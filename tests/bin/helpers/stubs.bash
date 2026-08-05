#!/usr/bin/env bash
# shellcheck shell=bash
#
# Stub helpers for bin/ CLI tests.
#
# Source this file from Bats test files:
#   load '../helpers/stubs'

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "helpers/stubs.bash must be sourced by Bats, not executed directly\n" >&2
	exit 1
fi

# ---------------------------------------------------------------------------
# Low-level stub creation
# ---------------------------------------------------------------------------

# make_stub — create a simple stub in BIN_STUB_DIR.
# Usage: make_stub NAME [exit_code [output]]
make_stub() {
	local name="${1:?make_stub requires a name}"
	local exit_code="${2:-0}"
	local output="${3:-}"
	local stub_path="${BIN_STUB_DIR:?bin_test_setup must be called first}/${name}"
	{
		printf "#!/bin/sh\n"
		if [[ -n "${output}" ]]; then
			printf 'printf "%%s\\n" %q\n' "${output}"
		fi
		printf "exit %d\n" "${exit_code}"
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}

# make_recording_stub — create a stub that records its arguments.
# Arguments are written one-per-line to "${BIN_STUB_DIR}/${name}.calls".
# Usage: make_recording_stub NAME [exit_code [output]]
make_recording_stub() {
	local name="${1:?make_recording_stub requires a name}"
	local exit_code="${2:-0}"
	local output="${3:-}"
	local stub_path="${BIN_STUB_DIR:?}/${name}"
	local record_file="${BIN_STUB_DIR}/${name}.calls"
	{
		printf "#!/bin/sh\n"
		printf 'printf "%%s\\n" "$*" >> %q\n' "${record_file}"
		if [[ -n "${output}" ]]; then
			printf 'printf "%%s\\n" %q\n' "${output}"
		fi
		printf "exit %d\n" "${exit_code}"
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}

# recording_stub_calls — print the number of times a recording stub was called.
recording_stub_calls() {
	local name="${1:?}"
	local record_file="${BIN_STUB_DIR:-/dev/null}/${name}.calls"
	if [[ -f "${record_file}" ]]; then
		wc -l <"${record_file}" | tr -d ' '
	else
		printf "0\n"
	fi
}

# recording_stub_args — print the recorded argument line(s) for a stub.
recording_stub_args() {
	local name="${1:?}"
	local record_file="${BIN_STUB_DIR:-/dev/null}/${name}.calls"
	if [[ -f "${record_file}" ]]; then
		cat "${record_file}"
	fi
}

# ---------------------------------------------------------------------------
# Domain-specific stubs
# ---------------------------------------------------------------------------

# stub_openssl — stub openssl; default outputs a fake base64 password.
stub_openssl() {
	local output="${1:-ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij}"
	make_stub "openssl" 0 "${output}"
}

# stub_openssl_fail — stub openssl to fail.
stub_openssl_fail() {
	make_stub "openssl" 1 ""
}

# stub_curl_success — stub curl to succeed (optionally write body to -o file).
stub_curl_success() {
	local body="${1:-stub-response}"
	local stub_path="${BIN_STUB_DIR:?}/curl"
	{
		printf "#!/bin/sh\n"
		printf 'body=%q\n' "${body}"
		printf 'out=""\n'
		printf 'while [ "$#" -gt 0 ]; do\n'
		printf '  case "$1" in\n'
		printf '    -o|--output) out="$2"; shift 2 ;;\n'
		printf '    *) shift ;;\n'
		printf '  esac\n'
		printf 'done\n'
		printf '[ -n "$out" ] && printf "%%s" "$body" > "$out"\n'
		printf 'exit 0\n'
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}

# stub_curl_fail — stub curl to fail.
stub_curl_fail() {
	make_stub "curl" 1 ""
}

# stub_gh — stub the GitHub CLI; default succeeds with empty output.
stub_gh() {
	local exit_code="${1:-0}"
	local output="${2:-}"
	make_recording_stub "gh" "${exit_code}" "${output}"
}

# stub_git — stub git; pass-through to real git for everything except
# network commands, which are stubbed to succeed.
stub_git() {
	local stub_path="${BIN_STUB_DIR:?}/git"
	local real_git
	real_git="$(command -v git 2>/dev/null || echo /usr/bin/git)"
	{
		printf "#!/bin/sh\n"
		printf 'case "$1" in\n'
		printf '  push|pull|fetch|clone|remote) exit 0 ;;\n'
		printf '  *) exec %q "$@" ;;\n' "${real_git}"
		printf 'esac\n'
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}

# stub_docker — stub docker to record calls and succeed.
stub_docker() {
	local exit_code="${1:-0}"
	make_recording_stub "docker" "${exit_code}" ""
}

# stub_sudo — stub sudo to run the given command directly (no privilege).
stub_sudo() {
	local stub_path="${BIN_STUB_DIR:?}/sudo"
	{
		printf "#!/bin/sh\n"
		printf 'exec "$@"\n'
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}

# stub_sudo_fail — stub sudo to always fail.
stub_sudo_fail() {
	make_stub "sudo" 1 ""
}

# stub_ffmpeg — stub ffmpeg to record calls and succeed.
stub_ffmpeg() {
	make_recording_stub "ffmpeg" 0 ""
}

# stub_ffmpeg_fail — stub ffmpeg to fail.
stub_ffmpeg_fail() {
	make_stub "ffmpeg" 1 ""
}

# stub_lsof — stub lsof to return empty output.
stub_lsof() {
	make_stub "lsof" 0 ""
}

# stub_ss — stub ss to return empty output.
stub_ss() {
	make_stub "ss" 0 ""
}

# stub_jq — stub jq to return fixed output.
stub_jq() {
	local output="${1:-{}}"
	make_stub "jq" 0 "${output}"
}

# stub_python3_success — stub python3 to succeed.
stub_python3_success() {
	make_stub "python3" 0 "${1:-}"
}

# stub_apt_get — stub apt-get to record calls and succeed.
stub_apt_get() {
	make_recording_stub "apt-get" 0 ""
}

# stub_dpkg — stub dpkg to record calls and succeed.
stub_dpkg() {
	local output="${1:-}"
	make_stub "dpkg" 0 "${output}"
}

# stub_pbcopy — stub pbcopy to record calls and succeed.
stub_pbcopy() {
	make_recording_stub "pbcopy" 0 ""
}

# stub_wl_copy — stub wl-copy to record calls and succeed.
stub_wl_copy() {
	make_recording_stub "wl-copy" 0 ""
}

# stub_xclip — stub xclip to record calls and succeed.
stub_xclip() {
	make_recording_stub "xclip" 0 ""
}

# stub_xsel — stub xsel to record calls and succeed.
stub_xsel() {
	make_recording_stub "xsel" 0 ""
}

# stub_gcloud — stub gcloud to record calls and succeed.
stub_gcloud() {
	make_recording_stub "gcloud" 0 "${1:-}"
}

# stub_yt_dlp — stub yt-dlp to record calls and succeed.
stub_yt_dlp() {
	make_recording_stub "yt-dlp" 0 ""
}

# stub_convert — stub ImageMagick convert to record calls and succeed.
stub_convert() {
	make_recording_stub "convert" 0 ""
}

# stub_magick — stub ImageMagick magick to record calls and succeed.
stub_magick() {
	make_recording_stub "magick" 0 ""
}

# stub_fc_list — stub fc-list to return fixed output.
stub_fc_list() {
	local output="${1:-/usr/share/fonts/truetype/DejaVuSans.ttf: DejaVu Sans:style=Book}"
	make_stub "fc-list" 0 "${output}"
}

# stub_uname — stub uname to return a controllable OS name.
stub_uname() {
	local sysname="${1:-Linux}"
	make_stub "uname" 0 "${sysname}"
}

# stub_tee — pass-through tee stub.
stub_tee() {
	local stub_path="${BIN_STUB_DIR:?}/tee"
	{
		printf "#!/bin/sh\n"
		printf 'exec /usr/bin/tee "$@"\n'
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}
