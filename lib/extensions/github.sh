#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide opt-in GitHub release and tag-query helpers.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/extensions/github.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_GITHUB_EXTENSION_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_github_validate_repository() {
	[[ "${1:-}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]
}

__mantle_github_curl() {
	local request_url="${1:-}"
	local connect_timeout="${MANTLE_GITHUB_CONNECT_TIMEOUT:-10}"
	local request_timeout="${MANTLE_GITHUB_REQUEST_TIMEOUT:-30}"

	command -v curl >/dev/null 2>&1 || return 127
	if [[ ! "${connect_timeout}" =~ ^[1-9][0-9]*$ ||
		! "${request_timeout}" =~ ^[1-9][0-9]*$ ]]; then
		return 64
	fi
	if [[ -n "${GITHUB_TOKEN:-}" ]]; then
		curl \
			--connect-timeout "${connect_timeout}" \
			--fail \
			--header "Accept: application/vnd.github+json" \
			--header "Authorization: Bearer ${GITHUB_TOKEN}" \
			--header "X-GitHub-Api-Version: 2022-11-28" \
			--location \
			--max-time "${request_timeout}" \
			--show-error \
			--silent \
			"${request_url}"
	else
		curl \
			--connect-timeout "${connect_timeout}" \
			--fail \
			--header "Accept: application/vnd.github+json" \
			--header "X-GitHub-Api-Version: 2022-11-28" \
			--location \
			--max-time "${request_timeout}" \
			--show-error \
			--silent \
			"${request_url}"
	fi
}

# @description Fetch the latest GitHub release document for owner/repository.
# @arg $1 string GitHub repository slug.
mantle_github_latest_release_json() {
	local repository="${1:-}"

	if (($# != 1)) || ! __mantle_github_validate_repository "${repository}"; then
		return 64
	fi

	__mantle_github_curl "https://api.github.com/repos/${repository}/releases/latest"
}

# @description Read a release document from stdin and print its tag name.
mantle_github_release_tag() {
	command -v jq >/dev/null 2>&1 || return 127
	jq --exit-status --raw-output ".tag_name | select(type == \"string\" and length > 0)"
}

# @description Read a release document from stdin and print its tarball URL.
mantle_github_release_tarball_url() {
	command -v jq >/dev/null 2>&1 || return 127
	jq --exit-status --raw-output ".tarball_url | select(type == \"string\" and length > 0)"
}

# @description Read a release document from stdin and print its publication timestamp.
mantle_github_release_published_at() {
	command -v jq >/dev/null 2>&1 || return 127
	jq --exit-status --raw-output ".published_at | select(type == \"string\" and length > 0)"
}

# @description Resolve a GitHub tag to its commit SHA, including annotated tags.
# @arg $1 string GitHub repository slug.
# @arg $2 string Tag name.
mantle_github_commit_sha_for_tag() {
	local repository="${1:-}"
	local tag_name="${2:-}"

	if (($# != 2)) || ! __mantle_github_validate_repository "${repository}" ||
		[[ -z "${tag_name}" || "${tag_name}" == -* || "${tag_name}" == *[[:space:]]* ]]; then
		return 64
	fi
	command -v git >/dev/null 2>&1 || return 127
	git check-ref-format "refs/tags/${tag_name}" >/dev/null 2>&1 || return 64

	git ls-remote \
		"https://github.com/${repository}.git" \
		"refs/tags/${tag_name}" \
		"refs/tags/${tag_name}^{}" |
		awk -v peeled="refs/tags/${tag_name}^{}" '
			$2 == peeled { peeled_sha = $1 }
			$2 != peeled && direct_sha == "" { direct_sha = $1 }
			END {
				if (peeled_sha != "") print peeled_sha
				else if (direct_sha != "") print direct_sha
				else exit 1
			}'
}

MANTLE_GITHUB_EXTENSION_LOADED="1"

return 0
