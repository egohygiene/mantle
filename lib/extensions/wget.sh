#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide opt-in helpers for common GNU Wget workflows.
#
# Load with:
#   mantle_load_extension "wget"
#
# This library does not require Wget until a download helper is called, and it
# does not change the caller's shell options, traps, working directory, or
# environment.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]:-}" == "$0" ]]; then
	printf "[mantle:error] lib/extensions/wget.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_WGET_EXTENSION_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${BASH_VERSION:-}" && -z "${ZSH_VERSION:-}" ]]; then
	printf "[mantle:error] lib/extensions/wget.sh requires Bash or Zsh\n" >&2
	return 64
fi

# @description Print a Wget-helper error message to standard error.
# @arg $1 string Error message.
# @internal
__mantle_wget_error() {
	printf "[mantle:error] wget: %s\n" "${1:-unknown error}" >&2
}

# @description Verify that GNU Wget is available.
# @exitcode 0 Wget is available.
# @exitcode 127 Wget is unavailable.
# @internal
__mantle_wget_require_command() {
	if ! command -v wget >/dev/null 2>&1; then
		__mantle_wget_error "GNU Wget is required but was not found on PATH"
		return 127
	fi
}

# @description Require a nonempty function argument.
# @arg $1 string Argument value.
# @arg $2 string Human-readable argument name.
# @exitcode 0 The argument is nonempty.
# @exitcode 64 The argument is empty.
# @internal
__mantle_wget_require_argument() {
	if [[ -z "${1:-}" ]]; then
		__mantle_wget_error "missing ${2:-argument}"
		return 64
	fi
}

# @description Download a URL using Wget's normal filename behavior.
# @arg $1 string URL to download.
# @arg $@ any Additional Wget options.
# @example mantle_wget_get "https://example.com/file.zip" --quiet
mantle_wget_get() {
	local url="${1:-}"

	__mantle_wget_require_argument "${url}" "URL" || return
	shift
	__mantle_wget_require_command || return
	command wget "$@" -- "${url}"
}

# @description Download a URL to an explicit output file.
# @arg $1 string URL to download.
# @arg $2 path Output file.
# @arg $@ any Additional Wget options.
# @example mantle_wget_save "https://example.com/page" "./page.html"
mantle_wget_save() {
	local url="${1:-}"
	local output="${2:-}"

	__mantle_wget_require_argument "${url}" "URL" || return
	__mantle_wget_require_argument "${output}" "output file" || return
	shift 2
	__mantle_wget_require_command || return
	command wget "$@" --output-document="${output}" -- "${url}"
}

# @description Download a URL into a destination directory.
# @arg $1 string URL to download.
# @arg $2 path Destination directory.
# @arg $@ any Additional Wget options.
# @example mantle_wget_into "https://example.com/file.iso" "./downloads"
mantle_wget_into() {
	local url="${1:-}"
	local directory="${2:-}"

	__mantle_wget_require_argument "${url}" "URL" || return
	__mantle_wget_require_argument "${directory}" "destination directory" || return
	shift 2
	__mantle_wget_require_command || return
	mkdir -p -- "${directory}" || return
	command wget "$@" --directory-prefix="${directory}" -- "${url}"
}

# @description Resume a partially downloaded file when possible.
# @arg $1 string URL to download.
# @arg $@ any Additional Wget options.
# @example mantle_wget_resume "https://example.com/large.iso"
mantle_wget_resume() {
	local url="${1:-}"

	__mantle_wget_require_argument "${url}" "URL" || return
	shift
	__mantle_wget_require_command || return
	command wget "$@" --continue -- "${url}"
}

# @description Download a URL only when the remote copy is newer.
# @arg $1 string URL to download.
# @arg $@ any Additional Wget options.
# @example mantle_wget_update "https://example.com/latest.zip"
mantle_wget_update() {
	local url="${1:-}"

	__mantle_wget_require_argument "${url}" "URL" || return
	shift
	__mantle_wget_require_command || return
	command wget "$@" --timestamping --continue -- "${url}"
}

# @description Download URLs listed one per line in a file.
# @arg $1 path Text file containing URLs.
# @arg $@ any Additional Wget options.
# @example mantle_wget_list "./urls.txt" --directory-prefix="downloads"
mantle_wget_list() {
	local url_file="${1:-}"

	__mantle_wget_require_argument "${url_file}" "URL list file" || return
	if [[ ! -r "${url_file}" ]]; then
		__mantle_wget_error "URL list is not readable: ${url_file}"
		return 66
	fi
	shift
	__mantle_wget_require_command || return
	command wget "$@" --input-file="${url_file}"
}

# @description Download a numeric URL sequence without eval or brace expansion.
# @arg $1 string URL template containing the literal token {n}.
# @arg $2 integer First number.
# @arg $3 integer Last number.
# @arg $4 path Destination directory.
# @example mantle_wget_sequence "https://example.com/image-{n}.jpg" 1 20 "./images"
mantle_wget_sequence() {
	local template="${1:-}"
	local first="${2:-}"
	local last="${3:-}"
	local directory="${4:-}"
	local number=""
	local url=""
	local status=0

	__mantle_wget_require_argument "${template}" "URL template" || return
	__mantle_wget_require_argument "${first}" "first number" || return
	__mantle_wget_require_argument "${last}" "last number" || return
	__mantle_wget_require_argument "${directory}" "destination directory" || return
	if [[ "${template}" != *"{n}"* ]]; then
		__mantle_wget_error "URL template must contain {n}"
		return 64
	fi
	if [[ ! "${first}" =~ ^(0|[1-9][0-9]*)$ ||
		! "${last}" =~ ^(0|[1-9][0-9]*)$ ]] || ((first > last)); then
		__mantle_wget_error "sequence bounds must be nonnegative integers in ascending order"
		return 64
	fi

	__mantle_wget_require_command || return
	mkdir -p -- "${directory}" || return
	for ((number = first; number <= last; number += 1)); do
		url="${template//\{n\}/${number}}"
		command wget --directory-prefix="${directory}" -- "${url}" || status=$?
	done
	return "${status}"
}

# @description Save one web page with the assets needed for offline viewing.
# @arg $1 string Page URL.
# @arg $2 path Destination directory.
# @arg $@ any Additional Wget options.
# @example mantle_wget_page "https://example.com/article" "./offline-article"
mantle_wget_page() {
	local url="${1:-}"
	local directory="${2:-}"

	__mantle_wget_require_argument "${url}" "page URL" || return
	__mantle_wget_require_argument "${directory}" "destination directory" || return
	shift 2
	__mantle_wget_require_command || return
	mkdir -p -- "${directory}" || return
	command wget \
		--page-requisites \
		--convert-links \
		--adjust-extension \
		--span-hosts \
		--directory-prefix="${directory}" \
		"$@" \
		-- "${url}"
}

# @description Mirror a website for offline viewing with server-friendly pacing.
# @arg $1 string Root URL to mirror.
# @arg $2 path Destination directory.
# @arg $@ any Additional Wget options.
# @example mantle_wget_mirror "https://example.com" "./example-mirror"
mantle_wget_mirror() {
	local url="${1:-}"
	local directory="${2:-}"

	__mantle_wget_require_argument "${url}" "website URL" || return
	__mantle_wget_require_argument "${directory}" "destination directory" || return
	shift 2
	__mantle_wget_require_command || return
	mkdir -p -- "${directory}" || return
	command wget \
		--mirror \
		--continue \
		--no-parent \
		--page-requisites \
		--convert-links \
		--adjust-extension \
		--wait=1 \
		--random-wait \
		--directory-prefix="${directory}" \
		"$@" \
		-- "${url}"
}

# @description Recursively download selected file extensions from a URL tree.
# @arg $1 string Root URL.
# @arg $2 string Comma-separated extensions, such as mp3,MP3.
# @arg $3 path Destination directory.
# @arg $4 integer Optional recursion depth; defaults to 1.
# @arg $@ any Additional Wget options.
# @example mantle_wget_files "https://example.com/media" "mp3,MP3" "./audio" 2
mantle_wget_files() {
	local url="${1:-}"
	local extensions="${2:-}"
	local directory="${3:-}"
	local depth="${4:-1}"

	__mantle_wget_require_argument "${url}" "root URL" || return
	__mantle_wget_require_argument "${extensions}" "extension list" || return
	__mantle_wget_require_argument "${directory}" "destination directory" || return
	if [[ ! "${depth}" =~ ^(0|[1-9][0-9]*)$ ]]; then
		__mantle_wget_error "recursion depth must be a nonnegative integer"
		return 64
	fi
	shift $(($# >= 4 ? 4 : 3))
	__mantle_wget_require_command || return
	mkdir -p -- "${directory}" || return
	command wget \
		--recursive \
		--level="${depth}" \
		--no-parent \
		--no-clobber \
		--accept="${extensions}" \
		--directory-prefix="${directory}" \
		"$@" \
		-- "${url}"
}

# @description Download common web image formats from a URL tree.
# @arg $1 string Root URL.
# @arg $2 path Destination directory.
# @arg $@ any Additional Wget options.
# @example mantle_wget_images "https://example.com/images" "./pictures"
mantle_wget_images() {
	local url="${1:-}"
	local directory="${2:-}"

	__mantle_wget_require_argument "${url}" "root URL" || return
	__mantle_wget_require_argument "${directory}" "destination directory" || return
	shift 2
	mantle_wget_files \
		"${url}" \
		"jpg,jpeg,png,gif,webp,avif,svg,JPG,JPEG,PNG,GIF,WEBP,AVIF,SVG" \
		"${directory}" \
		1 \
		--no-directories \
		"$@"
}

# @description Download PDF files while restricting recursion to named domains.
# @arg $1 string Root URL.
# @arg $2 string Comma-separated allowed domains.
# @arg $3 path Destination directory.
# @arg $@ any Additional Wget options.
# @example mantle_wget_pdfs "https://example.com" "example.com,files.example.com" "./pdfs"
mantle_wget_pdfs() {
	local url="${1:-}"
	local domains="${2:-}"
	local directory="${3:-}"

	__mantle_wget_require_argument "${url}" "root URL" || return
	__mantle_wget_require_argument "${domains}" "domain list" || return
	__mantle_wget_require_argument "${directory}" "destination directory" || return
	shift 3
	mantle_wget_files \
		"${url}" \
		"pdf,PDF" \
		"${directory}" \
		0 \
		--domains="${domains}" \
		"$@"
}

# @description Mirror a website while excluding selected URL directories.
# @arg $1 string Root URL.
# @arg $2 string Comma-separated URL paths to exclude.
# @arg $3 path Destination directory.
# @arg $@ any Additional Wget options.
# @example mantle_wget_mirror_except "https://example.com" "/forums,/support" "./mirror"
mantle_wget_mirror_except() {
	local url="${1:-}"
	local exclusions="${2:-}"
	local directory="${3:-}"

	__mantle_wget_require_argument "${url}" "website URL" || return
	__mantle_wget_require_argument "${exclusions}" "excluded directories" || return
	__mantle_wget_require_argument "${directory}" "destination directory" || return
	shift 3
	mantle_wget_mirror \
		"${url}" \
		"${directory}" \
		--exclude-directories="${exclusions}" \
		"$@"
}

# @description Download a URL with explicit Referer and User-Agent headers.
# @arg $1 string URL to download.
# @arg $2 string Referer URL.
# @arg $3 string User-Agent value.
# @arg $@ any Additional Wget options.
# @example mantle_wget_with_identity "URL" "https://example.com" "Mozilla/5.0"
mantle_wget_with_identity() {
	local url="${1:-}"
	local referer="${2:-}"
	local user_agent="${3:-}"

	__mantle_wget_require_argument "${url}" "URL" || return
	__mantle_wget_require_argument "${referer}" "Referer URL" || return
	__mantle_wget_require_argument "${user_agent}" "User-Agent" || return
	shift 3
	__mantle_wget_require_command || return
	command wget \
		--referer="${referer}" \
		--user-agent="${user_agent}" \
		"$@" \
		-- "${url}"
}

# @description Download via HTTP Basic authentication without putting a password in shell history.
# @arg $1 string URL to download.
# @arg $2 string HTTP username.
# @arg $@ any Additional Wget options.
# @example mantle_wget_basic_auth "https://example.com/private.zip" "alan"
mantle_wget_basic_auth() {
	local url="${1:-}"
	local username="${2:-}"

	__mantle_wget_require_argument "${url}" "URL" || return
	__mantle_wget_require_argument "${username}" "HTTP username" || return
	shift 2
	__mantle_wget_require_command || return
	command wget \
		--http-user="${username}" \
		--ask-password \
		"$@" \
		-- "${url}"
}

# @description Establish a form-login cookie session, then fetch a protected URL.
# @arg $1 string Login form action URL.
# @arg $2 string Protected URL to fetch after login.
# @arg $3 path Optional cookie jar; a temporary file is used by default.
# @arg $@ any Additional Wget options for the protected request.
# @example printf "%s\n" "user=alan&password=secret" | mantle_wget_form_login "LOGIN_URL" "PAGE_URL"
# @note Reads the URL-encoded form body from standard input to keep it out of shell history.
mantle_wget_form_login() {
	local login_url="${1:-}"
	local protected_url="${2:-}"
	local cookie_jar="${3:-}"
	local post_data=""
	local post_file=""
	local status=0
	local temporary_cookie=0

	__mantle_wget_require_argument "${login_url}" "login URL" || return
	__mantle_wget_require_argument "${protected_url}" "protected URL" || return
	shift $(($# >= 3 ? 3 : 2))
	__mantle_wget_require_command || return

	if [[ -z "${cookie_jar}" ]]; then
		cookie_jar="$(mktemp "${TMPDIR:-/tmp}/mantle-wget-cookies.XXXXXX")" || return
		temporary_cookie=1
	fi
	if ! IFS= read -r post_data && [[ -z "${post_data}" ]]; then
		__mantle_wget_error "expected URL-encoded login form data on standard input"
		if ((temporary_cookie == 1)); then
			rm -f -- "${cookie_jar}"
		fi
		return 64
	fi
	post_file="$(mktemp "${TMPDIR:-/tmp}/mantle-wget-login.XXXXXX")" || {
		if ((temporary_cookie == 1)); then
			rm -f -- "${cookie_jar}"
		fi
		return 1
	}
	chmod 0600 -- "${post_file}" || {
		rm -f -- "${post_file}"
		if ((temporary_cookie == 1)); then
			rm -f -- "${cookie_jar}"
		fi
		return 1
	}
	printf "%s" "${post_data}" >"${post_file}"

	command wget \
		--quiet \
		--output-document=/dev/null \
		--save-cookies="${cookie_jar}" \
		--keep-session-cookies \
		--post-file="${post_file}" \
		-- "${login_url}"
	status=$?
	rm -f -- "${post_file}"

	if ((status == 0)); then
		command wget --load-cookies="${cookie_jar}" "$@" -- "${protected_url}"
		status=$?
	fi

	if ((temporary_cookie == 1)); then
		rm -f -- "${cookie_jar}"
	fi
	return "${status}"
}

# @description Print response headers and remote file metadata without downloading the body.
# @arg $1 string URL to inspect.
# @arg $@ any Additional Wget options.
# @example mantle_wget_info "https://example.com/file.iso"
mantle_wget_info() {
	local url="${1:-}"

	__mantle_wget_require_argument "${url}" "URL" || return
	shift
	__mantle_wget_require_command || return
	command wget --spider --server-response "$@" -- "${url}"
}

# @description Stream a remote resource to standard output without saving it.
# @arg $1 string URL to fetch.
# @arg $@ any Additional Wget options.
# @example mantle_wget_stdout "https://example.com/humans.txt"
mantle_wget_stdout() {
	local url="${1:-}"

	__mantle_wget_require_argument "${url}" "URL" || return
	shift
	__mantle_wget_require_command || return
	command wget --quiet --output-document=- "$@" -- "${url}"
}

# @description Recursively check a website's links without downloading pages.
# @arg $1 string Root URL to check.
# @arg $2 path Optional log file; defaults to wget-link-check.log.
# @arg $@ any Additional Wget options.
# @example mantle_wget_check_links "https://example.com" "./broken-links.log"
mantle_wget_check_links() {
	local url="${1:-}"
	local log_file="${2:-wget-link-check.log}"

	__mantle_wget_require_argument "${url}" "website URL" || return
	shift $(($# >= 2 ? 2 : 1))
	__mantle_wget_require_command || return
	command wget \
		--recursive \
		--spider \
		--output-file="${log_file}" \
		"$@" \
		-- "${url}"
}

# @description Mirror a website with an explicit bandwidth limit and delay.
# @arg $1 string Root URL.
# @arg $2 path Destination directory.
# @arg $3 string Optional Wget rate value, such as 200k or 2m.
# @arg $4 integer Optional base delay in seconds.
# @arg $@ any Additional Wget options.
# @example mantle_wget_polite_mirror "https://example.com" "./mirror" "200k" 3
mantle_wget_polite_mirror() {
	local url="${1:-}"
	local directory="${2:-}"
	local rate="${3:-200k}"
	local wait_seconds="${4:-3}"

	__mantle_wget_require_argument "${url}" "website URL" || return
	__mantle_wget_require_argument "${directory}" "destination directory" || return
	if [[ ! "${wait_seconds}" =~ ^(0|[1-9][0-9]*)$ ]]; then
		__mantle_wget_error "wait duration must be a nonnegative integer"
		return 64
	fi
	shift $(($# >= 4 ? 4 : $#))
	mantle_wget_mirror \
		"${url}" \
		"${directory}" \
		--limit-rate="${rate}" \
		--wait="${wait_seconds}" \
		--random-wait \
		"$@"
}

# @description Print the Wget-helper reference.
mantle_wget_help() {
	if (($# != 0)); then
		__mantle_wget_error "mantle_wget_help does not accept arguments"
		return 64
	fi

	printf "%s\n" \
		"Mantle Wget helpers — common GNU Wget workflows" \
		"" \
		"Load this optional extension:" \
		"" \
		"  mantle_load_extension \"wget\"" \
		"" \
		"Then call:" \
		"" \
		"  mantle_wget_get URL [WGET_OPTION...]" \
		"  mantle_wget_save URL FILE [WGET_OPTION...]" \
		"  mantle_wget_into URL DIRECTORY [WGET_OPTION...]" \
		"  mantle_wget_resume URL [WGET_OPTION...]" \
		"  mantle_wget_update URL [WGET_OPTION...]" \
		"  mantle_wget_list URL_FILE [WGET_OPTION...]" \
		"  mantle_wget_sequence URL_WITH_{n} FIRST LAST DIRECTORY" \
		"  mantle_wget_page URL DIRECTORY [WGET_OPTION...]" \
		"  mantle_wget_mirror URL DIRECTORY [WGET_OPTION...]" \
		"  mantle_wget_files URL EXTENSIONS DIRECTORY [DEPTH] [WGET_OPTION...]" \
		"  mantle_wget_images URL DIRECTORY [WGET_OPTION...]" \
		"  mantle_wget_pdfs URL DOMAINS DIRECTORY [WGET_OPTION...]" \
		"  mantle_wget_mirror_except URL EXCLUSIONS DIRECTORY [WGET_OPTION...]" \
		"  mantle_wget_with_identity URL REFERER USER_AGENT [WGET_OPTION...]" \
		"  mantle_wget_basic_auth URL USERNAME [WGET_OPTION...]" \
		"  mantle_wget_form_login LOGIN_URL PROTECTED_URL [COOKIE_FILE] [WGET_OPTION...]" \
		"  mantle_wget_info URL [WGET_OPTION...]" \
		"  mantle_wget_stdout URL [WGET_OPTION...]" \
		"  mantle_wget_check_links URL [LOG_FILE] [WGET_OPTION...]" \
		"  mantle_wget_polite_mirror URL DIRECTORY [RATE] [WAIT_SECONDS] [WGET_OPTION...]" \
		"" \
		"Crawlers respect robots.txt unless you explicitly pass --execute=robots=off." \
		"Only crawl content you are authorized to retrieve."
}

MANTLE_WGET_EXTENSION_LOADED="1"

return 0
