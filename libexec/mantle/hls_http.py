"""Private, memory-only HLS gateway with scoped upstream request context."""

import collections
import http.client
import http.server
import math
import re
import secrets
import socket
import socketserver
import threading
import urllib.error
import urllib.parse
import urllib.request


MAX_PLAYLIST_BYTES = 4 * 1024 * 1024
MAX_RESOURCES = 10000
MAX_PLAYLISTS = 256
MAX_REDIRECTS = 10
CHUNK_BYTES = 64 * 1024
SAFE_MEDIA_SUFFIXES = (
    ".ts", ".m4s", ".mp4", ".aac", ".mp3", ".vtt", ".webvtt", ".ac3", ".ec3",
    ".m4a", ".m4v", ".mpegts", ".mpg", ".mpeg", ".oga", ".ogg", ".opus", ".flac", ".wav", ".webm",
)
RESERVED_HEADERS = {
    "host", "content-length", "transfer-encoding", "connection",
    "proxy-authorization", "proxy-connection", "range", "accept-encoding",
    "upgrade", "te", "trailer", "expect",
}
ATTRIBUTE = re.compile(r"([A-Za-z0-9-]+)\s*=\s*(\"[^\"]*\"|[^,]*)")
CONTENT_RANGE = re.compile(r"bytes ([0-9]+)-([0-9]+)/(?:[0-9]+|\*)")


class HlsError(Exception):
    """A deliberately safe public diagnostic, without upstream input values."""

    def __init__(self, message, status=65):
        super().__init__(message)
        self.status = status
        self._recorded = False


def _recorded(error):
    error._recorded = True
    return error


def _url(value):
    try:
        if not isinstance(value, str) or any(ord(character) <= 32 or ord(character) == 127 for character in value):
            raise ValueError()
        parsed = urllib.parse.urlsplit(value)
        if (parsed.scheme.lower() not in ("http", "https") or not parsed.hostname
                or parsed.username is not None or parsed.password is not None):
            raise ValueError()
        parsed.port
        return parsed._replace(fragment="").geturl()
    except (ValueError, TypeError, UnicodeError):
        raise HlsError("HLS resources require valid HTTP or HTTPS URLs without embedded credentials.") from None


def _origin(value):
    parsed = urllib.parse.urlsplit(value)
    return parsed.scheme.lower(), parsed.hostname.lower(), parsed.port or (443 if parsed.scheme.lower() == "https" else 80)


class _Resource:
    def __init__(self, token, url, kind, allowed):
        self.token = token
        self.url = url
        self.kind = kind
        self.allowed = allowed
        self.lock = threading.Lock()
        self.cache = None
        self.cache_served = False
        self.live = None
        self.playlist_type = None


class _Redirects(urllib.request.HTTPRedirectHandler):
    def __init__(self, gateway, resource, byte_range):
        self.gateway = gateway
        self.allowed = resource.allowed
        self.byte_range = byte_range
        self.count = 0

    def redirect_request(self, request, response, code, message, headers, new_url):
        target = _url(new_url)
        self.count += 1
        if self.count > MAX_REDIRECTS:
            raise HlsError("The upstream HLS redirect limit was exceeded.")
        crossed = _origin(request.full_url) != _origin(target)
        if crossed:
            self.allowed = False
        with self.gateway._lock:
            self.gateway._request_count += 1
            self.gateway._status_counts[str(code)] += 1
            self.gateway._redirect_count += 1
            self.gateway._cross_redirect_count += int(crossed)
        return self.gateway._request(target, self.allowed, self.byte_range, request.get_method())


class _Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = False

    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name = "localhost"
        self.server_port = self.server_address[1]

    def handle_error(self, request, client_address):
        # Standard HTTPServer tracebacks may contain source-controlled values.
        pass


class Gateway:
    def __init__(self, source, headers, timeout, retry_count, inherit_query, no_range=False):
        self.source = _url(source)
        self.source_origin = _origin(self.source)
        self.headers = []
        for name, value in headers:
            if (not re.fullmatch(r"[!#$%&'*+.^_`|~0-9A-Za-z-]+", name)
                    or name.lower() in RESERVED_HEADERS
                    or any(ord(character) < 32 or ord(character) == 127 for character in value)):
                raise HlsError("An HLS request header is invalid or controls reserved transport behavior.", 64)
            try:
                value.encode("latin-1")
            except UnicodeError:
                raise HlsError("HLS request header values must be valid HTTP header text.", 64) from None
            self.headers.append((name, value))
        if not math.isfinite(timeout) or timeout <= 0 or not isinstance(retry_count, int) or retry_count < 0:
            raise HlsError("HLS request timeout or retry settings are invalid.", 64)
        self.timeout = timeout
        self.retry_count = retry_count
        self.inherit_query = inherit_query
        self.no_range = no_range
        self._lock = threading.RLock()
        self._resources = {}
        self._keys = {}
        self._edges = collections.defaultdict(set)
        self._pending = {}
        self._failure = None
        self._server = None
        self._thread = None
        self._namespace = secrets.token_hex(24)
        self._request_count = 0
        self._success_count = 0
        self._failure_count = 0
        self._status_counts = collections.Counter()
        self._categories = collections.Counter()
        self._redirect_count = 0
        self._cross_redirect_count = 0
        self._playlists = set()
        self._encrypted = False
        self._byte_ranges = False
        self._preflight_done = False
        self._initial = self._register(self.source, "playlist", True)

    @property
    def url(self):
        if self._server is None:
            raise HlsError("The local HLS gateway has not started.")
        return self._local_url(self._initial)

    @property
    def failure(self):
        with self._lock:
            return self._failure

    def has_unresolved_failures(self):
        with self._lock:
            return bool(self._failure or self._pending)

    def _fatal(self, error):
        with self._lock:
            if self._failure is None:
                self._failure = error

    def _failed(self, resource, category, status=None, terminal=False):
        with self._lock:
            self._failure_count += 1
            self._categories[category] += 1
            failures = self._pending.get(resource.token, 0) + 1
            self._pending[resource.token] = failures
            deterministic = status is not None and 400 <= status < 500 and status not in (408, 429)
            if terminal or deterministic or failures > self.retry_count:
                self._fatal(self._http_error(resource, status) if status is not None
                            else HlsError("An upstream HLS resource could not be retrieved completely."))

    @staticmethod
    def _http_error(resource, status):
        label = {"playlist": "playlist", "key": "key", "map": "initialization segment"}.get(resource.kind, "media segment")
        prefix = "The HLS " + label + " request failed (HTTP " + str(status) + "). "
        if status in (401, 403):
            advice = "Verify access headers, cookies, and signed-link expiry."
        elif status == 404:
            advice = "Verify that the source playlist and its referenced resources remain available."
        elif status == 422:
            advice = "Verify request context, query inheritance, and byte-range compatibility."
        else:
            advice = "Verify upstream availability and request context."
        return HlsError(prefix + advice)

    def _succeeded(self, resource):
        with self._lock:
            self._success_count += 1
            self._pending.pop(resource.token, None)

    def report(self):
        with self._lock:
            return dict(
                playlist_type=self._initial.playlist_type,
                live=self._initial.live,
                encrypted=self._encrypted,
                has_byte_ranges=self._byte_ranges,
                request_count=self._request_count,
                success_count=self._success_count,
                failure_count=self._failure_count,
                pending_failures=len(self._pending),
                resource_count=len(self._resources),
                playlist_count=len(self._playlists),
                status_counts=dict(sorted(self._status_counts.items())),
                error_categories=dict(sorted(self._categories.items())),
                redirect_count=self._redirect_count,
                cross_origin_redirect_count=self._cross_redirect_count,
                request_shape=dict(private_header_count=len(self.headers), inherit_query=self.inherit_query,
                                   timeout_seconds=self.timeout, retry_count=self.retry_count,
                                   no_range=self.no_range,
                                   source_has_query=bool(urllib.parse.urlsplit(self.source).query)),
            )

    def start(self):
        if self._server is not None:
            return
        gateway = self

        class Handler(http.server.BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, format, *arguments):
                pass

            def log_error(self, format, *arguments):
                pass

            def do_GET(self):
                gateway._serve(self, False)

            def do_HEAD(self):
                gateway._serve(self, True)

        self._server = _Server(("127.0.0.1", 0), Handler)
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()

    def close(self):
        if self._server is not None:
            self._server.shutdown()
            self._server.server_close()
            self._thread.join(timeout=2)
            self._server = None

    def _local_url(self, resource):
        suffix = {"playlist": ".m3u8", "key": ".key", "map": ".mp4"}.get(resource.kind)
        if suffix is None:
            path = urllib.parse.urlsplit(resource.url).path.lower()
            suffix = next((candidate for candidate in SAFE_MEDIA_SUFFIXES if path.endswith(candidate)), ".ts")
        return "http://127.0.0.1:" + str(self._server.server_address[1]) + "/" + self._namespace + "/" + resource.token + suffix

    def _register(self, url, kind, allowed, parent=None):
        url = _url(url)
        allowed = bool(allowed and _origin(url) == self.source_origin)
        key = (url, kind, allowed)
        with self._lock:
            if key in self._keys:
                resource = self._keys[key]
            else:
                if len(self._resources) >= MAX_RESOURCES:
                    raise HlsError("The HLS resource graph exceeds the supported size.")
                resource = _Resource(secrets.token_hex(16), url, kind, allowed)
                self._resources[resource.token] = resource
                self._keys[key] = resource
            if parent is not None and kind == "playlist":
                self._edges[parent.token].add(resource.token)
                pending, visited = [resource.token], set()
                while pending:
                    token = pending.pop()
                    if token == parent.token:
                        raise HlsError("Cyclic HLS playlist references are unsupported.")
                    if token not in visited:
                        visited.add(token)
                        pending.extend(self._edges[token])
            return resource

    def _request(self, url, allowed, byte_range=None, method="GET"):
        request = urllib.request.Request(url, method=method)
        request.add_header("Accept-Encoding", "identity")
        if allowed and _origin(url) == self.source_origin:
            for name, value in self.headers:
                request.add_header(name, value)
        if byte_range is not None:
            request.add_header("Range", byte_range)
        return request

    def _open(self, resource, byte_range=None, method="GET"):
        redirects = _Redirects(self, resource, byte_range)
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), redirects)
        with self._lock:
            self._request_count += 1
        try:
            response = opener.open(self._request(resource.url, resource.allowed, byte_range, method), timeout=self.timeout)
            with self._lock:
                self._status_counts[str(response.status)] += 1
            if response.status not in (200, 206):
                response.close()
                self._failed(resource, "http_status", response.status)
                raise _recorded(HlsError("An upstream HLS resource returned an unsupported HTTP response."))
            if response.headers.get("Content-Encoding", "identity").lower() not in ("", "identity"):
                response.close()
                self._failed(resource, "content_encoding", terminal=True)
                raise _recorded(HlsError("Compressed upstream HLS responses are unsupported."))
            return response, redirects.allowed
        except urllib.error.HTTPError as exception:
            with self._lock:
                self._status_counts[str(exception.code)] += 1
            exception.close()
            self._failed(resource, "http_status", exception.code)
            raise _recorded(self._http_error(resource, exception.code)) from None
        except HlsError:
            raise
        except (urllib.error.URLError, TimeoutError, socket.timeout, OSError, ValueError, UnicodeError):
            self._failed(resource, "connection")
            raise _recorded(HlsError("An upstream HLS resource could not be reached.")) from None

    def _length(self, response):
        raw = response.headers.get("Content-Length")
        if raw is None:
            return None
        if not re.fullmatch(r"[0-9]+", raw) or len(raw) > 20:
            raise HlsError("An upstream HLS response has invalid length metadata.")
        return int(raw)

    def _read_playlist(self, resource, response):
        expected = self._length(response)
        if expected is not None and expected > MAX_PLAYLIST_BYTES:
            raise HlsError("An HLS playlist exceeds the supported size.")
        chunks, size = [], 0
        while True:
            chunk = response.read(min(CHUNK_BYTES, MAX_PLAYLIST_BYTES + 1 - size))
            if not chunk:
                break
            chunks.append(chunk)
            size += len(chunk)
            if size > MAX_PLAYLIST_BYTES:
                raise HlsError("An HLS playlist exceeds the supported size.")
        if expected is not None and size != expected:
            raise HlsError("An upstream HLS playlist was truncated.")
        return b"".join(chunks)

    def _resolve(self, raw, parent_url, parent, allowed, kind):
        if not raw or "\\" in raw or any(ord(character) <= 32 or ord(character) == 127 for character in raw):
            raise HlsError("An HLS playlist contains an invalid resource reference.")
        try:
            reference = urllib.parse.urlsplit(raw)
            target = _url(urllib.parse.urljoin(parent_url, raw))
            explicit_query = "?" in raw.split("#", 1)[0]
            if explicit_query:
                target = urllib.parse.urlsplit(target)._replace(query=reference.query).geturl()
            if (self.inherit_query and not reference.scheme and not reference.netloc
                    and not raw.startswith("//") and not explicit_query
                    and _origin(target) == _origin(parent_url)):
                query = urllib.parse.urlsplit(parent_url).query
                if query:
                    target = urllib.parse.urlsplit(target)._replace(query=query).geturl()
        except ValueError:
            raise HlsError("An HLS playlist contains an invalid resource reference.") from None
        resource = self._register(target, kind, allowed, parent)
        return self._local_url(resource)

    def _attributes(self, text):
        result, spans, position = {}, {}, 0
        while position < len(text):
            while position < len(text) and text[position] in (" ", "\t"):
                position += 1
            match = ATTRIBUTE.match(text, position)
            if match is None:
                raise HlsError("An HLS playlist contains malformed attributes.")
            name, raw = match.group(1).upper(), match.group(2)
            if name in result:
                raise HlsError("An HLS playlist contains duplicate attributes.")
            quoted = raw.startswith("\"")
            if (quoted and not raw.endswith("\"")) or (not quoted and "\"" in raw) or (name == "URI" and not quoted):
                raise HlsError("An HLS playlist contains malformed quoted attributes.")
            result[name] = raw[1:-1] if quoted else raw.strip()
            spans[name] = (match.start(2) + int(quoted), match.end(2) - int(quoted))
            position = match.end()
            if position == len(text):
                break
            if text[position] != ",":
                raise HlsError("An HLS playlist contains malformed attributes.")
            position += 1
            if position == len(text):
                raise HlsError("An HLS playlist contains malformed attributes.")
        return result, spans

    def _rewrite(self, resource, body, parent_url, allowed):
        try:
            text = body.decode("utf-8-sig")
        except UnicodeError:
            raise HlsError("An HLS playlist is not valid UTF-8 text.") from None
        lines = text.splitlines()
        if "\0" in text or not lines or lines[0].strip() != "#EXTM3U":
            raise HlsError("The upstream response is not an HLS playlist.")
        with self._lock:
            self._playlists.add(resource.token)
            if len(self._playlists) > MAX_PLAYLISTS:
                raise HlsError("The HLS playlist graph exceeds the supported size.")
        result, next_playlist, master, encrypted, byte_ranges = [], False, False, False, False
        for line in lines:
            stripped = line.strip()
            if not stripped:
                result.append("")
                continue
            if not stripped.startswith("#"):
                kind = "playlist" if next_playlist or urllib.parse.urlsplit(stripped).path.lower().endswith(".m3u8") else "segment"
                result.append(self._resolve(stripped, parent_url, resource, allowed, kind))
                next_playlist = False
                continue
            tag, separator, attributes = stripped.partition(":")
            tag = tag.upper()
            if tag in ("#EXT-X-CONTENT-STEERING", "#EXT-X-PART", "#EXT-X-PART-INF",
                       "#EXT-X-PRELOAD-HINT", "#EXT-X-RENDITION-REPORT", "#EXT-X-SERVER-CONTROL", "#EXT-X-SKIP"):
                raise HlsError("Low-latency HLS and content-steering playlists are unsupported.")
            if tag == "#EXT-X-STREAM-INF":
                next_playlist, master = True, True
            if tag in ("#EXT-X-MEDIA", "#EXT-X-I-FRAME-STREAM-INF"):
                master = True
            if tag == "#EXT-X-BYTERANGE":
                byte_ranges = True
            if tag in ("#EXT-X-KEY", "#EXT-X-SESSION-KEY"):
                values, _spans = self._attributes(attributes)
                if values.get("METHOD", "").upper() not in ("NONE", "AES-128") or values.get("KEYFORMAT", "identity") != "identity":
                    raise HlsError("DRM and non-identity HLS encryption are unsupported.")
                if values["METHOD"].upper() == "AES-128" and not values.get("URI"):
                    raise HlsError("An AES-128 HLS key reference is missing.")
                encrypted = encrypted or values["METHOD"].upper() == "AES-128"
            uri_tag = tag in ("#EXT-X-KEY", "#EXT-X-SESSION-KEY", "#EXT-X-MAP", "#EXT-X-MEDIA", "#EXT-X-I-FRAME-STREAM-INF")
            uri_attribute = separator and re.search(r"(?i)(?:^|,)\s*(?:[A-Z0-9-]*URI|BYTERANGE(?:-START|-LENGTH)?)\s*=", attributes)
            if uri_attribute and not uri_tag:
                raise HlsError("An unsupported HLS tag contains a resource reference.")
            if uri_tag:
                values, spans = self._attributes(attributes)
                byte_ranges = byte_ranges or "BYTERANGE" in values or "BYTERANGE-START" in values
                if tag in ("#EXT-X-MAP", "#EXT-X-I-FRAME-STREAM-INF") and not values.get("URI"):
                    raise HlsError("An HLS tag is missing a required resource reference.")
                if "URI" in values:
                    if tag in ("#EXT-X-KEY", "#EXT-X-SESSION-KEY"):
                        kind = "key"
                    elif tag in ("#EXT-X-MEDIA", "#EXT-X-I-FRAME-STREAM-INF"):
                        kind = "playlist"
                    elif tag == "#EXT-X-MAP":
                        kind = "map"
                    else:
                        kind = "segment"
                    replacement = self._resolve(values["URI"], parent_url, resource, allowed, kind)
                    start, end = spans["URI"]
                    attributes = attributes[:start] + replacement + attributes[end:]
                    stripped = stripped[:len(tag)] + ":" + attributes
            result.append(stripped)
        if next_playlist:
            raise HlsError("An HLS master playlist is missing a child reference.")
        if self.no_range and byte_ranges:
            raise HlsError("Byte-range HLS playlists are incompatible with --no-range.")
        resource.playlist_type = "master" if master else "media"
        resource.live = None if master else not any(line.strip().upper() == "#EXT-X-ENDLIST" for line in lines)
        with self._lock:
            self._encrypted = self._encrypted or encrypted
            self._byte_ranges = self._byte_ranges or byte_ranges
        return ("\n".join(result) + "\n").encode("utf-8")

    def _playlist(self, resource):
        with resource.lock:
            if resource.cache is not None and (not resource.live or not resource.cache_served):
                resource.cache_served = True
                return resource.cache
            response = None
            try:
                response, allowed = self._open(resource)
                body = self._read_playlist(resource, response)
                rewritten = self._rewrite(resource, body, _url(response.geturl()), allowed)
                self._succeeded(resource)
                return rewritten
            except HlsError as exception:
                # Fetch errors already carry retry state; invalid manifests are fatal.
                if not exception._recorded:
                    self._fatal(exception)
                    self._failed(resource, "playlist", terminal=True)
                    exception._recorded = True
                raise
            except (OSError, TimeoutError, http.client.HTTPException):
                self._failed(resource, "playlist_transport", terminal=True)
                raise _recorded(HlsError("An upstream HLS playlist could not be read completely.")) from None
            finally:
                if response is not None:
                    response.close()

    def preflight(self):
        if self._server is None:
            raise HlsError("The local HLS gateway has not started.")
        if not self._preflight_done:
            body = self._playlist(self._initial)
            self._initial.cache = body
            self._initial.cache_served = False
            self._preflight_done = True
        return self.report()

    @staticmethod
    def _respond_failure(handler):
        body = b"HLS gateway resource unavailable.\n"
        try:
            handler.send_response(502)
            handler.send_header("Content-Type", "text/plain")
            handler.send_header("Content-Length", str(len(body)))
            handler.send_header("Connection", "close")
            handler.end_headers()
            if handler.command != "HEAD":
                handler.wfile.write(body)
        except (OSError, ValueError):
            pass
        handler.close_connection = True

    def _serve(self, handler, head_only):
        resource = None
        try:
            prefix = "/" + self._namespace + "/"
            path = handler.path
            if not path.startswith(prefix) or "?" in path or "#" in path:
                self._respond_failure(handler)
                return
            token = path[len(prefix):].split(".", 1)[0]
            with self._lock:
                resource = self._resources.get(token)
            if resource is None or path != urllib.parse.urlsplit(self._local_url(resource)).path:
                self._respond_failure(handler)
                return
            if self.failure is not None:
                self._respond_failure(handler)
                return
            if resource.kind == "playlist":
                body = self._playlist(resource)
                handler.send_response(200)
                handler.send_header("Content-Type", "application/vnd.apple.mpegurl")
                handler.send_header("Content-Length", str(len(body)))
                handler.end_headers()
                if not head_only:
                    handler.wfile.write(body)
                return
            self._stream(handler, resource, head_only)
        except (BrokenPipeError, ConnectionResetError):
            pass
        except HlsError as exception:
            if resource is not None and not exception._recorded:
                self._fatal(exception)
                self._failed(resource, "gateway", terminal=True)
            self._respond_failure(handler)
        except (OSError, ValueError, http.client.HTTPException):
            if resource is not None:
                self._failed(resource, "gateway", terminal=True)
            self._respond_failure(handler)

    def _stream(self, handler, resource, head_only):
        byte_range = handler.headers.get("Range")
        if byte_range is not None and not re.fullmatch(r"bytes=(?:[0-9]+-[0-9]*|-[0-9]+)", byte_range):
            raise HlsError("The local HLS request contains an unsupported byte range.")
        response, _allowed = self._open(resource, byte_range, "HEAD" if head_only else "GET")
        try:
            length = self._length(response)
            content_range = response.headers.get("Content-Range")
            if response.status == 206:
                match = CONTENT_RANGE.fullmatch(content_range or "")
                if match is None or int(match.group(2)) < int(match.group(1)):
                    raise HlsError("An upstream HLS response has invalid range metadata.")
                range_length = int(match.group(2)) - int(match.group(1)) + 1
                if length is not None and length != range_length:
                    raise HlsError("An upstream HLS response has inconsistent range metadata.")
                length = range_length
            handler.send_response(response.status)
            handler.send_header("Content-Type", "application/octet-stream")
            if length is not None:
                handler.send_header("Content-Length", str(length))
            else:
                handler.send_header("Connection", "close")
                handler.close_connection = True
            if response.status == 206:
                handler.send_header("Content-Range", content_range)
            handler.end_headers()
            if head_only:
                return
            transferred = 0
            while True:
                try:
                    chunk = response.read(CHUNK_BYTES)
                except (OSError, TimeoutError, http.client.HTTPException):
                    self._failed(resource, "stream_transport", terminal=True)
                    handler.close_connection = True
                    return
                if not chunk:
                    break
                transferred += len(chunk)
                try:
                    handler.wfile.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    handler.close_connection = True
                    return
            if length is not None and transferred != length:
                self._failed(resource, "truncated", terminal=True)
                handler.close_connection = True
                return
            self._succeeded(resource)
        finally:
            response.close()
