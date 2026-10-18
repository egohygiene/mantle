# Resilient HLS downloads

`mantle hls-download` downloads an HTTP(S) HLS stream using FFmpeg and validates
the result with ffprobe before publishing it. The equivalent standalone command
is `hls-download`. Use it only for content you are authorized to download;
Mantle does not bypass authentication, DRM, or provider restrictions.

```sh
mantle hls-download "https://media.example.test/playlist.m3u8"
mantle hls-download "$HLS_URL" --output "episode.mkv"
mantle hls-download "$HLS_URL" --output "episode.mp4"
mantle hls-download "$HLS_URL" --format ts --output "episode.ts"
mantle hls-download "$HLS_URL" --transcode --output "episode.mp4"
```

The default is `download.mkv` with stream-copy of the first video and audio
streams. An explicit `.mp4` or `.ts` output selects that container unless
`--format` specifies one. Stream-copy preserves the original codecs; choosing
MP4 does not make an incompatible codec compatible. Use `--transcode` to encode
H.264/AAC when needed. Mantle does not install media tools automatically.

The command wrapper supports Bash 3.2+. The implementation requires Python
3.9+, and downloading requires FFmpeg/ffprobe with HLS support and the
`seg_max_retry` option, available in FFmpeg 6.1+. Zsh and Fish invoke the same
external command; no shell runtime profile needs to load a media library.

## Request context and diagnostics

Headers may be supplied individually or through an existing user-owned file
containing one `Name: Value` record per line:

```sh
mantle hls-download "$HLS_URL" --header-file "$HOME/private/hls-headers.txt"
mantle hls-download "$HLS_URL" --referer "$HLS_REFERER" --cookie "$HLS_COOKIE"
mantle hls-download "$HLS_URL" --header "Authorization: $HLS_AUTHORIZATION"
```

Header files are read as data. They are never executed, imported as shell
scripts, or copied to a generated credential file. This interface does not
evaluate browser “copy as cURL” commands. `Host`, `Connection`, framing/proxy
headers, `Range`, and `Accept-Encoding` are reserved for the downloader rather
than accepted as arbitrary request overrides.

```sh
mantle hls-download "$HLS_URL" --diagnose --header-file "$HLS_HEADERS"
mantle hls-download "$HLS_URL" --dry-run --inherit-query --no-range
```

`--diagnose` fetches and classifies the initial master/media playlist and reports
an allowlisted request shape. It does not download segments. `--dry-run` is an
offline plan: no requests, media probes, files, or directories are created.
Neither mode prints credential values or the original URL.

The engine uses a loopback HTTP gateway with opaque resource IDs. Actual URLs,
query strings, header values, and playlist rewrites stay in memory. FFmpeg sees
only loopback URLs; its raw diagnostics and upstream response bodies are not
printed or saved. Ambient FFmpeg report-file settings are removed.

Values passed on this command's own command line can still be visible to local
process-inspection tools or shell history. An existing header file avoids
putting header values in arguments. Mantle does not make a shared or compromised
machine private.

Custom headers, cookies, and referer context are scoped to the source origin.
Cross-origin resource requests and redirects do not receive that private
context. HTTPS certificates are verified. Servers that require additional
authentication or a different authorized request context must supply it through
their supported access method.

## Signed queries and nested playlists

Normal URI resolution does not copy a parent playlist's query onto every child.
For a CDN that explicitly requires that behavior:

```sh
mantle hls-download "$HLS_URL" --inherit-query --output "episode.mkv"
```

This opt-in copies the parent's raw query only to a relative URI without its
own query and on the same origin. It applies to nested playlists, media
segments, ordinary keys, and initialization maps. Resolution always uses the
containing playlist. Existing child queries are preserved, and absolute URLs,
protocol-relative URLs, cross-origin destinations, and redirect targets do not
inherit a query. Signed text is not decoded and re-encoded.

To avoid a separate manifest read for a single-use or short-lived URL:

```sh
mantle hls-download "$HLS_URL" --no-preflight --inherit-query
```

The gateway still inspects every playlist before serving it to FFmpeg, including
child and refreshed live playlists. `--no-preflight` does not disable encryption
checks. With preflight enabled, the first manifest is reused for the first
FFmpeg request instead of being downloaded twice.

## Range compatibility and retries

Some CDNs reject opportunistic HTTP Range requests:

```sh
mantle hls-download "$HLS_URL" --no-range
mantle hls-download "$HLS_URL" --retry-count 0 --diagnose
```

`--no-range` disables FFmpeg HTTP seekability for the initial playlist and HLS
requests. Byte-range playlists and byte-range initialization maps inherently
need ranges, so they are refused in this mode rather than silently downloaded
incorrectly.

`--retry-count` defaults to `2` HLS segment retries and accepts `0` for fail-fast
operation. Deterministic HTTP client errors such as 401, 403, 404, and 422 abort
early even when retries are enabled. Timeout/transient failures remain bounded,
and any unresolved required-resource failure prevents publication. FFmpeg's
ability to skip a failed segment and exit successfully is not treated as a
complete download.

Useful diagnostics identify the resource kind and failure category, without
echoing the response or request secrets:

| Failure | Next check |
| --- | --- |
| 401 or 403 | Confirm authorization, expiry, and required request context. |
| 404 | Confirm the playlist or media resource still exists. |
| 422 | Check required headers, explicitly documented query inheritance, and Range compatibility. |
| Timeout or connection failure | Check connectivity and the `--timeout` setting. |
| Media/validation failure | Confirm the codecs fit the chosen container or try the explicit transcode mode. |

Low-level HTTP reconnect is a separate opt-in:

```sh
mantle hls-download "$HLS_URL" --http-reconnect
```

It requires FFmpeg's bounded reconnect options; builds without them return a
clear dependency error. EOF reconnect is disabled, including for finite media
responses. No global retry flags are silently enabled by the ordinary download
path.

## Live capture and encryption

```sh
mantle hls-download "$HLS_URL" --duration 60 --output "capture.mkv"
```

Use an explicit duration for a bounded live/event capture. Without one, a live
stream can continue until it ends or you interrupt it. Playlists can refresh
through the gateway while retaining the same query/context rules.

Ordinary identity AES-128 HLS is supported when the key is legitimately
accessible to the request. `METHOD=NONE` is supported. Other encryption methods,
SAMPLE-AES, and non-identity key formats are refused; Mantle does not obtain DRM
licenses or extract protected keys. Tests use generated media and synthetic
AES keys only.

## Output and interruption

The parent output directory must already exist. Mantle creates a private,
randomly named partial file beside the destination, runs FFmpeg against the
owned file, and checks the completed media with ffprobe. It publishes with an
atomic no-overwrite operation only after all checks pass. An existing output,
a competing output created during the download, or a symlink destination is
never replaced.

Use an output directory you control. The no-overwrite operation protects against
an output appearing during the download; it does not establish a security
boundary against a hostile process running as the same user and replacing
filesystem entries concurrently.

Failures and interruptions remove the owned partial by default. Pass
`--keep-partial` to retain incomplete media for inspection; it is not a validated
download and is not published under the requested final name. Ctrl-C stops
child media processes and returns `130`.

| Status | Meaning |
| --- | --- |
| `0` | Completed download or successful inspection. |
| `64` | Invalid usage or request metadata. |
| `65` | HTTP, playlist, encryption, media, or validation failure. |
| `69` | Missing dependency or required tool capability. |
| `73` | Output creation or publication failure. |
| `130` | Interrupted. |

## Existing `m3u8` utility

The legacy `m3u8` command keeps its existing MP4 default, local-playlist support,
flags, and exit codes. It is not an alias for this interface. New workflows
should use `mantle hls-download` for the redaction, retry, validation, and
publication contract described here.

## Local verification

```sh
./tests/run.sh tests/bin/hls-download.bats
./tests/run.sh tests/integration/hls-download.bats
```

The fixture generates a few seconds of video/audio locally, then serves VOD,
master, live/event, fMP4, and synthetic AES-128 streams on loopback addresses.
It also models missing/expired resources, 404/422, Range rejection, timeout,
finite/truncated EOF, malformed playlists, and refused encryption. Request
events record only route names and boolean request-shape facts.

The dedicated HLS workflow requires the fixture tests on Linux and macOS, using
the stock `/bin/bash` for Bash 3.2 coverage on macOS. It does not contact a live
media service or upload media/request artifacts. The generic integration suite
may skip these optional media tests when the local toolchain is unavailable.

Protocol references: [HLS RFC 8216](https://www.rfc-editor.org/rfc/rfc8216.html),
[FFmpeg HLS demuxer options](https://ffmpeg.org/ffmpeg-formats.html#hls), and
[FFmpeg HTTP options](https://ffmpeg.org/ffmpeg-protocols.html#http).
