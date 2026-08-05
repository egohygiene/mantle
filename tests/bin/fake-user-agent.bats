#!/usr/bin/env bats
# Behavioral tests for bin/fake-user-agent.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

_has_fake_useragent() {
	python3 -c "import fake_useragent" 2>/dev/null
}

@test "fake-user-agent --help exits 0 and prints usage" {
	run_bin fake-user-agent --help
	assert_success
	assert_output_contains "sage"
}

@test "fake-user-agent --version exits 0 and prints a version" {
	run_bin fake-user-agent --version
	assert_success
	assert_valid_version
}

@test "fake-user-agent unknown option exits non-zero" {
	run_bin fake-user-agent --no-such-flag
	assert_failure
}

@test "fake-user-agent exits 0 and prints a nonempty user-agent string" {
	if ! _has_fake_useragent; then skip "fake-useragent Python package not available"; fi
	run_bin fake-user-agent
	assert_success
	[[ -n "${output}" ]]
}

@test "fake-user-agent --json exits 0 and output is valid JSON" {
	if ! _has_fake_useragent; then skip "fake-useragent Python package not available"; fi
	run_bin fake-user-agent --json
	assert_success
	printf "%s\n" "${output}" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "fake-user-agent exits non-zero when fake-useragent package is unavailable" {
	if ! command -v python3 >/dev/null 2>&1; then skip "python3 not available"; fi
	# --install-dependency not specified, so it should fail if package is absent.
	if _has_fake_useragent; then skip "fake-useragent is installed"; fi
	run_bin fake-user-agent
	assert_failure
}
