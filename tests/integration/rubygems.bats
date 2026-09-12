#!/usr/bin/env bats
# Integration tests for Mantle's RubyGems environment contract.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	setup_stub_dir
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

_create_gem_env_stub() {
	cat >"${STUB_DIR}/gem" <<'EOF'
#!/bin/sh
case "${1:-}:${2:-}" in
env:path)
	printf '%s\n' "${MANTLE_TEST_GEM_ENV_PATH:-${GEM_HOME}}"
	;;
env:home)
	printf '%s\n' "${GEM_HOME}"
	;;
*)
	exit 0
	;;
esac
EOF
	chmod 0755 "${STUB_DIR}/gem"
}

@test "Bash supplies XDG-aware RubyGems defaults and PATH contract" {
	_create_gem_env_stub

	run env -i \
		HOME="${TEST_HOME}" \
		PATH="${STUB_DIR}:/usr/bin:/bin" \
		TERM=dumb \
		MANTLE_TEST_GEM_ENV_PATH="/system/gems:${TEST_HOME}/.local/share/gem" \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf 'home=%s\n' \"\${GEM_HOME}\"
			printf 'path=%s\n' \"\${GEM_PATH}\"
			printf 'cache=%s\n' \"\${GEM_SPEC_CACHE}\"
			count=0
			IFS=: read -r -a path_entries <<< \"\${PATH}\"
			for path_entry in \"\${path_entries[@]}\"; do
				[[ \"\${path_entry}\" == \"\${GEM_HOME}/bin\" ]] && ((count+=1))
			done
			printf 'bin-count=%s\n' \"\${count}\"
		"

	assert_success
	assert_output_contains "home=${TEST_HOME}/.local/share/gem"
	assert_output_contains "path=/system/gems:${TEST_HOME}/.local/share/gem"
	assert_output_contains "cache=${TEST_HOME}/.cache/gem/specs"
	assert_output_contains "bin-count=1"
}

@test "Bash preserves explicit GEM_PATH and same-shell gem executables become discoverable" {
	run env -i \
		HOME="${TEST_HOME}" \
		PATH="/usr/bin:/bin" \
		TERM=dumb \
		GEM_HOME="${TEST_HOME}/custom-gems" \
		GEM_PATH="${TEST_HOME}/vendor-gems:/opt/ruby/gems" \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			mkdir -p \"\${GEM_HOME}/bin\"
			cat >\"\${GEM_HOME}/bin/gem-fixture\" <<'EOF'
#!/bin/sh
exit 0
EOF
			chmod 0755 \"\${GEM_HOME}/bin/gem-fixture\"
			printf 'path=%s\n' \"\${GEM_PATH}\"
			command -v gem-fixture
		"

	assert_success
	assert_output_contains "path=${TEST_HOME}/vendor-gems:/opt/ruby/gems"
	assert_output_contains "${TEST_HOME}/custom-gems/bin/gem-fixture"
}

@test "Bash repeated sourcing does not duplicate the RubyGems bin PATH entry" {
	_create_gem_env_stub

	run env -i \
		HOME="${TEST_HOME}" \
		PATH="${STUB_DIR}:/usr/bin:/bin" \
		TERM=dumb \
		MANTLE_TEST_GEM_ENV_PATH="/system/gems:${TEST_HOME}/.local/share/gem" \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			unset MANTLE_INITIALIZATION_STATE
			source '${MANTLE_ROOT}/.shellrc'
			count=0
			IFS=: read -r -a path_entries <<< \"\${PATH}\"
			for path_entry in \"\${path_entries[@]}\"; do
				[[ \"\${path_entry}\" == \"\${GEM_HOME}/bin\" ]] && ((count+=1))
			done
			printf '%s\n' \"\${count}\"
		"

	assert_success
	[[ "${output}" == "1" ]]
}

@test "Bash and Zsh produce equivalent RubyGems environment state" {
	require_zsh
	_create_gem_env_stub

	run env -i \
		HOME="${TEST_HOME}" \
		PATH="${STUB_DIR}:/usr/bin:/bin" \
		TERM=dumb \
		MANTLE_TEST_GEM_ENV_PATH="/system/gems:${TEST_HOME}/.local/share/gem" \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s|%s|%s\n' \"\${GEM_HOME}\" \"\${GEM_PATH}\" \"\${GEM_SPEC_CACHE}\"
		"
	local bash_state="${output}"

	run env -i \
		HOME="${TEST_HOME}" \
		PATH="${STUB_DIR}:/usr/bin:/bin" \
		TERM=dumb \
		MANTLE_TEST_GEM_ENV_PATH="/system/gems:${TEST_HOME}/.local/share/gem" \
		zsh --no-rcs -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s|%s|%s\n' \"\${GEM_HOME}\" \"\${GEM_PATH}\" \"\${GEM_SPEC_CACHE}\"
		"

	assert_success
	[[ "${output}" == "${bash_state}" ]]
}

@test "Fish produces equivalent RubyGems environment state" {
	require_fish
	_create_gem_env_stub

	run env -i \
		HOME="${TEST_HOME}" \
		MANTLE_ROOT="${MANTLE_ROOT}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		PATH="${STUB_DIR}:/usr/bin:/bin" \
		TERM=dumb \
		MANTLE_TEST_GEM_ENV_PATH="/system/gems:${TEST_HOME}/.local/share/gem" \
		fish --no-config -c '
			source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"
			printf "%s|%s|%s\n" "$GEM_HOME" "$GEM_PATH" "$GEM_SPEC_CACHE"
			set count 0
			for path_entry in $PATH
				if test "$path_entry" = "$GEM_HOME/bin"
					set count (math $count + 1)
				end
			end
			printf "bin-count=%s\n" "$count"
		'

	assert_success
	assert_output_contains "${TEST_HOME}/.local/share/gem|/system/gems:${TEST_HOME}/.local/share/gem|${TEST_HOME}/.cache/gem/specs"
	assert_output_contains "bin-count=1"
}

@test "real RubyGems integration keeps GEM_HOME discoverable when gem is available" {
	if ! command -v gem >/dev/null 2>&1 || ! command -v ruby >/dev/null 2>&1; then
		skip "ruby and gem are not available"
	fi

	run env -i \
		HOME="${TEST_HOME}" \
		PATH="/usr/bin:/bin" \
		TERM=dumb \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf 'home=%s\n' \"\${GEM_HOME}\"
			printf 'gem-home=%s\n' \"\$(gem env home)\"
			printf 'gem-path=%s\n' \"\$(gem env path)\"
			printf 'env-path=%s\n' \"\${GEM_PATH:-unset}\"
		"

	assert_success
	assert_output_contains "home=${TEST_HOME}/.local/share/gem"
	assert_output_contains "gem-home=${TEST_HOME}/.local/share/gem"
	assert_output_contains "gem-path="
	assert_output_contains "${TEST_HOME}/.local/share/gem"
	assert_output_contains "env-path="
}
