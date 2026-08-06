#!/usr/bin/env bats
#
# Integration tests for the repository-root installer.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	load '../test_helper/stubs'
	setup_isolated_home
	setup_clean_path
	setup_stub_dir

	INSTALL_SH="${MANTLE_ROOT}/install.sh"
	DEFAULT_PREFIX="${XDG_DATA_HOME}/mantle"
	REAL_MV="$(command -v mv)"
	mkdir -p "${TEST_HOME}/tmp"
	export TMPDIR="${TEST_HOME}/tmp"
}

teardown() {
	teardown_stub_dir
	teardown_clean_path
	teardown_isolated_home
}

_run_installer() {
	run env -i \
		HOME="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		PATH="${STUB_DIR}:${PATH}" \
		TMPDIR="${TMPDIR}" \
		TERM=dumb \
		/bin/bash "${INSTALL_SH}" "$@"
}

_run_installer_split_streams() {
	local stdout_file="${TEST_HOME}/stdout"
	local stderr_file="${TEST_HOME}/stderr"

	rm -f "${stdout_file}" "${stderr_file}"
	run env -i \
		HOME="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		PATH="${STUB_DIR}:${PATH}" \
		TMPDIR="${TMPDIR}" \
		TERM=dumb \
		STDOUT_CAPTURE="${stdout_file}" \
		STDERR_CAPTURE="${stderr_file}" \
		/bin/bash -c '/bin/bash "$1" "${@:2}" >"${STDOUT_CAPTURE}" 2>"${STDERR_CAPTURE}"' \
		_ "${INSTALL_SH}" "$@"
}

_count_fixed_string() {
	local needle="${1:?}"
	local file_path="${2:?}"

	if [[ ! -f "${file_path}" ]]; then
		printf '0\n'
		return 0
	fi

	grep -Fxc "${needle}" "${file_path}" 2>/dev/null || true
}

_metadata_path() {
	printf '%s/.mantle-installer\n' "$1"
}

_assert_installed_payload() {
	local prefix_path="${1:?}"

	assert_dir_exists "${prefix_path}"
	assert_file_exists "${prefix_path}/.shellrc"
	assert_dir_exists "${prefix_path}/bin"
	assert_dir_exists "${prefix_path}/lib"
	assert_file_exists "$(_metadata_path "${prefix_path}")"
	assert_file_executable "${prefix_path}/bin/mantle"
	assert_file_not_exists "${prefix_path}/.git"
}

_create_fail_on_second_mv_stub() {
	local stub_path="${STUB_DIR}/mv"
	local counter_file="${STUB_DIR}/mv.count"

	cat >"${stub_path}" <<EOF
#!/bin/sh
count=0
if [ -f "${counter_file}" ]; then
	count=\$(cat "${counter_file}")
fi
count=\$((count + 1))
printf '%s\n' "\${count}" >"${counter_file}"
if [ "\${count}" -eq 2 ]; then
	exit 1
fi
exec "${REAL_MV}" "\$@"
EOF
	chmod 0755 "${stub_path}"
}

@test "install.sh --help writes usage to stdout without mutating the filesystem" {
	_run_installer_split_streams --help
	assert_success
	assert_file_exists "${TEST_HOME}/stdout"
	assert_file_exists "${TEST_HOME}/stderr"
	run cat "${TEST_HOME}/stdout"
	assert_output_contains 'Usage: ./install.sh [OPTIONS]'
	run cat "${TEST_HOME}/stderr"
	[[ -z "${output}" ]]
	[[ ! -d "${DEFAULT_PREFIX}" ]]
}

@test "install.sh rejects unknown options on stderr with status 64" {
	_run_installer_split_streams --not-a-real-option
	assert_status 64
	run cat "${TEST_HOME}/stdout"
	[[ -z "${output}" ]]
	run cat "${TEST_HOME}/stderr"
	assert_output_contains 'unknown option: --not-a-real-option'
}

@test "install.sh --dry-run is non-mutating" {
	_run_installer --dry-run --shell bash
	assert_success
	assert_output_contains 'mode: dry-run'
	assert_output_contains "prefix: ${DEFAULT_PREFIX}"
	[[ ! -e "${DEFAULT_PREFIX}" ]]
	[[ ! -e "${TEST_HOME}/.bashrc" ]]
}

@test "install.sh performs a copy installation and bash activation by default" {
	_run_installer --shell bash
	assert_success
	_assert_installed_payload "${DEFAULT_PREFIX}"
	assert_file_exists "${TEST_HOME}/.bashrc"
	run grep -F "${DEFAULT_PREFIX}/.shellrc" "${TEST_HOME}/.bashrc"
	assert_success
}

@test "copy installation is idempotent and does not duplicate the managed bash block or PATH entries" {
	_run_installer --shell bash
	assert_success
	_run_installer --shell bash
	assert_success

	[[ "$(_count_fixed_string '# >>> mantle >>>' "${TEST_HOME}/.bashrc")" == '1' ]]

	run env -i \
		HOME="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		PATH="/usr/bin:/bin" \
		TERM=dumb \
		/bin/bash --noprofile --norc -c '
			source "$HOME/.bashrc"
			source "$HOME/.bashrc"
			count=0
			OLDIFS=$IFS
			IFS=:
			for entry in $PATH; do
				[[ "${entry}" == "'"${DEFAULT_PREFIX}"'/bin" ]] && count=$((count + 1))
			done
			IFS=$OLDIFS
			printf "%s\n" "${count}"
		'
	assert_success
	[[ "${output}" == '1' ]]
}

@test "install.sh safely quotes custom prefixes containing spaces and shell metacharacters for bash activation" {
	local prefix_path="${TEST_HOME}/prefix with spaces \$dollar"

	_run_installer --prefix "${prefix_path}" --shell bash
	assert_success
	_assert_installed_payload "${prefix_path}"

	run env -i \
		HOME="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		PATH="/usr/bin:/bin" \
		TERM=dumb \
		/bin/bash --noprofile --norc -c '
			source "$HOME/.bashrc"
			printf "%s\n" "${MANTLE_ROOT}"
		'
	assert_success
	[[ "${output}" == "${prefix_path}" ]]
}

@test "install.sh uses .bashrc on macOS when .bash_profile already sources it" {
	create_stub uname 0 'Darwin'
	printf '%s\n' '. "$HOME/.bashrc"' >"${TEST_HOME}/.bash_profile"
	printf '%s\n' '# existing bashrc content' >"${TEST_HOME}/.bashrc"

	_run_installer --shell bash
	assert_success
	run grep -F '# >>> mantle >>>' "${TEST_HOME}/.bashrc"
	assert_success
	run grep -F '# >>> mantle >>>' "${TEST_HOME}/.bash_profile"
	assert_failure
	assert_file_exists "${TEST_HOME}/.bashrc.mantle.bak"
}

@test "install.sh backs up existing shell files and uninstall removes only the managed block" {
	printf '%s\n%s\n' '# before' '# after' >"${TEST_HOME}/.bashrc"

	_run_installer --shell bash
	assert_success
	assert_file_exists "${TEST_HOME}/.bashrc.mantle.bak"
	run cat "${TEST_HOME}/.bashrc.mantle.bak"
	assert_output_contains '# before'
	assert_output_contains '# after'

	printf '%s\n' '# user change after install' >>"${TEST_HOME}/.bashrc"
	_run_installer --uninstall --shell bash
	assert_success
	run cat "${TEST_HOME}/.bashrc"
	assert_output_contains '# before'
	assert_output_contains '# after'
	assert_output_contains '# user change after install'
	assert_output_not_contains '# >>> mantle >>>'
}

@test "install.sh --no-shell-hook installs without touching startup files" {
	_run_installer --no-shell-hook
	assert_success
	_assert_installed_payload "${DEFAULT_PREFIX}"
	[[ ! -e "${TEST_HOME}/.bashrc" ]]
	[[ ! -e "${TEST_HOME}/.zshrc" ]]
	[[ ! -e "${XDG_CONFIG_HOME}/fish/conf.d/mantle.fish" ]]
}

@test "install.sh status reports absent and installed states without mutating files" {
	_run_installer --status
	assert_success
	assert_output_contains 'installed: no'
	[[ ! -e "${DEFAULT_PREFIX}" ]]

	_run_installer --no-shell-hook
	assert_success
	_run_installer --status
	assert_success
	assert_output_contains 'installed: yes'
	assert_output_contains 'ownership: installer-owned'
}

@test "install.sh supports explicit symlink installations" {
	local prefix_path="${TEST_HOME}/symlink prefix"

	_run_installer --prefix "${prefix_path}" --method symlink --no-shell-hook
	assert_success
	assert_dir_exists "${prefix_path}"
	[[ -L "${prefix_path}/bin" ]]
	run grep -F '"method": "symlink"' "$(_metadata_path "${prefix_path}")"
	assert_success

	_run_installer --prefix "${prefix_path}" --status
	assert_success
	assert_output_contains 'method: symlink'

	_run_installer --prefix "${prefix_path}" --uninstall --no-shell-hook
	assert_success
	[[ ! -e "${prefix_path}" ]]
	[[ -d "${MANTLE_ROOT}" ]]
}

@test "install.sh refuses to overwrite an unrelated occupied destination" {
	mkdir -p "${DEFAULT_PREFIX}"
	printf '%s\n' 'not mantle' >"${DEFAULT_PREFIX}/README"

	_run_installer --no-shell-hook
	assert_status 73
	assert_output_contains "refusing to overwrite a non-installer-owned destination: ${DEFAULT_PREFIX}"
}

@test "install.sh environment-diff does not mutate the installation or startup files" {
	_run_installer --environment-diff --no-shell-hook
	assert_success
	assert_output_contains '--- before'
	assert_output_contains '+++ after'
	[[ ! -e "${DEFAULT_PREFIX}" ]]
	[[ ! -e "${TEST_HOME}/.bashrc" ]]
	[[ ! -e "${TEST_HOME}/.zshrc" ]]
}

@test "install.sh rolls back an installer-owned update when publication fails" {
	_run_installer --no-shell-hook
	assert_success
	local metadata_before
	metadata_before="$(cat "$(_metadata_path "${DEFAULT_PREFIX}")")"

	_create_fail_on_second_mv_stub
	_run_installer --no-shell-hook
	assert_failure
	run cat "$(_metadata_path "${DEFAULT_PREFIX}")"
	[[ "${output}" == "${metadata_before}" ]]
	run find "$(dirname -- "${DEFAULT_PREFIX}")" -maxdepth 1 -name "$(basename -- "${DEFAULT_PREFIX}").previous.*"
	[[ -z "${output}" ]]
}

@test "install.sh creates an installer-owned fish activation file and keeps it executable by fish when available" {
	_run_installer --shell fish
	assert_success
	assert_file_exists "${XDG_CONFIG_HOME}/fish/conf.d/mantle.fish"
	run grep -F "${DEFAULT_PREFIX}/runtime/shells/fish/runtime.fish" "${XDG_CONFIG_HOME}/fish/conf.d/mantle.fish"
	assert_success

	if command -v fish >/dev/null 2>&1; then
		run env -i \
			HOME="${TEST_HOME}" \
			XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
			XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
			XDG_DATA_HOME="${XDG_DATA_HOME}" \
			XDG_STATE_HOME="${XDG_STATE_HOME}" \
			XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
			PATH="/usr/bin:/bin" \
			TERM=dumb \
			fish -c 'source "$argv[1]"; printf "%s\n" "$MANTLE_ROOT"' "${XDG_CONFIG_HOME}/fish/conf.d/mantle.fish"
		assert_success
		[[ "${output}" == "${DEFAULT_PREFIX}" ]]
	fi
}

@test "install.sh creates a zsh activation block that can be sourced by zsh when available" {
	require_zsh

	_run_installer --shell zsh
	assert_success
	assert_file_exists "${TEST_HOME}/.zshrc"

	run env -i \
		HOME="${TEST_HOME}" \
		ZDOTDIR="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		PATH="/usr/bin:/bin" \
		TERM=dumb \
		zsh --no-rcs -c 'source "$HOME/.zshrc"; printf "%s\n" "${MANTLE_ROOT}"'
	assert_success
	[[ "${output}" == "${DEFAULT_PREFIX}" ]]
}
