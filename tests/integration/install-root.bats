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
	if [[ "$(uname -s)" == "Darwin" ]]; then
		DEFAULT_BASH_STARTUP_FILE="${TEST_HOME}/.bash_profile"
	else
		DEFAULT_BASH_STARTUP_FILE="${TEST_HOME}/.bashrc"
	fi
	REAL_MV="$(command -v mv)"
	mkdir -p "${TEST_HOME}/tmp"
	export TMPDIR="${TEST_HOME}/tmp"
}

teardown() {
	teardown_stub_dir
	teardown_clean_path
	teardown_isolated_home
}

_run_installer_from() {
	local installer_path="${1:?}"
	shift

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
		/bin/bash "${installer_path}" "$@"
}

_run_installer() {
	_run_installer_from "${INSTALL_SH}" "$@"
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
	assert_file_exists "${prefix_path}/VERSION"
	assert_file_executable "${prefix_path}/install.sh"
	assert_dir_exists "${prefix_path}/bin"
	assert_dir_exists "${prefix_path}/lib"
	assert_dir_exists "${prefix_path}/libexec/mantle/commands"
	assert_file_exists "$(_metadata_path "${prefix_path}")"
	assert_file_executable "${prefix_path}/bin/mantle"
	assert_file_executable "${prefix_path}/bin/shell-doctor"
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

_run_installer_with_zdotdir() {
	local zsh_directory="${1-}"
	shift

	run env -i \
		HOME="${TEST_HOME}" \
		ZDOTDIR="${zsh_directory}" \
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

_assert_no_installer_temporary_paths() {
	run find "${TEST_HOME}" -type d \
		\( -name '.mantle-install.*' -o -name '.mantle-hook.*' \
		-o -name '.mantle-trim.*' -o -name '.mantle-environment.*' \)
	assert_success
	[[ -z "${output}" ]]
}

_create_failed_rollback_stub() {
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
if [ "\${count}" -ge 2 ]; then
	exit 1
fi
exec "${REAL_MV}" "\$@"
EOF
	chmod 0755 "${stub_path}"
}

_create_interrupted_publication_stub() {
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
	kill -TERM "\$PPID"
	exit 143
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
	[[ ! -e "${DEFAULT_BASH_STARTUP_FILE}" ]]
}

@test "install.sh performs a copy installation and bash activation by default" {
	_run_installer --shell bash
	assert_success
	_assert_installed_payload "${DEFAULT_PREFIX}"
	assert_file_exists "${DEFAULT_BASH_STARTUP_FILE}"
	run grep -F "${DEFAULT_PREFIX}/.shellrc" "${DEFAULT_BASH_STARTUP_FILE}"
	assert_success
}

@test "copy installation is idempotent and does not duplicate the managed bash block or PATH entries" {
	_run_installer --shell bash
	assert_success
	_run_installer --shell bash
	assert_success

	[[ "$(_count_fixed_string '# >>> mantle >>>' "${DEFAULT_BASH_STARTUP_FILE}")" == '1' ]]

	run env -i \
		HOME="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		GEM_HOME="${TEST_HOME}/fixture-gems" \
		GEM_PATH="${TEST_HOME}/fixture-gems" \
		PATH="/usr/bin:/bin" \
		TERM=dumb \
		/bin/bash --noprofile --norc -c '
			source "'"${DEFAULT_BASH_STARTUP_FILE}"'"
			source "'"${DEFAULT_BASH_STARTUP_FILE}"'"
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
		GEM_HOME="${TEST_HOME}/fixture-gems" \
		GEM_PATH="${TEST_HOME}/fixture-gems" \
		PATH="/usr/bin:/bin" \
		TERM=dumb \
		/bin/bash --noprofile --norc -c '
			source "'"${DEFAULT_BASH_STARTUP_FILE}"'"
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
	printf '%s\n%s\n' '# before' '# after' >"${DEFAULT_BASH_STARTUP_FILE}"

	_run_installer --shell bash
	assert_success
	assert_file_exists "${DEFAULT_BASH_STARTUP_FILE}.mantle.bak"
	run cat "${DEFAULT_BASH_STARTUP_FILE}.mantle.bak"
	assert_output_contains '# before'
	assert_output_contains '# after'

	printf '%s\n' '# user change after install' >>"${DEFAULT_BASH_STARTUP_FILE}"
	_run_installer --uninstall --shell bash
	assert_success
	run cat "${DEFAULT_BASH_STARTUP_FILE}"
	assert_output_contains '# before'
	assert_output_contains '# after'
	assert_output_contains '# user change after install'
	assert_output_not_contains '# >>> mantle >>>'
}

@test "install.sh --no-shell-hook installs without touching startup files" {
	_run_installer --no-shell-hook
	assert_success
	_assert_installed_payload "${DEFAULT_PREFIX}"
	[[ ! -e "${DEFAULT_BASH_STARTUP_FILE}" ]]
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

	_run_installer --update --dry-run --pin "0.1.0-dev" --prefix "${prefix_path}" --no-shell-hook
	assert_success
	assert_output_contains "operation: update"
	assert_output_contains "method: symlink"

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
	local fish_path=""

	_run_installer --shell fish
	assert_success
	assert_file_exists "${XDG_CONFIG_HOME}/fish/conf.d/mantle.fish"
	run grep -F "${DEFAULT_PREFIX}/runtime/shells/fish/runtime.fish" "${XDG_CONFIG_HOME}/fish/conf.d/mantle.fish"
	assert_success

	if command -v fish >/dev/null 2>&1; then
		fish_path="$(command -v fish)"
		run env -i \
			HOME="${TEST_HOME}" \
			XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
			XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
			XDG_DATA_HOME="${XDG_DATA_HOME}" \
			XDG_STATE_HOME="${XDG_STATE_HOME}" \
			XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
			PATH="/usr/bin:/bin" \
			TERM=dumb \
			"${fish_path}" --no-config -c 'source "$XDG_CONFIG_HOME/fish/conf.d/mantle.fish"; printf "%s\n" "$MANTLE_ROOT"'
		assert_success
		[[ "${output}" == "${DEFAULT_PREFIX}" ]]
	fi
}

@test "install.sh refuses an unmanaged Fish activation file before publishing its payload" {
	local fish_file="${XDG_CONFIG_HOME}/fish/conf.d/mantle.fish"

	mkdir -p "$(dirname -- "${fish_file}")"
	printf "%s\n" "# user-managed fish setup" >"${fish_file}"

	_run_installer --shell fish
	assert_status 73
	assert_output_contains "refusing to replace an unmanaged Fish activation file"
	[[ ! -e "${DEFAULT_PREFIX}" ]]
	run cat "${fish_file}"
	assert_success
	assert_output_contains "# user-managed fish setup"
}

@test "install.sh creates a zsh activation block that can be sourced by zsh when available" {
	require_zsh
	bats_require_minimum_version "1.5.0"

	_run_installer --shell zsh
	assert_success
	assert_file_exists "${TEST_HOME}/.zshrc"

	# Activation must not depend on the host's optional RubyGems installation.
	# Preserve the workstation profile while supplying explicit, isolated paths.
	run --separate-stderr env -i \
		HOME="${TEST_HOME}" \
		ZDOTDIR="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		GEM_HOME="${TEST_HOME}/fixture-gems" \
		GEM_PATH="${TEST_HOME}/fixture-gems" \
		PATH="/usr/bin:/bin" \
		TERM=dumb \
		zsh --no-rcs -c '
			source "$HOME/.zshrc" || exit $?
			[[ "$MANTLE_INITIALIZATION_STATE" == initialized &&
				"$MANTLE_SHELL_NAME" == zsh &&
				"$MANTLE_ACTIVE_PROFILE" == workstation ]] || exit 1
			printf "%s\n" "$MANTLE_ROOT"
		'
	assert_success
	[[ "${output}" == "${DEFAULT_PREFIX}" ]]
	[[ -z "${stderr}" ]]
}

@test "installed mantle dispatches its own commands from the copied libexec payload" {
	_run_installer --no-shell-hook
	assert_success

	run env -i \
		HOME="${TEST_HOME}" \
		PATH="${STUB_DIR}:${PATH}" \
		TERM=dumb \
		"${DEFAULT_PREFIX}/bin/mantle" version --short
	assert_success
	[[ "${output}" == "0.1.0-dev" ]]

	run env -i \
		HOME="${TEST_HOME}" \
		PATH="${STUB_DIR}:${PATH}" \
		TERM=dumb \
		"${DEFAULT_PREFIX}/bin/mantle" doctor --help
	assert_success
	assert_output_contains "mantle doctor"
}

@test "install.sh rejects a release pin that does not match the source VERSION" {
	_run_installer --pin "0.1.0" --no-shell-hook
	assert_status 65
	assert_output_contains "release pin does not match this source"
	[[ ! -e "${DEFAULT_PREFIX}" ]]
}

@test "install.sh records the verified pin instead of an ambient version override" {
	run env -i \
		HOME="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		MANTLE_VERSION="untrusted-override" \
		PATH="${STUB_DIR}:${PATH}" \
		TMPDIR="${TMPDIR}" \
		TERM=dumb \
		/bin/bash "${INSTALL_SH}" --pin "0.1.0-dev" --no-shell-hook
	assert_success

	run grep -F '"version": "0.1.0-dev"' "$(_metadata_path "${DEFAULT_PREFIX}")"
	assert_success
	run grep -F '"pin": "0.1.0-dev"' "$(_metadata_path "${DEFAULT_PREFIX}")"
	assert_success
}

@test "install.sh updates an installer-owned prefix from a new exact pinned source" {
	local next_source="${TEST_HOME}/mantle-next"

	_run_installer --pin "0.1.0-dev" --no-shell-hook
	assert_success
	/bin/cp -R "${MANTLE_ROOT}" "${next_source}"
	printf '%s\n' "0.1.1" >"${next_source}/VERSION"

	_run_installer_from "${next_source}/install.sh" \
		--update \
		--pin "0.1.1" \
		--prefix "${DEFAULT_PREFIX}"
	assert_success
	assert_output_contains "update complete"

	run env -i \
		HOME="${TEST_HOME}" \
		PATH="${STUB_DIR}:${PATH}" \
		TERM=dumb \
		"${DEFAULT_PREFIX}/bin/mantle" version --short
	assert_success
	[[ "${output}" == "0.1.1" ]]
	run grep -F '"pin": "0.1.1"' "$(_metadata_path "${DEFAULT_PREFIX}")"
	assert_success
}

@test "install.sh preserves an existing symlink method during a pinned update" {
	local next_source="${TEST_HOME}/mantle-next-symlink"

	_run_installer --method symlink --pin "0.1.0-dev" --no-shell-hook
	assert_success
	/bin/cp -R "${MANTLE_ROOT}" "${next_source}"
	printf '%s\n' "0.1.1" >"${next_source}/VERSION"

	_run_installer_from "${next_source}/install.sh" \
		--update \
		--pin "0.1.1" \
		--prefix "${DEFAULT_PREFIX}"
	assert_success
	[[ -L "${DEFAULT_PREFIX}/bin" ]]
	run readlink "${DEFAULT_PREFIX}/bin"
	assert_success
	[[ "${output}" == "${next_source}/bin" ]]
}

@test "install.sh update requires an exact release pin" {
	_run_installer --update --no-shell-hook
	assert_status 64
	assert_output_contains "--update requires an exact --pin VERSION"
}

@test "install.sh doctor, disable, and enable preserve a user-owned Bash startup file" {
	printf '%s\n' '# user shell setup' >"${DEFAULT_BASH_STARTUP_FILE}"
	_run_installer --shell bash --pin "0.1.0-dev"
	assert_success

	_run_installer --doctor --prefix "${DEFAULT_PREFIX}"
	assert_success
	assert_output_contains "installed shell doctor passed"

	_run_installer --disable --shell bash --prefix "${DEFAULT_PREFIX}"
	assert_success
	assert_dir_exists "${DEFAULT_PREFIX}"
	run cat "${DEFAULT_BASH_STARTUP_FILE}"
	assert_output_contains '# user shell setup'
	assert_output_not_contains '# >>> mantle >>>'

	_run_installer --enable --shell bash --prefix "${DEFAULT_PREFIX}"
	assert_success
	run cat "${DEFAULT_BASH_STARTUP_FILE}"
	assert_output_contains '# user shell setup'
	assert_output_contains '# >>> mantle >>>'
}

@test "installed Bash activation distinguishes interactive and non-interactive shells" {
	_run_installer --shell bash --pin "0.1.0-dev"
	assert_success

	run env -i \
		HOME="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		GEM_HOME="${TEST_HOME}/fixture-gems" \
		GEM_PATH="${TEST_HOME}/fixture-gems" \
		PATH="/usr/bin:/bin" \
		TERM=dumb \
		/bin/bash --noprofile --norc -c 'source "'"${DEFAULT_BASH_STARTUP_FILE}"'"; printf "%s:%s\n" "${MANTLE_INTERACTIVE}" "${MANTLE_ROOT}"'
	assert_success
	[[ "${output}" == "0:${DEFAULT_PREFIX}" ]]

	run env -i \
		HOME="${TEST_HOME}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
		XDG_DATA_HOME="${XDG_DATA_HOME}" \
		XDG_STATE_HOME="${XDG_STATE_HOME}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
		GEM_HOME="${TEST_HOME}/fixture-gems" \
		GEM_PATH="${TEST_HOME}/fixture-gems" \
		PATH="/usr/bin:/bin" \
		TERM=dumb \
		/bin/bash --noprofile --rcfile "${DEFAULT_BASH_STARTUP_FILE}" -ic 'printf "%s:%s\n" "${MANTLE_INTERACTIVE}" "${MANTLE_ROOT}"'
	assert_success
	assert_output_contains "1:${DEFAULT_PREFIX}"
}

@test "install.sh honors explicit ZDOTDIR throughout the Zsh hook lifecycle" {
	local zsh_directory="${XDG_CONFIG_HOME}/zsh setup"
	local zsh_file="${zsh_directory}/.zshrc"

	mkdir -p "${zsh_directory}"
	printf '%s\n' '# HOME configuration' >"${TEST_HOME}/.zshrc"
	printf '%s\n' '# custom Zsh configuration' >"${zsh_file}"

	_run_installer_with_zdotdir "${zsh_directory}" --shell zsh --dry-run
	assert_success
	assert_output_contains "zsh: ${zsh_file}"
	[[ ! -e "${DEFAULT_PREFIX}" ]]

	_run_installer_with_zdotdir "${zsh_directory}" --shell zsh
	assert_success
	assert_file_exists "${zsh_file}.mantle.bak"
	run grep -F '# >>> mantle >>>' "${zsh_file}"
	assert_success
	run grep -F '# >>> mantle >>>' "${TEST_HOME}/.zshrc"
	assert_failure

	_run_installer_with_zdotdir "${zsh_directory}" --shell zsh --status
	assert_success
	assert_output_contains "file=${zsh_file}"

	_run_installer_with_zdotdir "${zsh_directory}" --shell zsh --disable
	assert_success
	assert_dir_exists "${DEFAULT_PREFIX}"
	run grep -F '# >>> mantle >>>' "${zsh_file}"
	assert_failure

	_run_installer_with_zdotdir "${zsh_directory}" --shell zsh --enable
	assert_success
	_run_installer_with_zdotdir "${zsh_directory}" --shell zsh --uninstall
	assert_success
	[[ ! -e "${DEFAULT_PREFIX}" ]]
	[[ "$(cat "${zsh_file}")" == '# custom Zsh configuration' ]]
	[[ "$(cat "${TEST_HOME}/.zshrc")" == '# HOME configuration' ]]
	_assert_no_installer_temporary_paths
}

@test "install.sh refuses empty or relative ZDOTDIR before publishing" {
	local zsh_directory=""

	for zsh_directory in '' 'relative/zsh'; do
		_run_installer_with_zdotdir "${zsh_directory}" --shell zsh
		assert_status 64
		assert_output_contains 'ZDOTDIR must be a non-empty absolute path'
		[[ ! -e "${DEFAULT_PREFIX}" ]]
		[[ ! -e "${TEST_HOME}/.zshrc" ]]
	done
}

@test "install.sh rejects malformed markers without changing hooks or the installed prefix" {
	local malformed=""
	local operation=""
	local original_file="${TEST_HOME}/startup.original"
	local metadata_before=""

	_run_installer --no-shell-hook
	assert_success
	metadata_before="$(cat "$(_metadata_path "${DEFAULT_PREFIX}")")"

	for malformed in \
		$'# user setup\n# >>> mantle >>>\nuser_command\n' \
		$'# user setup\n# <<< mantle <<<\nuser_command\n' \
		$'# >>> mantle >>>\n# >>> mantle >>>\n# <<< mantle <<<\n# <<< mantle <<<\n'; do
		printf '%s' "${malformed}" >"${DEFAULT_BASH_STARTUP_FILE}"
		cp "${DEFAULT_BASH_STARTUP_FILE}" "${original_file}"

		_run_installer --shell bash --dry-run
		assert_status 73
		cmp -s "${original_file}" "${DEFAULT_BASH_STARTUP_FILE}"

		for operation in install enable disable uninstall; do
			case "${operation}" in
			install) _run_installer --shell bash ;;
			*) _run_installer --shell bash "--${operation}" ;;
			esac
			assert_status 73
			assert_output_contains 'malformed Mantle activation markers'
			cmp -s "${original_file}" "${DEFAULT_BASH_STARTUP_FILE}"
			[[ "$(cat "$(_metadata_path "${DEFAULT_PREFIX}")")" == "${metadata_before}" ]]
			[[ ! -e "${DEFAULT_BASH_STARTUP_FILE}.mantle.bak" ]]
		done
	done
	_assert_no_installer_temporary_paths
}

@test "install.sh preserves symlinked Bash and Zsh startup files and their targets" {
	local target_file="${TEST_HOME}/managed-by-another-tool"
	local shell_name=""
	local startup_file=""

	printf '%s\n' '# external configuration' >"${target_file}"
	for shell_name in bash zsh; do
		if [[ "${shell_name}" == bash ]]; then
			startup_file="${DEFAULT_BASH_STARTUP_FILE}"
		else
			startup_file="${TEST_HOME}/.zshrc"
		fi
		ln -s "${target_file}" "${startup_file}"
		_run_installer --shell "${shell_name}"
		assert_status 73
		assert_output_contains 'symlinked or non-regular startup file'
		[[ -L "${startup_file}" ]]
		[[ "$(cat "${target_file}")" == '# external configuration' ]]
		[[ ! -e "${DEFAULT_PREFIX}" ]]
	done

	_run_installer --no-shell-hook
	assert_success
	_run_installer --shell bash --disable
	assert_status 73
	_run_installer --shell bash --uninstall
	assert_status 73
	assert_dir_exists "${DEFAULT_PREFIX}"
	[[ -L "${DEFAULT_BASH_STARTUP_FILE}" ]]
	[[ "$(cat "${target_file}")" == '# external configuration' ]]
}

@test "install.sh refuses a non-regular startup destination before publishing" {
	mkdir -p "${DEFAULT_BASH_STARTUP_FILE}"
	_run_installer --shell bash
	assert_status 73
	assert_output_contains 'symlinked or non-regular startup file'
	[[ -d "${DEFAULT_BASH_STARTUP_FILE}" ]]
	[[ ! -e "${DEFAULT_PREFIX}" ]]
}

@test "install.sh preserves private startup modes across install and hook removal" {
	local operation=""

	umask 022
	printf '%s\n' '# private configuration' >"${DEFAULT_BASH_STARTUP_FILE}"
	chmod 0600 "${DEFAULT_BASH_STARTUP_FILE}"
	_run_installer --shell bash
	assert_success
	[[ "$(file_permissions "${DEFAULT_BASH_STARTUP_FILE}")" == 600 ]]
	[[ "$(file_permissions "${DEFAULT_BASH_STARTUP_FILE}.mantle.bak")" == 600 ]]

	for operation in disable enable uninstall; do
		_run_installer --shell bash "--${operation}"
		assert_success
		[[ "$(file_permissions "${DEFAULT_BASH_STARTUP_FILE}")" == 600 ]]
	done
	[[ "$(cat "${DEFAULT_BASH_STARTUP_FILE}")" == '# private configuration' ]]
	_assert_no_installer_temporary_paths
}

@test "install.sh leaves unmanaged startup bytes unchanged during disable and uninstall" {
	local original_file="${TEST_HOME}/startup.original"

	printf '# user configuration\n\n\n' >"${DEFAULT_BASH_STARTUP_FILE}"
	cp "${DEFAULT_BASH_STARTUP_FILE}" "${original_file}"
	_run_installer --no-shell-hook
	assert_success
	_run_installer --shell bash --disable
	assert_success
	cmp -s "${original_file}" "${DEFAULT_BASH_STARTUP_FILE}"
	_run_installer --shell bash --uninstall
	assert_success
	cmp -s "${original_file}" "${DEFAULT_BASH_STARTUP_FILE}"
}

@test "install.sh removes owned temporary roots after success and staging failure" {
	local metadata_before=""

	_run_installer --shell bash
	assert_success
	_assert_no_installer_temporary_paths
	metadata_before="$(cat "$(_metadata_path "${DEFAULT_PREFIX}")")"

	create_stub cp 1
	_run_installer --update --pin 0.1.0-dev --no-shell-hook
	assert_failure
	[[ "$(cat "$(_metadata_path "${DEFAULT_PREFIX}")")" == "${metadata_before}" ]]
	_assert_no_installer_temporary_paths
}

@test "install.sh retains the previous installation when publication and rollback both fail" {
	local metadata_before=""
	local backup_path=""

	_run_installer --no-shell-hook
	assert_success
	metadata_before="$(cat "$(_metadata_path "${DEFAULT_PREFIX}")")"
	_create_failed_rollback_stub

	_run_installer --update --pin 0.1.0-dev --no-shell-hook
	assert_failure
	assert_output_contains 'backup preserved:'
	[[ ! -e "${DEFAULT_PREFIX}" ]]
	run find "$(dirname -- "${DEFAULT_PREFIX}")" -maxdepth 1 -type d -name 'mantle.previous.*'
	assert_success
	[[ -n "${output}" && "${output}" != *$'\n'* ]]
	backup_path="${output}"
	[[ "$(cat "$(_metadata_path "${backup_path}")")" == "${metadata_before}" ]]
	_assert_no_installer_temporary_paths
}

@test "install.sh exits on TERM and restores the previous installation during publication" {
	local metadata_before=""

	_run_installer --no-shell-hook
	assert_success
	metadata_before="$(cat "$(_metadata_path "${DEFAULT_PREFIX}")")"
	_create_interrupted_publication_stub

	_run_installer --update --pin 0.1.0-dev --no-shell-hook
	assert_status 143
	[[ "$(cat "$(_metadata_path "${DEFAULT_PREFIX}")")" == "${metadata_before}" ]]
	run find "$(dirname -- "${DEFAULT_PREFIX}")" -maxdepth 1 -name 'mantle.previous.*'
	assert_success
	[[ -z "${output}" ]]
	_assert_no_installer_temporary_paths
}

@test "install.sh environment-diff propagates initialization failure and removes capture files" {
	local broken_prefix="${TEST_HOME}/broken-prefix"

	mkdir -p "${broken_prefix}"
	printf 'return 23\n' >"${broken_prefix}/.shellrc"
	_run_installer --environment-diff --prefix "${broken_prefix}"
	assert_status 23
	assert_output_contains 'Mantle initialization failed while capturing the environment'
	assert_output_not_contains 'No environment changes.'
	_assert_no_installer_temporary_paths
}

@test "install.sh environment-diff propagates an initial capture failure" {
	create_stub bash 42
	_run_installer --environment-diff --no-shell-hook
	assert_status 42
	assert_output_contains 'failed to capture the initial environment'
	_assert_no_installer_temporary_paths
}
