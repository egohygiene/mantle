#!/usr/bin/env bats
# Unit tests for lib/install/archive.sh

setup() {
	load '../../test_helper/common'
	load '../../test_helper/assertions'
	load '../../test_helper/fixtures'
	setup_isolated_home
	setup_stub_dir
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

_bash_archive() {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/install/runtime.sh'
		$*
	"
}

# ---------------------------------------------------------------------------
# mantle_install_archive_format — format detection
# ---------------------------------------------------------------------------

@test "archive_format returns tar.gz for .tar.gz file" {
	_bash_archive "mantle_install_archive_format 'tool.tar.gz'"
	assert_success
	assert_output_contains "tar.gz"
}

@test "archive_format returns tar.gz for .tgz file" {
	_bash_archive "mantle_install_archive_format 'tool.tgz'"
	assert_success
	assert_output_contains "tar.gz"
}

@test "archive_format returns tar.xz for .tar.xz file" {
	_bash_archive "mantle_install_archive_format 'tool.tar.xz'"
	assert_success
	assert_output_contains "tar.xz"
}

@test "archive_format returns zip for .zip file" {
	_bash_archive "mantle_install_archive_format 'tool.zip'"
	assert_success
	assert_output_contains "zip"
}

@test "archive_format returns raw for an unrecognized extension" {
	_bash_archive "mantle_install_archive_format 'binary'"
	assert_success
	assert_output_contains "raw"
}

@test "archive_format returns 64 with no arguments" {
	_bash_archive "mantle_install_archive_format; printf '%d\n' \$?"
	assert_output_contains "64"
}

# ---------------------------------------------------------------------------
# mantle_install_archive_extract — extraction
# ---------------------------------------------------------------------------

@test "archive_extract extracts a .tar.gz archive" {
	# Create a real .tar.gz archive
	local src_dir="${TEST_HOME}/src"
	mkdir -p "${src_dir}"
	printf "hello\n" >"${src_dir}/hello.txt"
	local archive="${TEST_HOME}/hello.tar.gz"
	tar -czf "${archive}" -C "${src_dir}" "hello.txt"

	local dest_dir="${TEST_HOME}/dest"
	_bash_archive "mantle_install_archive_extract '${archive}' '${dest_dir}' 'hello.txt'"
	assert_success
	assert_file_exists "${dest_dir}/hello.txt"
}

@test "archive_extract copies a raw artifact" {
	local raw_file="${TEST_HOME}/mybinary"
	printf "#!/bin/sh\necho hi\n" >"${raw_file}"
	chmod 0755 "${raw_file}"
	local dest_dir="${TEST_HOME}/raw_dest"

	_bash_archive "mantle_install_archive_extract '${raw_file}' '${dest_dir}'"
	assert_success
	assert_file_exists "${dest_dir}/mybinary"
}

@test "archive_extract returns 64 for missing arguments" {
	_bash_archive "mantle_install_archive_extract; printf '%d\n' \$?"
	assert_output_contains "64"
}

@test "archive_extract rejects traversal member paths" {
	local archive="${TEST_HOME}/safe.tar.gz"
	local src="${TEST_HOME}/safe_src"
	mkdir -p "${src}"
	printf "x" >"${src}/x.txt"
	tar -czf "${archive}" -C "${src}" "x.txt"
	local dest="${TEST_HOME}/safe_dest"

	_bash_archive "
		mantle_install_archive_extract '${archive}' '${dest}' '../etc/passwd'
		printf '%d\n' \$?
	"
	assert_output_contains "64"
}

@test "archive.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/install/archive.sh"
	assert_status 64
}
