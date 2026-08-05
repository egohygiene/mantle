#!/usr/bin/env bats
# Behavioral tests for bin/record-audio.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

@test "record-audio --help exits 0 and prints usage" {
	run_bin record-audio --help
	assert_success
	assert_output_contains "sage"
}

@test "record-audio --version exits 0 and prints a version" {
	run_bin record-audio --version
	assert_success
	assert_valid_version
}

@test "record-audio unknown option exits non-zero" {
	run_bin record-audio --no-such-flag
	assert_failure
}

@test "record-audio exits non-zero without required audio packages" {
	if ! command -v python3 >/dev/null 2>&1; then skip "python3 not available"; fi
	# When sounddevice/soundfile are absent the command reports an error.
	if python3 -c "import sounddevice, soundfile" 2>/dev/null; then
		skip "sounddevice and soundfile are installed"
	fi
	run_bin record-audio output.wav
	assert_failure
}

@test "record-audio exits non-zero when python3 is unavailable" {
	local empty_dir="${BIN_TEST_HOME}/empty-bin"
	mkdir -p "${empty_dir}"
	run env -i HOME="${BIN_TEST_HOME}" PATH="${empty_dir}:/usr/sbin:/sbin" \
		TERM=dumb CI=true \
		"${MANTLE_ROOT}/bin/record-audio" output.wav
	assert_failure
}
