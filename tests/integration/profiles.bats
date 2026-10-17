#!/usr/bin/env bats
# Profile composition is a runtime contract, independent of Python introspection.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	load '../test_helper/profiles'
	setup_isolated_home
	setup_stub_dir
	PROFILE_ROOT="${MANTLE_ROOT}"
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

# @description Expose only portable runtime tools; Python is deliberately absent.
_profile_minimal_path() {
	local tool
	for tool in awk bash basename dirname readlink env mkdir chmod uname id grep cut; do
		ln -s "$(command -v "${tool}")" "${STUB_DIR}/${tool}"
	done
	PROFILE_TEST_PATH="${STUB_DIR}"
}

# @description Mark the first environment mutation in both runtime families.
_profile_install_environment_markers() {
	local source_file marker_index=0
	for source_file in "${PROFILE_ROOT}/modules/xdg.sh" "${PROFILE_ROOT}/runtime/shells/fish/conf.d/environment.fish"; do
		marker_index=$((marker_index + 1))
		cp "${source_file}" "${TEST_HOME}/original-environment-${marker_index}"
		{
			printf 'printf "unexpected environment load\\n" >"$HOME/module-loaded"\n'
			cat "${TEST_HOME}/original-environment-${marker_index}"
		} >"${source_file}"
	done
}

# @description Check all published profile combinations through one native shell.
# @arg $1 string Shell name.
_assert_profile_matrix() {
	local shell_name="${1:?}" name expected
	for name in core interactive workstation container ci full; do
		case "${name}" in
		core) expected="core" ;;
		interactive) expected="core:interactive" ;;
		workstation) expected="core:interactive:tooling:workstation" ;;
		container) expected="core:container" ;;
		ci) expected="core:ci" ;;
		full) expected="core:interactive:tooling:workstation:container:ci" ;;
		esac
		profile_test_shell "${shell_name}" "${name}" 'printf "%s|%s\n" "$MANTLE_ACTIVE_PROFILE" "$MANTLE_PROFILE_CAPABILITIES"'
		assert_success
		assert_line_contains "${name}|${expected}"
	done
}

@test "profiles compose deterministically through the Bash runtime" {
	_assert_profile_matrix bash
}

@test "profiles compose deterministically through the Zsh adapter" {
	_assert_profile_matrix zsh
}

@test "profiles compose deterministically through the native Fish adapter" {
	_assert_profile_matrix fish
}

@test "profiles preserve workstation as the default without selecting it from host CI hints" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" MANTLE_ROOT="${PROFILE_ROOT}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" TERM=dumb CI=true GITHUB_ACTIONS=true \
		/bin/bash --noprofile --norc -c 'source "$MANTLE_ROOT/.shellrc" || exit $?; printf "%s\n" "$MANTLE_ACTIVE_PROFILE"'
	assert_success
	assert_line_contains "workstation"
}

@test "profiles core container and CI start in every shell without Python or Ruby probes" {
	_profile_minimal_path
	create_recording_stub gem 99
	create_recording_stub ruby 99
	local shell_name profile
	for shell_name in bash zsh fish; do
		for profile in core container ci; do
			if [[ "${shell_name}" == "fish" ]]; then
				profile_test_shell "${shell_name}" "${profile}" '
                not command --query python3; or exit 91
                not set --query GEM_HOME; or exit 92
                not set --query CARGO_HOME; or exit 93
                not set --query NODE_COMPILER_CACHE; or exit 94
                mantle_profile_has "$MANTLE_ACTIVE_PROFILE"; or exit 95
                not mantle_profile_has interactive; or exit 96
                printf "minimal-ci\n"
            '
			else
				profile_test_shell "${shell_name}" "${profile}" '
                ! command -v python3 >/dev/null 2>&1 || exit 91
                test -z "${GEM_HOME+x}" || exit 92
                test -z "${CARGO_HOME+x}" || exit 93
                test -z "${NODE_COMPILER_CACHE+x}" || exit 94
                mantle_profile_has "$MANTLE_ACTIVE_PROFILE" || exit 95
                ! mantle_profile_has interactive || exit 96
                printf "minimal-ci\n"
            '
			fi
			assert_success
			assert_output_contains "minimal-ci"
		done
	done
	assert_file_not_exists "${STUB_DIR}/gem.calls"
	assert_file_not_exists "${STUB_DIR}/ruby.calls"
}

@test "profiles minimal runtime preserves required module order and omits interactive modules" {
	local name
	for name in core interactive container ci; do
		profile_test_shell bash "${name}" 'printf "%s\n" "$MANTLE_LOADED_MODULES"'
		assert_success
		[[ "${output}" == "xdg:privacy:environment" ]]
	done
	profile_test_shell bash workstation 'printf "%s\n" "$MANTLE_LOADED_MODULES"'
	assert_success
	assert_line_contains "xdg:privacy:cache:tooling:environment"
}

@test "profiles core and CI stay minimal even when Bash is interactive" {
	local name
	for name in core ci container; do
		run env -i HOME="${TEST_HOME}" PATH="${PATH}" MANTLE_ROOT="${PROFILE_ROOT}" \
			XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" TERM=dumb MANTLE_PROFILE="${name}" \
			MANTLE_STARTUP_DISPLAY=1 /bin/bash --noprofile --norc -i -c '
                original_history="${HISTFILE-unset}"
                source "$MANTLE_ROOT/.shellrc" || exit $?
                test "$MANTLE_LOADED_MODULES" = "xdg:privacy:environment" || exit 91
                test "${HISTFILE-unset}" = "$original_history" || exit 92
                test -z "${MANTLE_STARTUP_SHOWN+x}" || exit 93
                printf "interactive-shell-minimal-profile\n"
            '
		assert_success
		assert_output_contains "interactive-shell-minimal-profile"
	done
}

@test "profiles interactive capability adds aliases and history only in an interactive shell" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" MANTLE_ROOT="${PROFILE_ROOT}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" TERM=dumb MANTLE_PROFILE=interactive \
		/bin/bash --noprofile --norc -i -c '
            source "$MANTLE_ROOT/.shellrc" || exit $?
            printf "%s\n" "$MANTLE_LOADED_MODULES"
            mantle_profile_has interactive || exit 91
            ! mantle_profile_has tooling || exit 92
        '
	assert_success
	assert_line_contains "xdg:privacy:environment:aliases:history"
}

@test "profiles repeated sourcing is idempotent and a later profile change is rejected" {
	local shell_name
	for shell_name in bash zsh; do
		profile_test_shell "${shell_name}" ci '
            before="$PATH|$MANTLE_LOADED_MODULES|$MANTLE_PROFILE_CAPABILITIES"
            source "$MANTLE_ROOT/.shellrc" || exit $?
            test "$before" = "$PATH|$MANTLE_LOADED_MODULES|$MANTLE_PROFILE_CAPABILITIES" || exit 91
            mantle_profile_select ci || exit $?
            mantle_profile_select workstation
        '
		assert_status 78
	done
	profile_test_shell fish ci '
        set before "$PATH|$MANTLE_PROFILE_CAPABILITIES"
        source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status
        test "$before" = "$PATH|$MANTLE_PROFILE_CAPABILITIES"; or exit 91
        set --global --export MANTLE_PROFILE workstation
        source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"
    '
	assert_status 78
}

@test "profiles reject invalid selection before loading environment modules" {
	profile_test_copy_tree
	_profile_install_environment_markers
	local shell_name
	for shell_name in bash zsh fish; do
		profile_test_shell "${shell_name}" unknown-profile 'printf "unreachable\n"'
		assert_status 64
	done
	assert_file_not_exists "${TEST_HOME}/module-loaded"
}

@test "profiles reject cycles in unselected branches before runtime mutations" {
	profile_test_require_python
	profile_test_copy_tree
	_profile_install_environment_markers
	python3 - "${PROFILE_ROOT}/config/profiles.tsv" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace("interactive\tcore\t", "interactive\tfull\t"))
PY
	local shell_name
	for shell_name in bash zsh fish; do
		profile_test_shell "${shell_name}" ci 'printf "unreachable\n"'
		assert_status 64
		assert_output_contains "cycle"
	done
	assert_file_not_exists "${TEST_HOME}/module-loaded"
}

@test "profiles CLI exposes inherited facts and validates all six definitions" {
	profile_test_require_python
	profile_test_cli profiles list --json
	assert_success
	profile_test_json '
assert [profile["name"] for profile in report["profiles"]] == ["core", "interactive", "workstation", "container", "ci", "full"]
for profile in report["profiles"]:
    assert len(profile["resolved_capabilities"]) == len(set(profile["resolved_capabilities"]))
'
	profile_test_cli profiles show full --json
	assert_success
	profile_test_json '
profile = report["profile"]
assert profile["resolved_profiles"] == ["core", "interactive", "workstation", "container", "ci", "full"]
assert profile["resolved_capabilities"] == ["core", "interactive", "tooling", "workstation", "container", "ci"]
'
	profile_test_cli profiles validate --json
	assert_success
	profile_test_json 'assert report["valid"] and report["profiles"] == 6'
}

@test "profiles CLI rejects unknown parents duplicate definitions and malformed TSV" {
	profile_test_require_python
	profile_test_copy_tree
	cp "${PROFILE_ROOT}/config/profiles.tsv" "${TEST_HOME}/original.tsv"
	local fault
	for fault in missing-parent duplicate header; do
		python3 - "${TEST_HOME}/original.tsv" "${PROFILE_ROOT}/config/profiles.tsv" "${fault}" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
fault = sys.argv[3]
if fault == "missing-parent":
    text = text.replace("interactive\tcore\t", "interactive\tmissing\t")
elif fault == "duplicate":
    text += "core\t-\tcore\n"
else:
    text = text.replace("profile\tparents\tcapabilities", "profile parents capabilities")
Path(sys.argv[2]).write_text(text)
PY
		profile_test_cli profiles validate --json
		assert_status 78
		assert_output_not_contains "Traceback"
		profile_test_shell bash ci 'printf "unreachable\n"'
		assert_status 64
	done
}

@test "profiles optional extension failures are diagnostic and do not fail initialization" {
	profile_test_copy_tree
	printf 'return 42\n' >"${PROFILE_ROOT}/lib/extensions/fixture-failure.sh"
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" MANTLE_ROOT="${PROFILE_ROOT}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" TERM=dumb MANTLE_PROFILE=ci \
		MANTLE_EXTENSIONS=fixture-failure:missing-extension \
		/bin/bash --noprofile --norc -c '
            source "$MANTLE_ROOT/.shellrc" || exit $?
            printf "state=%s failed=%s\n" "$MANTLE_INITIALIZATION_STATE" "$MANTLE_FAILED_EXTENSIONS"
        '
	assert_success
	assert_output_contains "state=initialized"
	assert_output_contains "fixture-failure"
	assert_output_contains "missing-extension"
	assert_output_contains "[mantle:warn]"
}

@test "profiles requested extensions load after the environment in stable order exactly once" {
	profile_test_copy_tree
	cat >"${PROFILE_ROOT}/lib/extensions/fixture-first.sh" <<'SH'
test "$MANTLE_LOADED_MODULES" = "xdg:privacy:environment" || return 91
test -n "$MANTLE_PLATFORM_RUNTIME" || return 92
printf "first\n" >>"$HOME/extension-order"
SH
	cat >"${PROFILE_ROOT}/lib/extensions/fixture-second.sh" <<'SH'
printf "second\n" >>"$HOME/extension-order"
SH
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" MANTLE_ROOT="${PROFILE_ROOT}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" TERM=dumb MANTLE_PROFILE=ci \
		MANTLE_EXTENSIONS=fixture-first:fixture-second:fixture-first \
		/bin/bash --noprofile --norc -c '
            source "$MANTLE_ROOT/.shellrc" || exit $?
            source "$MANTLE_ROOT/.shellrc" || exit $?
            mantle_load_extension fixture-first || exit $?
            printf "%s\n" "$MANTLE_LOADED_EXTENSIONS"
        '
	assert_success
	[[ "${output}" == "fixture-first:fixture-second" ]]
	[[ "$(cat "${TEST_HOME}/extension-order")" == $'first\nsecond' ]]
}

@test "profiles Fish reports unsupported explicit extensions once without failing its native runtime" {
	local fish_binary
	fish_binary="$(command -v fish || true)"
	if [[ -z "${fish_binary}" ]]; then skip "fish is not available"; fi
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" MANTLE_ROOT="${PROFILE_ROOT}" \
		LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" TERM=dumb MANTLE_PROFILE=ci \
		MANTLE_EXTENSIONS=fonts:fonts:missing-extension \
		"${fish_binary}" --no-config -c '
            source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status
            test "$MANTLE_FISH_INITIALIZATION_STATE" = initialized; or exit 91
            test "$MANTLE_FAILED_EXTENSIONS" = fonts:missing-extension; or exit 92
            printf "native-runtime-initialized\n"
        '
	assert_success
	assert_output_contains "native-runtime-initialized"
	assert_output_contains "unsupported"
	assert_output_contains "[mantle:warn]"
}

@test "profiles CI initialization remains usable on an unsupported platform without desktop adapters" {
	create_stub uname 0 "FixtureOS"
	profile_test_shell bash ci '
        test "$MANTLE_INITIALIZATION_STATE" = initialized || exit 91
        test "$MANTLE_PLATFORM_RUNTIME" = none || exit 92
        test "$MANTLE_LOADED_MODULES" = xdg:privacy:environment || exit 93
        printf "portable-ci-foundation\n"
    '
	assert_success
	assert_output_contains "portable-ci-foundation"
}

@test "profiles bound optional extension lists and reject executable selection text" {
	local extensions
	extensions="$(printf 'missing:%.0s' {1..32})missing"
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" MANTLE_ROOT="${PROFILE_ROOT}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" TERM=dumb MANTLE_PROFILE=ci \
		MANTLE_EXTENSIONS="${extensions}" /bin/bash --noprofile --norc -c '
            source "$MANTLE_ROOT/.shellrc" || exit $?
            printf "%s\n" "$MANTLE_FAILED_EXTENSIONS"
        '
	assert_success
	assert_output_contains "invalid-selection"
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" MANTLE_ROOT="${PROFILE_ROOT}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" TERM=dumb MANTLE_PROFILE=ci \
		MANTLE_EXTENSIONS="fonts;touch ${TEST_HOME}/injected" /bin/bash --noprofile --norc -c '
            source "$MANTLE_ROOT/.shellrc" || exit $?
            printf "%s\n" "$MANTLE_FAILED_EXTENSIONS"
        '
	assert_success
	assert_output_contains "invalid-selection"
	assert_file_not_exists "${TEST_HOME}/injected"
	profile_test_shell bash "ci;touch ${TEST_HOME}/injected" 'printf "unreachable\n"'
	assert_status 64
	assert_file_not_exists "${TEST_HOME}/injected"
}
