#!/usr/bin/env bats
# Integration tests for the public .shellrc entrypoint.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
}

teardown() {
	teardown_isolated_home
}

# ---------------------------------------------------------------------------
# Sourcing in Bash
# ---------------------------------------------------------------------------

@test ".shellrc sources successfully in Bash" {
	run /bin/bash --noprofile --norc -c "
		HOME='${TEST_HOME}'
		MANTLE_ROOT='${MANTLE_ROOT}'
		export HOME MANTLE_ROOT
		source '${MANTLE_ROOT}/.shellrc'
	"
	assert_success
}

@test ".shellrc sources successfully in Zsh" {
	require_zsh
	run zsh --no-rcs -c "
		HOME='${TEST_HOME}'
		MANTLE_ROOT='${MANTLE_ROOT}'
		export HOME MANTLE_ROOT
		source '${MANTLE_ROOT}/.shellrc'
	"
	assert_success
}

@test ".shellrc direct execution is rejected with status 64 in Bash" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/.shellrc"
	assert_status 64
	assert_output_contains "must be sourced"
}

# ---------------------------------------------------------------------------
# Variable correctness
# ---------------------------------------------------------------------------

@test ".shellrc sets MANTLE_ROOT to an absolute path" {
	run /bin/bash --noprofile --norc -c "
		HOME='${TEST_HOME}'
		export HOME
		source '${MANTLE_ROOT}/.shellrc' && printf '%s\n' \"\${MANTLE_ROOT}\"
	"
	assert_success
	[[ "${lines[0]}" == /* ]]
}

@test ".shellrc sets MANTLE_SHELL_NAME to bash in Bash" {
	run /bin/bash --noprofile --norc -c "
		HOME='${TEST_HOME}'
		export HOME
		source '${MANTLE_ROOT}/.shellrc' && printf '%s\n' \"\${MANTLE_SHELL_NAME}\"
	"
	assert_success
	assert_output_contains "bash"
}

@test ".shellrc sets MANTLE_SHELL_NAME to zsh in Zsh" {
	require_zsh
	run zsh --no-rcs -c "
		HOME='${TEST_HOME}'
		export HOME
		source '${MANTLE_ROOT}/.shellrc' && printf '%s\n' \"\${MANTLE_SHELL_NAME}\"
	"
	assert_success
	assert_output_contains "zsh"
}

@test ".shellrc sets MANTLE_INTERACTIVE=0 in noninteractive shell" {
	run /bin/bash --noprofile --norc -c "
		HOME='${TEST_HOME}'
		export HOME
		source '${MANTLE_ROOT}/.shellrc' && printf '%s\n' \"\${MANTLE_INTERACTIVE}\"
	"
	assert_success
	assert_output_contains "0"
}

# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------

@test ".shellrc repeated sourcing is idempotent" {
	run /bin/bash --noprofile --norc -c "
		HOME='${TEST_HOME}'
		export HOME
		source '${MANTLE_ROOT}/.shellrc'
		source '${MANTLE_ROOT}/.shellrc'
		printf 'state=%s\n' \"\${MANTLE_INITIALIZATION_STATE}\"
	"
	assert_success
	assert_output_contains "state=initialized"
}

@test ".shellrc recursive initialization is rejected with status 70" {
	run /bin/bash --noprofile --norc -c "
		HOME='${TEST_HOME}'
		MANTLE_INITIALIZATION_STATE=initializing
		export HOME MANTLE_INITIALIZATION_STATE
		source '${MANTLE_ROOT}/.shellrc'
		printf '%d\n' \$?
	"
	# The source returns 70; the shell exits 0 after the printf
	assert_output_contains "70"
}

# ---------------------------------------------------------------------------
# State preservation
# ---------------------------------------------------------------------------

@test ".shellrc does not change the caller's working directory" {
	local original_dir
	original_dir="$(pwd)"
	run /bin/bash --noprofile --norc -c "
		HOME='${TEST_HOME}'
		export HOME
		cd '${TEST_HOME}'
		source '${MANTLE_ROOT}/.shellrc'
		pwd
	"
	assert_success
	assert_output_contains "${TEST_HOME}"
}

@test ".shellrc does not export MANTLE_INITIALIZATION_STATE to child processes" {
	run /bin/bash --noprofile --norc -c "
		HOME='${TEST_HOME}'
		export HOME
		source '${MANTLE_ROOT}/.shellrc'
		/bin/bash --noprofile --norc -c 'printf \"%s\n\" \"\${MANTLE_INITIALIZATION_STATE:-unset}\"'
	"
	assert_success
	assert_output_contains "unset"
}

@test ".shellrc adds MANTLE bin/ to PATH" {
	run /bin/bash --noprofile --norc -c "
		HOME='${TEST_HOME}'
		export HOME
		source '${MANTLE_ROOT}/.shellrc'
		command -v mantle
	"
	assert_success
}

# ---------------------------------------------------------------------------
# Failure and retry
# ---------------------------------------------------------------------------

@test ".shellrc records failed state on init failure" {
	local broken_root
	broken_root="$(mktemp -d "${TMPDIR:-/tmp}/mantle-broken-XXXXXX")"
	cp "${MANTLE_ROOT}/.shellrc" "${broken_root}/.shellrc"
	mkdir -p "${broken_root}/init"
	# Create a broken init.sh that returns non-zero to trigger failure state
	printf "#!/usr/bin/env bash\nreturn 1\n" >"${broken_root}/init/init.sh"
	run /bin/bash --noprofile --norc -c "
		HOME='${TEST_HOME}'
		export HOME
		source '${broken_root}/.shellrc'
		printf 'state=%s\n' \"\${MANTLE_INITIALIZATION_STATE}\"
	"
	assert_output_contains "state=failed"
	rm -rf "${broken_root}"
}

# ---------------------------------------------------------------------------
# Runtime environment detection
# ---------------------------------------------------------------------------

@test ".shellrc detects CI environment when GITHUB_ACTIONS is set" {
	run env -i \
		HOME="${TEST_HOME}" \
		PATH="${PATH}" \
		TERM=dumb \
		GITHUB_ACTIONS=true \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${MANTLE_RUNTIME_ENVIRONMENT}\"
		"
	assert_success
	assert_output_contains "ci"
}

@test ".shellrc detects Codespaces environment" {
	run env -i \
		HOME="${TEST_HOME}" \
		PATH="${PATH}" \
		TERM=dumb \
		CODESPACES=true \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${MANTLE_RUNTIME_ENVIRONMENT}\"
		"
	assert_success
	assert_output_contains "codespaces"
}

@test ".shellrc detects local environment without CI variables" {
	run env -i \
		HOME="${TEST_HOME}" \
		PATH="${PATH}" \
		TERM=dumb \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${MANTLE_RUNTIME_ENVIRONMENT}\"
		"
	assert_success
	assert_output_contains "local"
}
