#!/usr/bin/env bats
# Offline context values consumed through Fastfetch's /bin/sh command modules.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	setup_stub_dir
	MANTLE_BIN="${MANTLE_ROOT}/bin/mantle"
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

_fastfetch() {
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}:${PATH}" \
		"${MANTLE_BIN}" fastfetch "$@"
}

_minimal_path() {
	local tool
	for tool in bash basename dirname readlink sleep env; do
		ln -s "$(command -v "${tool}")" "${STUB_DIR}/${tool}"
	done
}

@test "fastfetch collectors expose help and reject extra arguments" {
	_fastfetch --help
	assert_success
	assert_output_contains "runtime|workspace|toolchains|contexts"
	_fastfetch runtime unexpected
	assert_status 64
	_fastfetch unknown
	assert_status 64
}

@test "fastfetch runtime works with optional tools absent and strips terminal controls" {
	_minimal_path
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		MANTLE_VERSION="1.2.3" MANTLE_SHELL_NAME="zsh" MANTLE_RUNTIME_ENVIRONMENT=$'local\n\033' \
		"${MANTLE_BIN}" fastfetch runtime
	assert_success
	[[ "${output}" == "1.2.3 / zsh / local" ]]
}

@test "fastfetch workspace reports a non-Git directory without leaking its full path" {
	mkdir -p "${TEST_HOME}/plain project"
	cd "${TEST_HOME}/plain project"
	_fastfetch workspace
	assert_success
	[[ "${output}" == "plain project (no Git)" ]]
}

@test "fastfetch workspace reports unborn and detached Git branches" {
	mkdir -p "${TEST_HOME}/project"
	git -C "${TEST_HOME}/project" init --quiet
	git -C "${TEST_HOME}/project" symbolic-ref HEAD refs/heads/testing
	cd "${TEST_HOME}/project"
	_fastfetch workspace
	assert_success
	[[ "${output}" == "project / testing" ]]
	git -c user.name="Mantle Test" -c user.email="test@mantle" commit --quiet --allow-empty --message="fixture"
	git checkout --quiet --detach
	_fastfetch workspace
	assert_success
	assert_output_contains "project / detached@"
}

@test "fastfetch toolchains gracefully reports optional tools absent" {
	_minimal_path
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" fastfetch toolchains
	assert_success
	[[ "${output}" == "none detected" ]]
}

@test "fastfetch toolchains bounds version probes and accepts Node output without a name" {
	_minimal_path
	cat >"${STUB_DIR}/python3" <<'SH'
#!/bin/sh
sleep 5
SH
	cat >"${STUB_DIR}/node" <<'SH'
#!/bin/sh
printf "v22.1.0\n"
SH
	chmod 0755 "${STUB_DIR}/python3" "${STUB_DIR}/node"
	local started="${SECONDS}"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" fastfetch toolchains
	assert_success
	assert_output_contains "python3 available | node v22.1.0"
	((SECONDS - started < 3))
}

@test "fastfetch Go version forces the installed toolchain and disables module networking" {
	_minimal_path
	cat >"${STUB_DIR}/go" <<'SH'
#!/bin/sh
[ "$*" = "version" ] || exit 91
[ "${GOTOOLCHAIN}" = "local" ] || exit 92
[ "${GOPROXY}" = "off" ] || exit 93
[ "${GOSUMDB}" = "off" ] || exit 94
printf "go version go1.25.1 linux/amd64\n"
SH
	chmod 0755 "${STUB_DIR}/go"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		GOTOOLCHAIN="auto" GOPROXY="https://proxy.example.test" GOSUMDB="sum.example.test" \
		"${MANTLE_BIN}" fastfetch toolchains
	assert_success
	[[ "${output}" == "Go 1.25.1" ]]
}

@test "fastfetch context hints never invoke remote clients or expose configured endpoints" {
	local tool
	for tool in docker kubectl aws gcloud curl; do
		cat >"${STUB_DIR}/${tool}" <<'SH'
#!/bin/sh
printf "unexpected external context probe\n" >&2
exit 99
SH
		chmod 0755 "${STUB_DIR}/${tool}"
	done
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}:${PATH}" \
		DOCKER_HOST="ssh://secret@example.test" KUBECONFIG="${TEST_HOME}/private-config" AWS_PROFILE="development" \
		"${MANTLE_BIN}" fastfetch contexts
	assert_success
	[[ "${output}" == "docker: endpoint configured | kubeconfig set | aws: development" ]]
}

@test "recommended Fastfetch command modules run through bin sh with explicit stable keys" {
	if ! command -v python3 >/dev/null 2>&1; then
		skip "python3 not available"
	fi
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${MANTLE_ROOT}/bin:${PATH}" \
		python3 - "${MANTLE_ROOT}/config/fastfetch/fastfetch.jsonc" <<'PY'
import json
import re
import subprocess
import sys

config = json.loads(re.sub(r"(?m)^\s*//.*$", "", open(sys.argv[1], encoding="utf-8").read()))
commands = []
for module in config["modules"]:
    if not isinstance(module, dict):
        raise AssertionError("Every visible module needs an explicit short key")
    kind = module["type"]
    if kind not in ("break", "separator"):
        assert "key" in module, kind
    if kind == "custom":
        # Unlike the schema description, 2.67.0 uses a single-space sentinel.
        # Empty strings fall back to the default module label, "Custom".
        assert module["key"] == " ", "Section headers must hide their module key"
    if kind == "command":
        assert module["shell"] == "/bin/sh"
        assert module["param"] == "-c"
        result = subprocess.run([module["shell"], module["param"], module["text"]], capture_output=True, text=True, timeout=2)
        assert result.returncode == 0, result.stderr
        assert result.stdout.strip(), module["text"]
        commands.append(module["text"].split()[-1])
assert commands == ["runtime", "workspace", "toolchains", "contexts"]
PY
	assert_success
}

@test "recommended Fastfetch profile renders section headers without Custom prefixes" {
	local fastfetch="${MANTLE_TEST_FASTFETCH_BINARY:-}"
	if [[ -z "${fastfetch}" ]]; then
		fastfetch="$(command -v fastfetch || true)"
	fi
	if [[ -z "${fastfetch}" ]]; then
		skip "Fastfetch is not available; set MANTLE_TEST_FASTFETCH_BINARY for native profile validation"
	fi
	if ! command -v python3 >/dev/null 2>&1; then
		skip "python3 not available"
	fi
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${MANTLE_ROOT}/bin:${PATH}" TERM="xterm-256color" \
		python3 "${MANTLE_ROOT}/tests/fixtures/startup/run-pty.py" --timeout 8 -- \
		"${fastfetch}" --config "${MANTLE_ROOT}/config/fastfetch/fastfetch.jsonc" --logo none --pipe true
	assert_success
	assert_output_not_contains "Custom"
	local heading
	for heading in SESSION SYSTEM HARDWARE NETWORK DEVELOPMENT "NOW PLAYING"; do
		assert_output_contains "${heading}"
	done
}
