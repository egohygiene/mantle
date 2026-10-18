#!/usr/bin/env python3
"""Download an authorized HTTP(S) HLS stream without publishing partial media."""

import sys

if sys.version_info < (3, 9):
    print("mantle hls-download: Python 3.9 or newer is required.", file=sys.stderr)
    sys.exit(69)

import argparse
import json
import math
import os
import re
import secrets
import shutil
import signal
import stat
import subprocess
import threading
import time
import urllib.parse

from hls_http import Gateway, HlsError


VERSION = "hls-download 1.0.0"
FORMATS = {"mkv": "matroska", "mp4": "mp4", "ts": "mpegts"}
TOKEN = re.compile(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$")
DIRECTORY_FLAGS = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
MAX_HEADER_BYTES = 65536
MAX_HEADERS = 64


class UsageParser(argparse.ArgumentParser):
    def error(self, message):
        # argparse's message can contain a source URL, header, or cookie value.
        self.print_usage(sys.stderr)
        self.exit(64, "mantle hls-download: invalid arguments; use --help for supported options.\n")


def arguments():
    parser = UsageParser(prog="mantle hls-download", allow_abbrev=False)
    parser.add_argument("source")
    parser.add_argument("--output")
    parser.add_argument("--format", choices=tuple(FORMATS))
    parser.add_argument("--transcode", action="store_true")
    parser.add_argument("--duration")
    parser.add_argument("--header", action="append", default=[])
    parser.add_argument("--header-file", action="append", default=[])
    parser.add_argument("--referer")
    parser.add_argument("--user-agent")
    parser.add_argument("--cookie")
    parser.add_argument("--no-preflight", action="store_true")
    parser.add_argument("--inherit-query", action="store_true")
    parser.add_argument("--no-range", action="store_true")
    parser.add_argument("--retry-count", default="2")
    parser.add_argument("--http-reconnect", action="store_true")
    parser.add_argument("--timeout", default="30")
    parser.add_argument("--diagnose", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-partial", action="store_true")
    parser.add_argument("--version", action="version", version=VERSION)
    result = parser.parse_args()
    if result.diagnose and result.dry_run:
        parser.error("choose one inspection mode")
    try:
        result.timeout = float(result.timeout)
        if not math.isfinite(result.timeout) or not 0 < result.timeout <= 3600:
            raise ValueError()
        if not re.fullmatch(r"[0-9]{1,2}", result.retry_count):
            raise ValueError()
        result.retry_count = int(result.retry_count)
        if result.retry_count > 20:
            raise ValueError()
        if result.duration is not None:
            result.duration = float(result.duration)
            if not math.isfinite(result.duration) or not 0 < result.duration <= 604800:
                raise ValueError()
        parsed = urllib.parse.urlsplit(result.source)
        if (parsed.scheme.lower() not in ("http", "https") or not parsed.hostname
                or parsed.username is not None or parsed.password is not None
                or any(ord(character) < 33 or ord(character) == 127 for character in result.source)):
            raise ValueError()
        parsed.port
        if result.output is not None and (not result.output or "\0" in result.output):
            raise ValueError()
    except (TypeError, ValueError):
        parser.error("invalid source or numeric option")
    result.source_has_query = bool(parsed.query)
    if result.format is None:
        suffix = os.path.splitext(result.output or "")[1].lower().lstrip(".")
        result.format = suffix if suffix in FORMATS else "mkv"
    if result.output is None:
        result.output = "download." + result.format
    return result


def parse_header(value):
    if ":" not in value:
        raise HlsError("Headers must use NAME: VALUE syntax without line breaks.", 64)
    name, content = value.split(":", 1)
    name, content = name.strip(), content.strip(" \t")
    if (not TOKEN.fullmatch(name) or any(ord(character) < 32 or ord(character) == 127 for character in content)):
        raise HlsError("Headers must use NAME: VALUE syntax without line breaks.", 64)
    # These headers could change proxy routing, frame a request, or override Range.
    forbidden = {
        "host", "connection", "content-length", "transfer-encoding", "upgrade",
        "proxy-authorization", "proxy-connection", "range", "accept-encoding",
        "te", "trailer", "expect",
    }
    if name.lower() in forbidden:
        raise HlsError("Transport and range control headers are not supported; use the documented options.", 64)
    try:
        content.encode("latin-1")
    except UnicodeEncodeError:
        raise HlsError("Header values must use HTTP-compatible characters.", 64) from None
    return name, content


def headers(options, read_files=True):
    values = list(options.header)
    try:
        total = sum(len(value.encode("utf-8")) for value in values)
    except UnicodeError:
        raise HlsError("Header context must use supported text characters.", 64) from None
    if len(options.header_file) > MAX_HEADERS:
        raise HlsError("Too many header files; at most 64 headers are supported.", 64)
    if read_files:
        for filename in options.header_file:
            try:
                descriptor = os.open(filename, os.O_RDONLY | getattr(os, "O_NONBLOCK", 0))
                with os.fdopen(descriptor, "rb") as stream:
                    if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                        raise ValueError()
                    raw = stream.read(MAX_HEADER_BYTES + 1)
                total += len(raw)
                if total > MAX_HEADER_BYTES or b"\0" in raw:
                    raise ValueError()
                text = raw.decode("utf-8")
                for value in text.splitlines():
                    if value.strip():
                        values.append(value)
            except (OSError, UnicodeError, ValueError):
                raise HlsError("A header file could not be read as bounded UTF-8 NAME: VALUE lines.", 64) from None
    for name, content in (("Referer", options.referer), ("User-Agent", options.user_agent), ("Cookie", options.cookie)):
        if content is not None:
            value = name + ": " + content
            try:
                total += len(value.encode("utf-8"))
            except UnicodeError:
                raise HlsError("Header context must use supported text characters.", 64) from None
            values.append(value)
    if total > MAX_HEADER_BYTES or len(values) > MAX_HEADERS:
        raise HlsError("Header context exceeds the 64-header or 64 KiB limit.", 64)
    return [parse_header(value) for value in values]


def subprocess_environment():
    result = dict(os.environ)
    for name in tuple(result):
        if name.lower() in ("http_proxy", "https_proxy", "all_proxy", "no_proxy", "ffreport"):
            result.pop(name, None)
        elif name in ("AV_LOG_FORCE_COLOR", "AV_LOG_FORCE_NOCOLOR"):
            result.pop(name, None)
    return result


class Capture:
    """Drain a subprocess pipe with bounded retained output and a skip marker."""

    def __init__(self, pipe, limit):
        self.pipe = pipe
        self.limit = limit
        self.data = bytearray()
        self.overflow = False
        self.skipped_segment = False
        self.thread = threading.Thread(target=self.read, daemon=True)
        self.thread.start()

    def read(self):
        tail = b""
        try:
            while True:
                part = self.pipe.read(4096)
                if not part:
                    break
                inspected = (tail + part).lower()
                if b"failed too many times, skipping" in inspected:
                    self.skipped_segment = True
                tail = inspected[-128:]
                available = self.limit - len(self.data)
                self.data.extend(part[:available])
                if len(part) > available:
                    self.overflow = True
        finally:
            self.pipe.close()

    def finish(self):
        self.thread.join(timeout=2)


class Runner:
    def __init__(self):
        self.active = None

    def stop(self):
        process = self.active
        if process is None:
            return
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
        self.active = None

    def run(self, command, timeout=None, gateway=None, descriptors=()):
        try:
            self.active = subprocess.Popen(
                command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, env=subprocess_environment(), pass_fds=descriptors,
            )
        except (OSError, ValueError):
            raise HlsError("A required media tool could not be started.", 69) from None
        output = Capture(self.active.stdout, 1024 * 1024)
        errors = Capture(self.active.stderr, 65536)
        deadline = time.monotonic() + timeout if timeout is not None else None
        try:
            while self.active.poll() is None:
                if gateway is not None and gateway.failure is not None:
                    raise gateway.failure
                if deadline is not None and time.monotonic() >= deadline:
                    raise HlsError("A media tool exceeded its bounded operation timeout.")
                time.sleep(0.05)
            result = self.active.returncode
            self.active = None
        finally:
            self.stop()
            output.finish()
            errors.finish()
        if gateway is not None and gateway.failure is not None:
            raise gateway.failure
        return result, bytes(output.data), bytes(errors.data), errors.skipped_segment, output.overflow


def media_tools(options, runner):
    ffmpeg, ffprobe = shutil.which("ffmpeg"), shutil.which("ffprobe")
    if ffmpeg is None or ffprobe is None:
        raise HlsError("Install ffmpeg and ffprobe before downloading; Mantle never installs dependencies.", 69)
    status, output, errors, _, _ = runner.run([ffmpeg, "-hide_banner", "-h", "demuxer=hls"], timeout=10)
    features = output + errors
    if status or not re.search(rb"(?:^|\s)-seg_max_retry\s", features):
        raise HlsError("This FFmpeg lacks bounded HLS segment retries (-seg_max_retry); use a supported version.", 69)
    if options.no_range and not re.search(rb"(?:^|\s)-http_seekable\s", features):
        raise HlsError("This FFmpeg lacks HLS range control (-http_seekable); use a supported version.", 69)
    if options.http_reconnect:
        status, output, errors, _, _ = runner.run([ffmpeg, "-hide_banner", "-h", "protocol=http"], timeout=10)
        features = output + errors
        required = (b"reconnect", b"reconnect_streamed", b"reconnect_on_network_error",
                    b"reconnect_delay_max", b"reconnect_max_retries", b"reconnect_delay_total_max")
        if status or any(not re.search(rb"(?:^|\s)-" + name + rb"\s", features) for name in required):
            raise HlsError("This FFmpeg lacks bounded HTTP reconnect options; omit --http-reconnect or use a supported version.", 69)
    return ffmpeg, ffprobe


def same_file(first, second):
    return first.st_dev == second.st_dev and first.st_ino == second.st_ino


def physical_directory(path):
    descriptor = None
    try:
        descriptor = os.open(os.sep if os.path.isabs(path) else ".", DIRECTORY_FLAGS)
        for component in path.split(os.sep):
            if component in ("", "."):
                continue
            information = os.stat(component, dir_fd=descriptor, follow_symlinks=False)
            if not stat.S_ISDIR(information.st_mode):
                raise HlsError("Choose an existing physical output directory without symbolic-link components.", 73)
            child = os.open(component, DIRECTORY_FLAGS, dir_fd=descriptor)
            if not same_file(os.fstat(child), information):
                os.close(child)
                raise HlsError("The output directory changed while opening it.", 73)
            os.close(descriptor)
            descriptor = child
        result, descriptor = descriptor, None
        return result
    except OSError:
        raise HlsError("Choose a writable, existing physical output directory without symbolic-link components.", 73) from None
    finally:
        if descriptor is not None:
            os.close(descriptor)


class Output:
    def __init__(self, options):
        self.options = options
        self.parent = None
        self.descriptor = None
        self.partial = None
        self.published = False
        self.parent_path, self.name = os.path.split(options.output)
        self.parent_path = self.parent_path or "."
        if self.name in ("", ".", ".."):
            raise HlsError("The output must name a file in an existing physical directory.", 73)

    def prepare(self):
        if (not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY")
                or os.open not in os.supports_dir_fd or os.stat not in os.supports_dir_fd
                or os.link not in os.supports_dir_fd):
            raise HlsError("This platform lacks safe no-overwrite output publication support.", 69)
        self.parent = physical_directory(self.parent_path)
        self.check_destination()
        for _ in range(10):
            self.partial = ".mantle-hls-" + secrets.token_hex(12) + ".partial." + self.options.format
            try:
                self.descriptor = os.open(self.partial, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                          0o600, dir_fd=self.parent)
                break
            except FileExistsError:
                continue
            except OSError:
                raise HlsError("A private partial output could not be created in the output directory.", 73) from None
        if self.descriptor is None:
            raise HlsError("A unique partial output could not be created.", 73)
        os.fchmod(self.descriptor, 0o600)
        try:
            probe = os.open(self.media_path, os.O_RDWR)
            try:
                if not same_file(os.fstat(probe), os.fstat(self.descriptor)):
                    raise OSError()
            finally:
                os.close(probe)
        except OSError:
            raise HlsError("This platform cannot safely pass a private media file to FFmpeg using /dev/fd.", 69) from None

    @property
    def media_path(self):
        return "/dev/fd/" + str(self.descriptor)

    def check_destination(self):
        try:
            os.stat(self.name, dir_fd=self.parent, follow_symlinks=False)
        except FileNotFoundError:
            return
        except OSError:
            raise HlsError("The output destination could not be checked safely.", 73) from None
        raise HlsError("The output already exists; choose a different destination. Existing files are never replaced.", 73)

    def owned(self):
        if self.descriptor is None or self.partial is None or self.parent is None:
            return False
        try:
            information = os.stat(self.partial, dir_fd=self.parent, follow_symlinks=False)
            return stat.S_ISREG(information.st_mode) and same_file(information, os.fstat(self.descriptor))
        except OSError:
            return False

    def publish(self):
        check = physical_directory(self.parent_path)
        try:
            if not same_file(os.fstat(check), os.fstat(self.parent)) or not self.owned():
                raise HlsError("The output location changed; the download was not published.", 73)
        finally:
            os.close(check)
        self.check_destination()
        linked_identity = None
        try:
            os.fsync(self.descriptor)
            os.link(self.partial, self.name, src_dir_fd=self.parent, dst_dir_fd=self.parent, follow_symlinks=False)
            linked_identity = os.stat(self.name, dir_fd=self.parent, follow_symlinks=False)
            if not same_file(linked_identity, os.fstat(self.descriptor)):
                raise HlsError("The output location changed during publication.", 73)
            os.unlink(self.partial, dir_fd=self.parent)
            self.published = True
        except FileExistsError:
            raise HlsError("The output appeared during download; existing files are never replaced.", 73) from None
        except (OSError, HlsError) as exception:
            # Roll back only the link observed immediately after our publication.
            # A competing replacement with a different identity is never removed.
            if linked_identity is not None:
                try:
                    current = os.stat(self.name, dir_fd=self.parent, follow_symlinks=False)
                    if same_file(current, linked_identity):
                        os.unlink(self.name, dir_fd=self.parent)
                except OSError:
                    pass
            if isinstance(exception, HlsError):
                raise
            raise HlsError("The validated output could not be published without replacing an existing file.", 73) from None

    def close(self):
        try:
            if self.owned():
                if self.options.keep_partial and not self.published:
                    print("mantle hls-download: partial output retained as " + self.partial + ".", file=sys.stderr)
                else:
                    os.unlink(self.partial, dir_fd=self.parent)
        except OSError:
            print("mantle hls-download: the private partial output could not be removed.", file=sys.stderr)
        finally:
            if self.descriptor is not None:
                os.close(self.descriptor)
                self.descriptor = None
            if self.parent is not None:
                os.close(self.parent)
                self.parent = None


def ffmpeg_command(options, executable, gateway, output):
    command = [executable, "-hide_banner", "-nostdin", "-loglevel", "warning", "-y",
               "-protocol_whitelist", "http,https,tcp,tls,crypto", "-rw_timeout", str(int(options.timeout * 1000000)),
               "-seg_max_retry", str(options.retry_count)]
    if options.no_range:
        command.extend(["-seekable", "0", "-http_seekable", "0"])
    if options.http_reconnect:
        command.extend(["-reconnect", "1", "-reconnect_streamed", "1", "-reconnect_on_network_error", "1",
                        "-reconnect_delay_max", "2", "-reconnect_max_retries", str(options.retry_count),
                        "-reconnect_delay_total_max", str(max(1, options.retry_count * 2))])
    command.extend(["-f", "hls", "-i", gateway.url, "-map", "0:v:0?", "-map", "0:a:0?", "-map_metadata", "-1"])
    if options.duration is not None:
        command.extend(["-t", str(options.duration)])
    if options.transcode:
        command.extend(["-c:v", "libx264", "-c:a", "aac"])
    else:
        command.extend(["-c", "copy"])
    command.extend(["-f", FORMATS[options.format], output.media_path])
    return command


def validate_media(options, executable, output, runner):
    if os.fstat(output.descriptor).st_size <= 0 or not output.owned():
        raise HlsError("FFmpeg did not produce a nonempty private output; nothing was published.")
    os.lseek(output.descriptor, 0, os.SEEK_SET)
    status, data, _, _, overflow = runner.run(
        [executable, "-v", "error", "-protocol_whitelist", "file,pipe", "-show_entries",
         "format=duration:stream=codec_type,duration", "-of", "json", output.media_path],
        timeout=max(10, min(options.timeout, 60)), descriptors=(output.descriptor,),
    )
    try:
        result = json.loads(data)
        streams = [stream for stream in result.get("streams", []) if stream.get("codec_type") in ("audio", "video")]
        durations = [result.get("format", {}).get("duration")]
        durations.extend(stream.get("duration") for stream in streams)
        positive_duration = any(value is not None and math.isfinite(float(value)) and float(value) > 0
                                for value in durations if value != "N/A")
        if status or overflow or not streams or not positive_duration:
            raise ValueError()
    except (ValueError, TypeError, AttributeError):
        raise HlsError("ffprobe could not validate audio/video streams and a positive duration; nothing was published.") from None


def dry_run(options, context):
    print(json.dumps({
        "schema_version": 1, "mode": "dry-run", "source_scheme": urllib.parse.urlsplit(options.source).scheme.lower(),
        "source_has_query": options.source_has_query, "format": options.format,
        "codec_mode": "h264-aac" if options.transcode else "copy", "duration_seconds": options.duration,
        "header_names": sorted({name.lower() for name, _ in context}),
        "header_file_count": len(options.header_file), "header_files_read": False,
        "preflight": not options.no_preflight, "inherit_query": options.inherit_query,
        "no_range": options.no_range, "retry_count": options.retry_count, "http_reconnect": options.http_reconnect,
        "timeout_seconds": options.timeout, "keep_partial": options.keep_partial,
        "publication": "validate-then-no-overwrite", "network_requests": 0,
    }, sort_keys=True))


def interrupted(signum, frame):
    raise KeyboardInterrupt()


def main():
    options = arguments()
    runner, gateway, output = Runner(), None, None
    signal.signal(signal.SIGINT, interrupted)
    try:
        context = headers(options, read_files=not options.dry_run)
        if options.dry_run:
            dry_run(options, context)
            return 0
        # Diagnose is a manifest-only operation and requires no media binaries or files.
        if not options.diagnose:
            ffmpeg, ffprobe = media_tools(options, runner)
            output = Output(options)
            output.prepare()
        gateway = Gateway(options.source, context, options.timeout, options.retry_count, options.inherit_query,
                          no_range=options.no_range)
        gateway.start()
        if options.diagnose or not options.no_preflight:
            gateway.preflight()
        if options.diagnose:
            report = {"schema_version": 1, "mode": "diagnose"}
            report.update(gateway.report())
            print(json.dumps(report, sort_keys=True))
            return 0
        status, _, _, skipped, _ = runner.run(ffmpeg_command(options, ffmpeg, gateway, output), gateway=gateway,
                                            descriptors=(output.descriptor,))
        if status or skipped or gateway.has_unresolved_failures():
            raise HlsError("The HLS download failed or skipped a resource; nothing was published. Check access, expiry, and request context.")
        validate_media(options, ffprobe, output, runner)
        output.publish()
        print("mantle hls-download: completed; validated media published without replacing existing files.")
        return 0
    except KeyboardInterrupt:
        print("mantle hls-download: interrupted; no incomplete media was published.", file=sys.stderr)
        return 130
    except HlsError as exception:
        print("mantle hls-download: " + str(exception), file=sys.stderr)
        return exception.status
    except OSError:
        print("mantle hls-download: an input/output operation failed; no incomplete media was published.", file=sys.stderr)
        return 73
    finally:
        runner.stop()
        if gateway is not None:
            gateway.close()
        if output is not None:
            output.close()


if __name__ == "__main__":
    sys.exit(main())
