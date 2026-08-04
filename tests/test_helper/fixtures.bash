#!/usr/bin/env bash
# shellcheck shell=bash
#
# Fixture helpers for the Mantle test suite.
#
# Source this file from test files:
#   load '../test_helper/fixtures'

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "test_helper/fixtures.bash must be sourced by Bats, not executed directly\n" >&2
	exit 1
fi

# ---------------------------------------------------------------------------
# Fixture directory.
# ---------------------------------------------------------------------------

MANTLE_FIXTURE_DIR="${MANTLE_TEST_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/fixtures"
export MANTLE_FIXTURE_DIR

# ---------------------------------------------------------------------------
# Archive fixtures.
# ---------------------------------------------------------------------------

# create_tar_gz_fixture — create a minimal .tar.gz archive in the fixture dir.
# Usage: create_tar_gz_fixture ARCHIVE_NAME MEMBER_NAME CONTENT
create_tar_gz_fixture() {
	local archive_name="${1:?}"
	local member_name="${2:?}"
	local content="${3:-test content}"
	local archive_path="${MANTLE_FIXTURE_DIR}/archives/${archive_name}"
	local tmp_dir
	tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/mantle-fixture-XXXXXX")"

	printf "%s\n" "${content}" >"${tmp_dir}/${member_name}"
	tar -czf "${archive_path}" -C "${tmp_dir}" "${member_name}" 2>/dev/null
	rm -rf "${tmp_dir}"
}

# ---------------------------------------------------------------------------
# Checksum fixtures.
# ---------------------------------------------------------------------------

# write_checksum_fixture — create a sha256sum-format checksum file.
# Usage: write_checksum_fixture CHECKSUM_FILE DIGEST FILENAME
write_checksum_fixture() {
	local checksum_file="${1:?}"
	local digest="${2:?}"
	local filename="${3:?}"
	printf "%s  %s\n" "${digest}" "${filename}" >"${checksum_file}"
}

# ---------------------------------------------------------------------------
# GitHub API response fixtures.
# ---------------------------------------------------------------------------

# github_release_fixture — print a minimal GitHub release JSON object.
# Usage: github_release_fixture TAG_NAME [ASSET_NAME]
github_release_fixture() {
	local tag_name="${1:-v1.0.0}"
	local asset_name="${2:-tool_x86_64-unknown-linux-gnu.tar.gz}"
	local asset_download_url="https://example.invalid/download/${asset_name}"

	printf '{
  "tag_name": "%s",
  "assets": [
    {
      "name": "%s",
      "browser_download_url": "%s",
      "size": 1024
    }
  ]
}\n' "${tag_name}" "${asset_name}" "${asset_download_url}"
}

# ---------------------------------------------------------------------------
# Temporary Mantle tree helpers.
# ---------------------------------------------------------------------------

# create_mantle_tree — copy a subset of the Mantle tree into a temp directory
# so that tests can modify it without touching the real sources.
create_mantle_tree() {
	local tree_dir
	tree_dir="$(mktemp -d "${TMPDIR:-/tmp}/mantle-tree-XXXXXX")"
	cp -r \
		"${MANTLE_ROOT}/.shellrc" \
		"${MANTLE_ROOT}/bin" \
		"${MANTLE_ROOT}/init" \
		"${MANTLE_ROOT}/lib" \
		"${MANTLE_ROOT}/libexec" \
		"${MANTLE_ROOT}/modules" \
		"${MANTLE_ROOT}/platforms" \
		"${MANTLE_ROOT}/runtime" \
		"${tree_dir}/"
	printf "%s\n" "${tree_dir}"
}
