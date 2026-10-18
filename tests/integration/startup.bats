#!/usr/bin/env bats
# Startup display tests use real PTYs, an isolated HOME, and local tool stubs.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	command -v python3 >/dev/null 2>&1 || skip "python3 is not available"
	STARTUP_PYTHON="$(command -v python3)"
	STARTUP_STUB_DIR="${TEST_HOME}/startup-tools"
	STARTUP_LOG="${TEST_HOME}/fastfetch.calls"
	mkdir -p "${STARTUP_STUB_DIR}"
	cat >"${STARTUP_STUB_DIR}/fastfetch" <<'STUB'
#!/bin/sh
printf 'call\n' >>"${STARTUP_LOG}"
printf '%s\n' "$@" >"${STARTUP_LOG}.arguments"
printf '%s\n' "${MANTLE_STARTUP_LOGO_PATH:-}" >"${STARTUP_LOG}.logo"
printf 'FASTFETCH_RENDER\n'
STUB
	chmod 0755 "${STARTUP_STUB_DIR}/fastfetch"
	STARTUP_PATH="${STARTUP_STUB_DIR}:/usr/local/bin:/usr/bin:/bin"
}

teardown() {
	teardown_isolated_home
}

# Arguments before -- are environment overrides. Arguments after -- are the
# command, optionally prefixed by fixture options such as --stdin-pipe.
_startup_pty() {
	local fixture_options=()
	while [[ "${1:-}" == --stdin-pipe || "${1:-}" == --stdout-pipe || "${1:-}" == --timeout ]]; do
		if [[ "$1" == --timeout ]]; then
			fixture_options+=("$1" "$2")
			shift 2
		else
			fixture_options+=("$1")
			shift
		fi
	done
	local environment=()
	while [[ "${1:-}" != -- ]]; do
		environment+=("$1")
		shift
	done
	shift
	run env -i \
		HOME="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		PATH="${STARTUP_PATH}" \
		TERM=xterm-256color \
		MANTLE_ROOT="${MANTLE_ROOT}" \
		MANTLE_INTERACTIVE=1 \
		MANTLE_STARTUP_DISPLAY=1 \
		MANTLE_STARTUP_BANNER=0 \
		STARTUP_LOG="${STARTUP_LOG}" \
		STARTUP_PYTHON="${STARTUP_PYTHON}" \
		"${environment[@]}" \
		"${STARTUP_PYTHON}" "${MANTLE_ROOT}/tests/fixtures/startup/run-pty.py" \
		"${fixture_options[@]}" -- "$@"
}

_assert_fastfetch_calls() {
	local expected="$1"
	local actual=0
	if [[ -f "${STARTUP_LOG}" ]]; then
		actual="$(wc -l <"${STARTUP_LOG}" | tr -d ' ')"
	fi
	[[ "${actual}" -eq "${expected}" ]] || {
		printf 'Expected %s Fastfetch invocations, got %s\n%s\n' "${expected}" "${actual}" "${output}" >&2
		return 1
	}
}

@test "startup PTY cleanup accepts stopped Darwin groups and preserves live permission failures" {
	run "${STARTUP_PYTHON}" - "${MANTLE_ROOT}/tests/fixtures/startup/run-pty.py" <<'PY'
import errno
import runpy
import signal
import subprocess
import sys
from types import SimpleNamespace
from unittest.mock import Mock, patch

stop_group = runpy.run_path(sys.argv[1])["stop_fixture_group"]
process = SimpleNamespace(pid=424242, poll=Mock(return_value=0))
for members in ("", "424242 Z+\n"):
    snapshot = subprocess.CompletedProcess([], 0, stdout=members)
    with patch("os.killpg", side_effect=PermissionError(errno.EPERM, "group stopped")) as kill_group:
        with patch("subprocess.run", return_value=snapshot):
            stop_group(process)
        kill_group.assert_called_once_with(process.pid, signal.SIGKILL)
with patch("os.killpg", side_effect=PermissionError(errno.EPERM, "live group denied")):
    with patch("subprocess.run", return_value=subprocess.CompletedProcess([], 0, stdout="424242 S+\n")):
        try:
            stop_group(process)
        except PermissionError:
            pass
        else:
            raise AssertionError("a live group's signal denial was hidden")
process.poll.return_value = None
with patch("os.killpg", side_effect=PermissionError(errno.EPERM, "leader denied")):
    with patch("subprocess.run") as snapshot:
        try:
            stop_group(process)
        except PermissionError:
            pass
        else:
            raise AssertionError("a running leader's signal denial was hidden")
        snapshot.assert_not_called()
print("stopped-group cleanup and live permission failures verified")
PY
	assert_success
	assert_output_contains "stopped-group cleanup and live permission failures verified"
}

@test "startup PTY cleanup preserves ordinary child status and pipe output" {
	_startup_pty -- /bin/bash --noprofile --norc -c 'printf "CHILD_EXIT_23\n"; exit 23'
	assert_status 23
	assert_output_contains "CHILD_EXIT_23"
	_startup_pty --stdout-pipe -- /bin/bash --noprofile --norc -c 'printf "PIPE_COMPLETE\n"'
	assert_success
	assert_output_contains "PIPE_COMPLETE"
}

@test "startup PTY cleanup stops leaked descendants after leader exit and fixture deadline" {
	local mode
	for mode in exited deadline; do
		_startup_pty --timeout 0.5 STARTUP_FIXTURE_MODE="${mode}" -- "${STARTUP_PYTHON}" -c '
import json
import os
from pathlib import Path
import signal
import time
signal.signal(signal.SIGHUP, signal.SIG_IGN)
child = os.fork()
if child == 0:
    time.sleep(20)
    os._exit(0)
Path(os.environ["STARTUP_LOG"] + ".leaked.json").write_text(json.dumps({"leader": os.getpid(), "child": child}))
print("FIXTURE_CHILD_READY", flush=True)
if os.environ["STARTUP_FIXTURE_MODE"] == "deadline":
    time.sleep(20)
'
		if [[ "${mode}" == deadline ]]; then
			assert_status 124
			assert_output_contains "startup fixture exceeded its deadline"
		else
			assert_success
		fi
		assert_output_contains "FIXTURE_CHILD_READY"
		run "${STARTUP_PYTHON}" - "${STARTUP_LOG}.leaked.json" <<'PY'
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
record = json.loads(Path(sys.argv[1]).read_text())
child = record["child"]
result = subprocess.run(["ps", "-p", str(child), "-o", "stat="], stdout=subprocess.PIPE, text=True)
state = result.stdout.strip()
if state and not state.startswith("Z"):
    if os.getpgid(child) == record["leader"] and os.getsid(child) == record["leader"]:
        os.kill(child, signal.SIGKILL)
    raise AssertionError("the fixture left a live descendant")
print("LEAKED_DESCENDANT_STOPPED")
PY
		assert_success
		assert_output_contains "LEAKED_DESCENDANT_STOPPED"
	done
}

@test "startup is opt-in even on an interactive terminal" {
	_startup_pty -- /bin/bash --noprofile --norc -c '
        unset MANTLE_STARTUP_DISPLAY
        exec "${MANTLE_ROOT}/bin/mantle" startup
    '
	assert_success
	[[ -z "${output}" ]]
	_startup_pty MANTLE_STARTUP_DISPLAY=0 -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -z "${output}" ]]
	_assert_fastfetch_calls 0
}

@test "startup presentation off and ci policies suppress an enabled display" {
	local mode
	for mode in off ci; do
		_startup_pty MANTLE_POLICY_PRESENTATION="${mode}" -- "${MANTLE_ROOT}/bin/mantle" startup
		assert_success
		[[ -z "${output}" ]]
		_startup_pty MANTLE_POLICY_PRESENTATION="${mode}" -- "${MANTLE_ROOT}/bin/mantle" startup --check
		assert_status 1
		[[ -z "${output}" ]]
	done
	_assert_fastfetch_calls 0
}

@test "startup explicit presentation mode overrides inherited policy" {
	_startup_pty MANTLE_POLICY_PRESENTATION=private MANTLE_PRESENTATION_MODE=off -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -z "${output}" ]]
	_assert_fastfetch_calls 0
}

@test "startup share-safe mode renders only bundled text and never custom configuration" {
	local private_banner="${TEST_HOME}/private-banner.txt"
	printf "%s\n" "PRIVATE_BANNER_SENTINEL" >"${private_banner}"
	_startup_pty MANTLE_POLICY_PRESENTATION=share-safe MANTLE_STARTUP_BANNER=1 \
		MANTLE_BANNER_FILE="${private_banner}" MANTLE_FASTFETCH_CONFIG="${private_banner}" \
		-- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -n "${output}" ]]
	assert_output_not_contains "PRIVATE_BANNER_SENTINEL"
	assert_output_not_contains "FASTFETCH_RENDER"
	_assert_fastfetch_calls 0
	_startup_pty MANTLE_POLICY_PRESENTATION=share-safe -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -z "${output}" ]]
	_assert_fastfetch_calls 0
}

@test "startup renders Fastfetch when explicitly enabled on a terminal" {
	_startup_pty -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	assert_output_contains "FASTFETCH_RENDER"
	_assert_fastfetch_calls 1
}

@test "copy and symlink installs retain the startup profile and artwork" {
	local method prefix calls=0
	for method in copy symlink; do
		prefix="${TEST_HOME}/installed-${method}"
		run "${MANTLE_ROOT}/install.sh" --prefix "${prefix}" --method "${method}" --no-shell-hook
		assert_success
		[[ -r "${prefix}/config/fastfetch/fastfetch.jsonc" ]]
		[[ -r "${prefix}/assets/presentation/incompris.png" ]]
		[[ ! -e "${TEST_HOME}/.bashrc" ]]
		_startup_pty MANTLE_ROOT="${prefix}" -- "${prefix}/bin/mantle" startup
		assert_success
		assert_output_contains "FASTFETCH_RENDER"
		calls=$((calls + 1))
		_assert_fastfetch_calls "${calls}"
		grep -Fqx -- "${prefix}/config/fastfetch/fastfetch.jsonc" "${STARTUP_LOG}.arguments"
	done
}

@test "startup gives Fastfetch a foreground terminal for capability negotiation" {
	cat >"${STARTUP_STUB_DIR}/fastfetch" <<'STUB'
#!/bin/sh
printf 'call\n' >>"${STARTUP_LOG}"
exec "${STARTUP_PYTHON}" -c 'import os; assert os.isatty(0); assert os.tcgetpgrp(0) == os.getpgrp(); print("FOREGROUND_TTY_READY")'
STUB
	_startup_pty -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	assert_output_contains "FOREGROUND_TTY_READY"
	_assert_fastfetch_calls 1
}

@test "startup respects global and individual display switches" {
	_startup_pty MANTLE_STARTUP_FASTFETCH=0 -- "${MANTLE_ROOT}/bin/mantle" startup --diagnostics
	assert_success
	[[ -z "${output}" ]]
	_assert_fastfetch_calls 0
	_startup_pty MANTLE_STARTUP_DISPLAY=0 MANTLE_STARTUP_BANNER=1 -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -z "${output}" ]]
	_assert_fastfetch_calls 0
}

@test "startup can render a selected banner without Fastfetch" {
	local banner="${TEST_HOME}/my-banner.txt"
	printf 'CUSTOM_STARTUP_BANNER\n' >"${banner}"
	_startup_pty MANTLE_STARTUP_BANNER=1 MANTLE_STARTUP_FASTFETCH=0 MANTLE_BANNER_FILE="${banner}" -- \
		"${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	assert_output_contains "CUSTOM_STARTUP_BANNER"
	_assert_fastfetch_calls 0
}

@test "startup respects an inherited already-shown guard" {
	_startup_pty MANTLE_STARTUP_SHOWN=1 -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -z "${output}" ]]
	_assert_fastfetch_calls 0
}

@test "startup remains silent in CI and dumb terminals" {
	local suppression
	for suppression in CI=true GITHUB_ACTIONS=true TERM=dumb; do
		_startup_pty "${suppression}" -- "${MANTLE_ROOT}/bin/mantle" startup
		assert_success
		[[ -z "${output}" ]]
		_assert_fastfetch_calls 0
	done
}

@test "startup requires interactive mode and both stdin and stdout terminals" {
	_startup_pty MANTLE_INTERACTIVE=0 -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -z "${output}" ]]
	_startup_pty --stdin-pipe -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -z "${output}" ]]
	_startup_pty --stdout-pipe -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -z "${output}" ]]
	_assert_fastfetch_calls 0
}

@test "startup preserves literal Fastfetch configuration and logo paths" {
	local config="${TEST_HOME}/config with spaces;literal.jsonc"
	local logo="${TEST_HOME}/logo with spaces;literal.txt"
	printf '{}\n' >"${config}"
	printf 'logo\n' >"${logo}"
	_startup_pty MANTLE_FASTFETCH_CONFIG="${config}" MANTLE_FASTFETCH_LOGO="${logo}" -- \
		"${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	_assert_fastfetch_calls 1
	local arguments
	arguments="$(cat "${STARTUP_LOG}.arguments")"
	[[ "${arguments}" == *"${config}"* ]]
	# Fastfetch performs its own path expansion. A quoted environment reference
	# preserves metacharacters without asking Fastfetch to interpret the path.
	[[ "${arguments}" == *'"$MANTLE_STARTUP_LOGO_PATH"'* ]]
	[[ "$(cat "${STARTUP_LOG}.logo")" == "${logo}" ]]
	[[ ! -e "${TEST_HOME}/literal.jsonc" ]]
}

@test "startup prefers an existing XDG Fastfetch profile and preserves its logo" {
	local config="${XDG_CONFIG_HOME}/fastfetch/config.jsonc"
	mkdir -p "${XDG_CONFIG_HOME}/fastfetch"
	printf '{"logo":{"source":"custom-user-logo"}}\n' >"${config}"
	_startup_pty -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	_assert_fastfetch_calls 1
	local arguments
	arguments="$(cat "${STARTUP_LOG}.arguments")"
	[[ "${arguments}" == *"${config}"* ]]
	[[ "${arguments}" != *"--logo"* ]]
	[[ -z "$(cat "${STARTUP_LOG}.logo")" ]]
}

@test "startup suppresses ordinary tool failures while diagnostics are optional" {
	cat >"${STARTUP_STUB_DIR}/fastfetch" <<'STUB'
#!/bin/sh
printf 'call\n' >>"${STARTUP_LOG}"
printf 'PRIVATE_TOOL_FAILURE\n' >&2
exit 23
STUB
	_startup_pty -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -z "${output}" ]]
	_assert_fastfetch_calls 1
	_startup_pty -- "${MANTLE_ROOT}/bin/mantle" startup --diagnostics
	assert_success
	[[ -n "${output}" ]]
	assert_output_not_contains "PRIVATE_TOOL_FAILURE"
	_assert_fastfetch_calls 2
}

@test "startup tolerates an unavailable Fastfetch binary" {
	local minimal_path="${TEST_HOME}/without-fastfetch"
	local tool executable
	mkdir -p "${minimal_path}"
	# Keep the dispatcher and bounded runner dependencies available while making
	# the optional presentation tool unambiguously absent, even on a workstation
	# that has Fastfetch installed globally.
	for tool in bash dirname basename readlink mktemp rm sleep ps awk cat date setsid; do
		executable="$(command -v "${tool}" 2>/dev/null)" || continue
		ln -s "${executable}" "${minimal_path}/${tool}"
	done
	_startup_pty PATH="${minimal_path}" -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	[[ -z "${output}" ]]
	_assert_fastfetch_calls 0
}

@test "startup bounds a slow display command and returns to the caller" {
	cat >"${STARTUP_STUB_DIR}/fastfetch" <<'STUB'
#!/bin/sh
printf 'call\n' >>"${STARTUP_LOG}"
sleep 20
printf 'TOO_LATE\n'
STUB
	_startup_pty MANTLE_STARTUP_TIMEOUT_SECONDS=1 -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	assert_output_not_contains "TOO_LATE"
	_assert_fastfetch_calls 1
}

@test "startup timeout restores styling cursor visibility and terminal autowrap" {
	cat >"${STARTUP_STUB_DIR}/fastfetch" <<'STUB'
#!/bin/sh
printf 'call\n' >>"${STARTUP_LOG}"
printf '\033[?7l'
sleep 20
STUB
	_startup_pty MANTLE_STARTUP_TIMEOUT_SECONDS=1 -- "${MANTLE_ROOT}/bin/mantle" startup
	assert_success
	# Confirm the renderer changed terminal state before the timeout, then
	# require the final recovery to reset SGR, show the cursor, and enable wrap.
	assert_output_contains $'\033[?7l'
	[[ "${output}" == *$'\033[0m\033[?25h\033[?7h' ]]
	_assert_fastfetch_calls 1
}

@test "startup deadline stops display descendants before returning to the shell" {
	cat >"${STARTUP_STUB_DIR}/fastfetch" <<'STUB'
#!/bin/sh
printf 'call\n' >>"${STARTUP_LOG}"
sleep 20 &
child_pid=$!
printf '%s\n' "${child_pid}" >"${STARTUP_LOG}.child-pid"
wait "${child_pid}"
STUB
	# Inspect the descendant inside the fixture's shell, before run-pty.py does
	# its own safety cleanup. A zombie is already stopped; containers can have
	# an init process that reaps adopted descendants asynchronously.
	_startup_pty MANTLE_STARTUP_TIMEOUT_SECONDS=1 -- /bin/bash --noprofile --norc -c '
        "${MANTLE_ROOT}/bin/mantle" startup || exit
        child_pid="$(cat "${STARTUP_LOG}.child-pid")"
        child_state="$(ps -o stat= -p "${child_pid}" 2>/dev/null || true)"
        case "${child_state}" in
            "" | *Z*) printf "DESCENDANT_STOPPED\n" ;;
            *) kill "${child_pid}" 2>/dev/null; printf "DESCENDANT_STILL_RUNNING=%s\n" "${child_state}"; exit 1 ;;
        esac
    '
	assert_success
	assert_output_contains "DESCENDANT_STOPPED"
	_assert_fastfetch_calls 1
}

@test "Bash startup displays once across repeated sourcing and a nested shell" {
	_startup_pty -- /bin/bash --noprofile --norc -ic '
        source "${MANTLE_ROOT}/.shellrc" || exit
        source "${MANTLE_ROOT}/.shellrc" || exit
        printf "initialized=%s shown=%s\n" "${MANTLE_INITIALIZATION_STATE}" "${MANTLE_STARTUP_SHOWN:-unset}"
        /bin/bash --noprofile --norc -ic '\''source "${MANTLE_ROOT}/.shellrc"; printf "child=%s\n" "${MANTLE_INITIALIZATION_STATE}"'\''
    '
	assert_success
	assert_output_contains "initialized=initialized shown=1"
	assert_output_contains "child=initialized"
	_assert_fastfetch_calls 1
}

@test "Zsh startup displays once across repeated sourcing and a nested shell" {
	require_zsh
	_startup_pty STARTUP_SHELL="$(command -v zsh)" -- "$(command -v zsh)" --no-rcs -ic '
        source "${MANTLE_ROOT}/.shellrc" || exit
        source "${MANTLE_ROOT}/.shellrc" || exit
        printf "initialized=%s shown=%s\n" "${MANTLE_INITIALIZATION_STATE}" "${MANTLE_STARTUP_SHOWN:-unset}"
        "${STARTUP_SHELL}" --no-rcs -ic '\''source "${MANTLE_ROOT}/.shellrc"; printf "child=%s\n" "${MANTLE_INITIALIZATION_STATE}"'\''
    '
	assert_success
	assert_output_contains "initialized=initialized shown=1"
	assert_output_contains "child=initialized"
	_assert_fastfetch_calls 1
}

@test "Fish greeting displays once across repeated sourcing and a nested shell" {
	require_fish
	_startup_pty STARTUP_SHELL="$(command -v fish)" -- "$(command -v fish)" --no-config --interactive --command '
        source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit
        source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit
        fish_greeting
        fish_greeting
        printf "initialized=%s shown=%s\n" "$MANTLE_FISH_INITIALIZATION_STATE" "$MANTLE_STARTUP_SHOWN"
        "$STARTUP_SHELL" --no-config --interactive --command '\''source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; fish_greeting; printf "child=%s\n" "$MANTLE_FISH_INITIALIZATION_STATE"'\''
    '
	assert_success
	assert_output_contains "initialized=initialized shown=1"
	assert_output_contains "child=initialized"
	_assert_fastfetch_calls 1
}

@test "Bash noninteractive initialization never displays or consumes the startup guard" {
	_startup_pty -- /bin/bash --noprofile --norc -c '
        source "${MANTLE_ROOT}/.shellrc" || exit
        printf "interactive=%s shown=%s\n" "${MANTLE_INTERACTIVE}" "${MANTLE_STARTUP_SHOWN:-unset}"
    '
	assert_success
	assert_output_contains "interactive=0 shown=unset"
	_assert_fastfetch_calls 0
}

@test "Bash CI initialization does not consume the startup guard" {
	_startup_pty CI=true -- /bin/bash --noprofile --norc -ic '
        source "${MANTLE_ROOT}/.shellrc" || exit
        printf "shown=%s\n" "${MANTLE_STARTUP_SHOWN:-unset}"
    '
	assert_success
	assert_output_contains "shown=unset"
	_assert_fastfetch_calls 0
}

@test "failed initialization never displays or consumes the startup guard" {
	local broken_root="${TEST_HOME}/broken-root"
	mkdir -p "${broken_root}/init"
	cp "${MANTLE_ROOT}/.shellrc" "${broken_root}/.shellrc"
	printf 'return 23\n' >"${broken_root}/init/init.sh"
	_startup_pty BROKEN_ROOT="${broken_root}" -- /bin/bash --noprofile --norc -ic '
        source "${BROKEN_ROOT}/.shellrc"
        result=$?
        printf "result=%s state=%s shown=%s\n" "${result}" "${MANTLE_INITIALIZATION_STATE}" "${MANTLE_STARTUP_SHOWN:-unset}"
    '
	assert_success
	assert_output_contains "result=23 state=failed shown=unset"
	_assert_fastfetch_calls 0
}

@test "display failure does not break Bash initialization or prompt readiness" {
	cat >"${STARTUP_STUB_DIR}/fastfetch" <<'STUB'
#!/bin/sh
printf 'call\n' >>"${STARTUP_LOG}"
exit 23
STUB
	_startup_pty -- /bin/bash --noprofile --norc -ic '
        source "${MANTLE_ROOT}/.shellrc" || exit
        printf "READY=%s\n" "${MANTLE_INITIALIZATION_STATE}"
    '
	assert_success
	assert_output_contains "READY=initialized"
	_assert_fastfetch_calls 1
}
