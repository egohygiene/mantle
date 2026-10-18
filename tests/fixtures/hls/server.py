#!/usr/bin/env python3
"""Generate tiny synthetic HLS media and serve hermetic loopback test routes.

Usage:
    python3 server.py generate DIRECTORY
    python3 server.py serve DIRECTORY --ready-file READY.json --events-file EVENTS.jsonl

All authorization material is synthetic. Protected routes expect query
``token=fixture-access``, ``X-Fixture-Access: fixture-access``, cookie
``fixture_session=fixture-access``, or a Referer of ``<origin>/player``.
The own-query child deliberately uses ``token=fixture-child`` instead.
Neither the ready document nor request events contain credential values.
"""

import argparse
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import threading
import time
from urllib.parse import parse_qs, urlsplit


SCHEMA = "mantle.hls-fixture/v1"
ACCESS_VALUE = "fixture-access"
CHILD_VALUE = "fixture-child"
SEGMENT_NAME = re.compile(r"segment[0-9]{3}\.(?:ts|m4s)\Z")
MODES = ("vod", "master", "fmp4", "aes", "event", "live", "inherit", "own-query",
         "cross-origin", "redirect", "range", "auth", "error", "drm")


def run_ffmpeg(executable, directory, kind):
    directory.mkdir()
    command = [
        executable, "-nostdin", "-hide_banner", "-loglevel", "error",
        "-f", "lavfi", "-i", "testsrc2=size=160x90:rate=10",
        "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=48000",
        "-t", "3", "-map", "0:v:0", "-map", "1:a:0",
        "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
        "-g", "10", "-keyint_min", "10", "-sc_threshold", "0",
        "-c:a", "aac", "-b:a", "64k", "-ac", "1", "-ar", "48000",
        "-f", "hls", "-hls_time", "1", "-hls_list_size", "0",
        "-hls_playlist_type", "vod",
    ]
    extension = "ts"
    if kind == "fmp4":
        extension = "m4s"
        command += ["-hls_segment_type", "fmp4", "-hls_fmp4_init_filename", "init.mp4"]
    elif kind == "aes":
        key = directory / "key.bin"
        key.write_bytes(bytes(range(16)))
        key_info = directory / "key-info.txt"
        key_info.write_text("key.bin\n" + str(key.resolve()) + "\n" + "0" * 32 + "\n", encoding="ascii")
        command += ["-hls_key_info_file", str(key_info)]
    command += ["-hls_segment_filename", str(directory / ("segment%03d." + extension)),
                str(directory / "index.m3u8")]
    completed = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               timeout=30, check=False)
    if completed.returncode:
        raise RuntimeError("synthetic FFmpeg generation failed: " + completed.stderr.decode("utf-8", errors="replace"))
    playlist = (directory / "index.m3u8").read_text(encoding="utf-8")
    segments = [line for line in playlist.splitlines() if line and not line.startswith("#")]
    if len(segments) != 3 or any(not SEGMENT_NAME.fullmatch(name) for name in segments):
        raise RuntimeError("expected three bounded, predictably named synthetic HLS segments")
    return {"segments": segments, "bytes": sum((directory / name).stat().st_size for name in segments)}


def generate(arguments):
    root = arguments.directory.resolve()
    root.mkdir(parents=True, exist_ok=True)
    if any(root.iterdir()):
        raise ValueError("the fixture media directory must be empty")
    manifest = {"schema": SCHEMA, "duration_seconds": 3, "video": "h264",
                "audio": "aac", "width": 160, "height": 90, "media": {}}
    for kind in ("vod", "fmp4", "aes"):
        manifest["media"][kind] = run_ffmpeg(arguments.ffmpeg, root / kind, kind)
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, sort_keys=True))
    return 0


@dataclass
class Response:
    status: int
    body: bytes = b""
    content_type: str = "application/octet-stream"
    path: str = "/unknown"
    route: str = "unknown"
    delay: float = 0
    close: bool = False
    truncated: bool = False
    location: str = ""


class FixtureState:
    def __init__(self, directory, events_file, delay_seconds):
        self.directory = directory
        self.events_file = events_file
        self.delay_seconds = delay_seconds
        self.lock = threading.Lock()
        self.requests = 0
        self.playlist_reads = {"live": 0, "event": 0}
        self.segment_reads = {}
        self.primary_origin = ""
        self.secondary_origin = ""

    def record(self, server, method, response, parsed, headers):
        query = parse_qs(parsed.query, keep_blank_values=True)
        cookie = headers.get("Cookie", "")
        with self.lock:
            self.requests += 1
            event = {
                "request": self.requests, "server": server, "method": method,
                "route": response.route, "path": response.path, "status": response.status,
                "query_present": bool(parsed.query), "token_present": "token" in query,
                "token_valid": query.get("token") in ([ACCESS_VALUE], [CHILD_VALUE]),
                "header_present": "X-Fixture-Access" in headers,
                "header_valid": headers.get("X-Fixture-Access") == ACCESS_VALUE,
                "authorization_present": "Authorization" in headers,
                "cookie_present": bool(cookie),
                "cookie_valid": "fixture_session=" + ACCESS_VALUE in cookie.split("; "),
                "referer_present": "Referer" in headers,
                "referer_valid": headers.get("Referer") == self.primary_origin + "/player",
                "range_present": "Range" in headers,
            }
            with self.events_file.open("a", encoding="utf-8") as stream:
                stream.write(json.dumps(event, sort_keys=True) + "\n")

    def media_playlist(self, kind="vod"):
        return (self.directory / kind / "index.m3u8").read_text(encoding="utf-8")

    def master(self, child):
        return "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=300000,RESOLUTION=160x90\n" + child + "\n"

    def progressing_playlist(self, kind):
        with self.lock:
            self.playlist_reads[kind] += 1
            count = self.playlist_reads[kind]
        source = self.media_playlist().splitlines()
        segments = [(source[index], source[index + 1]) for index in range(len(source) - 1)
                    if source[index].startswith("#EXTINF:")]
        available = min(len(segments), count)
        first = max(0, available - 2) if kind == "live" else 0
        lines = ["#EXTM3U", "#EXT-X-VERSION:3", "#EXT-X-TARGETDURATION:1",
                 "#EXT-X-MEDIA-SEQUENCE:" + str(first)]
        if kind == "event":
            lines.append("#EXT-X-PLAYLIST-TYPE:EVENT")
        for duration, name in segments[first:available]:
            lines += [duration, name]
        if count >= 3:
            lines.append("#EXT-X-ENDLIST")
        return "\n".join(lines) + "\n"

    def file_response(self, kind, name, route, path):
        if name == "index.m3u8":
            return Response(200, self.media_playlist(kind).encode(), "application/vnd.apple.mpegurl", path, route)
        if name == "key.bin" and kind == "aes":
            content_type = "application/octet-stream"
        elif name == "init.mp4" and kind == "fmp4":
            content_type = "video/mp4"
        elif SEGMENT_NAME.fullmatch(name) and (self.directory / kind / name).is_file():
            content_type = "video/iso.segment" if name.endswith(".m4s") else "video/mp2t"
        else:
            return Response(404, path=path, route=route)
        return Response(200, (self.directory / kind / name).read_bytes(), content_type, path, route)

    def response(self, parsed, headers, secondary):
        parts = parsed.path.strip("/").split("/")
        # Only enumerated safe route components enter logs or filesystem paths.
        if not parts or parts[0] not in MODES or any(part in ("", ".", "..") for part in parts):
            return Response(404)
        mode, name = parts[0], parts[-1]
        permitted = {"index.m3u8", "master.m3u8", "fmp4-master.m3u8", "key.bin", "init.mp4"}
        if name not in permitted and not SEGMENT_NAME.fullmatch(name):
            return Response(404)
        middle = parts[1:-1]
        allowed_middle = {(), ("video",), ("fmp4",), ("header",), ("referer",),
                          ("cookie",), ("authorization",), ("all",), ("404",), ("422",),
                          ("segment-404",), ("segment-422",), ("expired",), ("missing",),
                          ("transient-once",), ("unavailable",),
                          ("timeout",), ("finite-eof",), ("truncated",), ("malformed",), ("widevine",)}
        if tuple(middle) not in allowed_middle:
            return Response(404)
        route = mode + ("/" + middle[0] if middle else "")
        path = "/" + "/".join(parts)
        query = parse_qs(parsed.query, keep_blank_values=True)
        token = query.get("token")
        if mode == "inherit" and token != [ACCESS_VALUE]:
            return Response(403, path=path, route=route)
        if mode == "own-query":
            expected = ACCESS_VALUE if name == "master.m3u8" else CHILD_VALUE
            if token != [expected]:
                return Response(403, path=path, route=route)
        if mode == "auth":
            checks = {
                "header": headers.get("X-Fixture-Access") == ACCESS_VALUE,
                "referer": headers.get("Referer") == self.primary_origin + "/player",
                "cookie": "fixture_session=" + ACCESS_VALUE in headers.get("Cookie", "").split("; "),
                "authorization": headers.get("Authorization") == "Bearer " + ACCESS_VALUE,
                "query": token == [ACCESS_VALUE],
            }
            required = list(checks) if middle == ["all"] else middle
            if not required or not all(checks.get(check, False) for check in required):
                return Response(403, path=path, route=route)
        if mode == "error":
            error = middle[0] if middle else "malformed"
            if error in ("404", "422"):
                return Response(int(error), path=path, route=route)
            if name != "index.m3u8" and error in ("segment-404", "segment-422", "expired", "missing"):
                status = {"segment-404": 404, "segment-422": 422, "expired": 410, "missing": 404}[error]
                return Response(status, path=path, route=route)
            if name != "index.m3u8" and error in ("transient-once", "unavailable"):
                with self.lock:
                    key = (error, name)
                    self.segment_reads[key] = self.segment_reads.get(key, 0) + 1
                    attempt = self.segment_reads[key]
                if error == "unavailable" or attempt == 1:
                    return Response(503, path=path, route=route)
            if error == "malformed":
                return Response(200, b"#EXTM3U\n#EXT-X-TARGETDURATION:invalid\n#EXTINF:NaN,\n", "application/vnd.apple.mpegurl", path, route)
            response = self.file_response("vod", name, route, path)
            response.delay = self.delay_seconds if error == "timeout" and name != "index.m3u8" else 0
            response.close = error in ("finite-eof", "truncated")
            response.truncated = error == "truncated" and name != "index.m3u8"
            return response
        if mode == "drm":
            response = self.file_response("fmp4", name, route, path)
            if name == "index.m3u8":
                key = '#EXT-X-KEY:METHOD=SAMPLE-AES-CTR,URI="data:text/plain;base64,AA==",KEYFORMAT="urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed"\n'
                response.body = response.body.replace(b"#EXT-X-MAP:", key.encode() + b"#EXT-X-MAP:")
            return response
        if mode == "master" and not middle and name == "index.m3u8":
            return Response(200, self.master("video/index.m3u8").encode(), "application/vnd.apple.mpegurl", path, route)
        if mode == "inherit" and name in ("master.m3u8", "fmp4-master.m3u8"):
            child = "fmp4/index.m3u8" if name == "fmp4-master.m3u8" else "video/index.m3u8"
            return Response(200, self.master(child).encode(), "application/vnd.apple.mpegurl", path, route)
        if mode == "own-query" and name == "master.m3u8":
            child = "video/index.m3u8?token=" + CHILD_VALUE
            return Response(200, self.master(child).encode(), "application/vnd.apple.mpegurl", path, route)
        if mode == "cross-origin" and not secondary and name == "index.m3u8":
            child = self.secondary_origin + "/cross-origin/video/index.m3u8"
            return Response(200, self.master(child).encode(), "application/vnd.apple.mpegurl", path, route)
        if mode == "redirect":
            return Response(302, path=path, route=route,
                            location=self.secondary_origin + "/cross-origin/video/index.m3u8")
        kind = "fmp4" if mode in ("fmp4", "drm") or middle == ["fmp4"] else "aes" if mode in ("aes", "own-query", "inherit") else "vod"
        response = self.file_response(kind, name, route, path)
        if mode in ("event", "live") and name == "index.m3u8":
            response.body = self.progressing_playlist(mode).encode()
        if mode == "own-query" and name == "index.m3u8":
            lines = []
            for line in response.body.decode().splitlines():
                if line and not line.startswith("#"):
                    line += "?token=" + CHILD_VALUE
                elif line.startswith("#EXT-X-KEY:"):
                    line = line.replace('URI="key.bin"', 'URI="key.bin?token=' + CHILD_VALUE + '"')
                lines.append(line)
            response.body = ("\n".join(lines) + "\n").encode()
        if mode == "range" and name != "index.m3u8" and "Range" in headers:
            return Response(422, path=path, route=route)
        return response


class FixtureHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, _format, *_arguments):
        # BaseHTTPRequestHandler would otherwise print the complete request URL.
        return

    def do_HEAD(self):
        self.respond(head=True)

    def do_GET(self):
        self.respond(head=False)

    def respond(self, head):
        parsed = urlsplit(self.path)
        response = self.server.state.response(parsed, self.headers, self.server.secondary)
        if response.status == 200 and response.content_type != "application/vnd.apple.mpegurl" and "Range" in self.headers:
            requested = re.fullmatch(r"bytes=([0-9]+)-([0-9]*)", self.headers["Range"])
            if requested:
                first = int(requested[1])
                last = int(requested[2]) if requested[2] else len(response.body) - 1
                if first >= len(response.body) or last < first:
                    response.status, response.body = 416, b""
                else:
                    total = len(response.body)
                    last = min(last, total - 1)
                    response.body = response.body[first:last + 1]
                    response.status = 206
                    content_range = "bytes " + str(first) + "-" + str(last) + "/" + str(total)
            else:
                response.status, response.body = 416, b""
        else:
            content_range = None
        self.server.state.record("secondary" if self.server.secondary else "primary", self.command, response, parsed, self.headers)
        if response.delay:
            time.sleep(response.delay)
        try:
            self.send_response(response.status)
            self.send_header("Content-Type", response.content_type)
            self.send_header("Content-Length", str(len(response.body) + (32 if response.truncated else 0)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Accept-Ranges", "bytes")
            if response.location:
                self.send_header("Location", response.location)
            if response.status == 206:
                self.send_header("Content-Range", content_range)
            if response.close:
                self.send_header("Connection", "close")
                self.close_connection = True
            self.end_headers()
            if not head:
                self.wfile.write(response.body)
        except (BrokenPipeError, ConnectionResetError, TimeoutError):
            # Client cancellation is part of the local fault corpus.
            self.close_connection = True


class FixtureServer(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, _request, _client_address):
        # Tracebacks can contain request state; tests consume sanitized events.
        return


def serve(arguments):
    root = arguments.directory.resolve()
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schema") != SCHEMA:
        raise ValueError("generate the synthetic media before starting the server")
    if arguments.ready_file.exists() or arguments.events_file.exists():
        raise ValueError("ready and events files must not already exist")
    arguments.events_file.touch(exist_ok=False)
    state = FixtureState(root, arguments.events_file, arguments.delay_seconds)
    servers = []
    threads = []
    stopped = threading.Event()
    for secondary in (False, True):
        server = FixtureServer(("127.0.0.1", 0), FixtureHandler)
        server.state, server.secondary = state, secondary
        origin = "http://127.0.0.1:" + str(server.server_port)
        if secondary:
            state.secondary_origin = origin
        else:
            state.primary_origin = origin
        servers.append(server)
    endpoints = {
        "vod": "/vod/index.m3u8", "master": "/master/index.m3u8",
        "fmp4": "/fmp4/index.m3u8", "aes": "/aes/index.m3u8",
        "event": "/event/index.m3u8", "live": "/live/index.m3u8",
        "inherit_aes": "/inherit/master.m3u8", "inherit_fmp4": "/inherit/fmp4-master.m3u8",
        "own_query": "/own-query/master.m3u8", "cross_origin": "/cross-origin/index.m3u8",
        "redirect_origin": "/redirect/index.m3u8",
        "range": "/range/index.m3u8", "header": "/auth/header/index.m3u8",
        "referer": "/auth/referer/index.m3u8", "cookie": "/auth/cookie/index.m3u8",
        "authorization": "/auth/authorization/index.m3u8", "all_context": "/auth/all/index.m3u8",
        "404": "/error/404/index.m3u8", "422": "/error/422/index.m3u8",
        "segment_404": "/error/segment-404/index.m3u8", "segment_422": "/error/segment-422/index.m3u8",
        "transient_once": "/error/transient-once/index.m3u8", "unavailable": "/error/unavailable/index.m3u8",
        "expired": "/error/expired/index.m3u8", "missing": "/error/missing/index.m3u8",
        "timeout": "/error/timeout/index.m3u8", "finite_eof": "/error/finite-eof/index.m3u8",
        "truncated": "/error/truncated/index.m3u8", "malformed": "/error/malformed/index.m3u8",
        "drm": "/drm/widevine/index.m3u8",
    }
    ready = {"schema": SCHEMA, "pid": os.getpid(), "origin": state.primary_origin,
             "secondary_origin": state.secondary_origin, "media": manifest,
             "endpoints": {key: state.primary_origin + path for key, path in endpoints.items()}}
    for server in servers:
        thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05}, daemon=True)
        thread.start()
        threads.append(thread)
    temporary_ready = arguments.ready_file.with_name(arguments.ready_file.name + ".tmp")
    temporary_ready.write_text(json.dumps(ready, sort_keys=True) + "\n", encoding="utf-8")
    temporary_ready.replace(arguments.ready_file)
    signal.signal(signal.SIGTERM, lambda *_arguments: stopped.set())
    signal.signal(signal.SIGINT, lambda *_arguments: stopped.set())
    try:
        while not stopped.wait(0.2):
            pass
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()
        for thread in threads:
            thread.join(timeout=1)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    generator = commands.add_parser("generate", help="Generate three tiny real FFmpeg HLS profiles.")
    generator.add_argument("directory", type=Path)
    generator.add_argument("--ffmpeg", default="ffmpeg")
    server = commands.add_parser("serve", help="Serve only generated media through enumerated loopback routes.")
    server.add_argument("directory", type=Path)
    server.add_argument("--ready-file", type=Path, required=True)
    server.add_argument("--events-file", type=Path, required=True)
    server.add_argument("--delay-seconds", type=float, default=2)
    arguments = parser.parse_args()
    if arguments.command == "serve" and not 0 <= arguments.delay_seconds <= 10:
        parser.error("--delay-seconds must be between 0 and 10")
    return generate(arguments) if arguments.command == "generate" else serve(arguments)


if __name__ == "__main__":
    raise SystemExit(main())
