#!/usr/bin/env bash
# shellcheck shell=bash
# Explicit HLS downloading; optional dependencies are never loaded by startup.

set -o errexit
set -o nounset
set -o pipefail

# @description Describe the canonical HLS downloader without Python or media tools.
# @stdout Public usage, options, and publication boundaries.
mantle_hls_download_usage() {
	printf "%s\n" \
		"Usage: mantle hls-download SOURCE [OPTIONS]" \
		"       hls-download SOURCE [OPTIONS]" \
		"" \
		"Download an HTTP(S) HLS playlist using FFmpeg and validate with ffprobe." \
		"Stream copy and Matroska (download.mkv) are the defaults. Existing outputs are preserved." \
		"" \
		"Options:" \
		"  --output FILE         Final output path; infer mkv/mp4/ts from its suffix." \
		"  --format mkv|mp4|ts   Set the output container explicitly." \
		"  --transcode          Encode H.264/AAC instead of copying streams." \
		"  --duration SECONDS   Limit recording duration (positive, at most 604800)." \
		"  --header NAME:VALUE  Add an HTTP header; may be repeated." \
		"  --header-file FILE   Read HTTP headers from a local file." \
		"  --referer URL        Set the HTTP Referer." \
		"  --user-agent VALUE   Set the HTTP User-Agent." \
		"  --cookie VALUE       Set an HTTP Cookie header." \
		"  --no-preflight       Skip the bounded playlist preflight request." \
		"  --inherit-query      Explicitly inherit query parameters in supported playlists." \
		"  --no-range           Disable opportunistic HTTP seeking; BYTERANGE is refused." \
		"  --retry-count COUNT  Retry failed segments 0..20 times; default 2." \
		"  --http-reconnect     Opt into bounded HTTP reconnects when FFmpeg supports them." \
		"  --timeout SECONDS    Network timeout; default 30, positive, at most 3600." \
		"  --diagnose           Classify the initial playlist and its request shape." \
		"  --dry-run            Print a redacted plan without network requests or file writes." \
		"  --keep-partial       Retain a failed partial output for explicit recovery." \
		"  --version            Print hls-download's interface version." \
		"  --help               Show this help without optional dependencies." \
		"" \
		"Python 3.9+, FFmpeg, and ffprobe are required for downloads. No tools are installed." \
		"Credentials are redacted from Mantle diagnostics; local process inspection can see arguments." \
		"Legacy m3u8 remains a separate MP4-default interface with its existing options." \
		"Exit codes: 0 success, 64 usage, 65 media failure, 69 dependency, 73 output, 130 interrupted."
}

case "${1:-}" in
--summary)
	printf "Download and validate HLS media with bounded retries and redacted diagnostics.\n"
	exit 0
	;;
--version)
	printf "hls-download 1.0.0\n"
	exit 0
	;;
esac

for mantle_hls_download_argument in "$@"; do
	[[ "${mantle_hls_download_argument}" != "--" ]] || break
	if [[ "${mantle_hls_download_argument}" == "--help" || "${mantle_hls_download_argument}" == "-h" ]]; then
		mantle_hls_download_usage
		exit 0
	fi
done

if (($# == 0)); then
	mantle_hls_download_usage >&2
	exit 64
fi

# Reject an unknown first option before checking optional dependencies. The
# Python parser owns complete argument validation and never echoes credential
# bearing inputs in its usage errors.
case "$1" in
--output | --format | --transcode | --duration | --header | --header-file | --referer | --user-agent | --cookie | --no-preflight | --inherit-query | --no-range | --retry-count | --http-reconnect | --timeout | --diagnose | --dry-run | --keep-partial | --) ;;
--output=* | --format=* | --duration=* | --header=* | --header-file=* | --referer=* | --user-agent=* | --cookie=* | --retry-count=* | --timeout=*) ;;
-*)
	printf "[mantle:error] invalid hls-download usage; run 'mantle hls-download --help'.\n" >&2
	exit 64
	;;
esac

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi
if ! command -v python3 >/dev/null 2>&1; then
	printf "[mantle:error] HLS downloads require Python 3.9 or newer (python3).\n" >&2
	exit 69
fi
exec python3 "${MANTLE_ROOT}/libexec/mantle/hls.py" "$@"
