#!/usr/bin/env bats
# Integration tests for the installer matrix.
# Discovers all installers dynamically — no hand-written list.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	load '../test_helper/stubs'
	setup_isolated_home
	setup_stub_dir

	INSTALLERS_DIR="${MANTLE_ROOT}/libexec/mantle/installers"
	MANTLE_BIN="${MANTLE_ROOT}/bin/mantle"
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_mantle_install() {
	run env -i \
		HOME="${TEST_HOME}" \
		MANTLE_ROOT="${MANTLE_ROOT}" \
		PATH="${STUB_DIR}:${PATH}" \
		TERM=dumb \
		"${MANTLE_BIN}" install "$@"
}

# Return the tool name from an installer path (strips directory and .sh).
_tool_name() {
	local installer_path="${1:?}"
	local name="${installer_path##*/}"
	printf "%s\n" "${name%.sh}"
}

# ---------------------------------------------------------------------------
# Per-installer structural tests (dynamic discovery)
# ---------------------------------------------------------------------------

@test "every discovered installer is executable" {
	local failed=0
	for installer in "${INSTALLERS_DIR}"/*.sh; do
		[[ -f "${installer}" ]] || continue
		if [[ ! -x "${installer}" ]]; then
			printf "Not executable: %s\n" "${installer}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

@test "every discovered installer has valid Bash syntax" {
	local failed=0
	for installer in "${INSTALLERS_DIR}"/*.sh; do
		[[ -f "${installer}" ]] || continue
		if ! /bin/bash -n "${installer}" 2>/dev/null; then
			printf "Syntax error: %s\n" "${installer}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

@test "every discovered installer does not use EGOHYGIENE namespace" {
	local failed=0
	for installer in "${INSTALLERS_DIR}"/*.sh; do
		[[ -f "${installer}" ]] || continue
		if grep -q "EGOHYGIENE" "${installer}" 2>/dev/null; then
			printf "EGOHYGIENE reference: %s\n" "${installer}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

@test "every discovered installer does not use legacy INSTALL_ contract" {
	local failed=0
	for installer in "${INSTALLERS_DIR}"/*.sh; do
		[[ -f "${installer}" ]] || continue
		if grep -qE '^\s*INSTALL_[A-Z]' "${installer}" 2>/dev/null; then
			printf "Legacy INSTALL_ variable: %s\n" "${installer}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

@test "every discovered installer does not invoke sudo" {
	local failed=0
	for installer in "${INSTALLERS_DIR}"/*.sh; do
		[[ -f "${installer}" ]] || continue
		if grep -qE '\bsudo\b' "${installer}" 2>/dev/null; then
			printf "sudo found: %s\n" "${installer}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# CLI surface — help and dry-run for well-known installers
# ---------------------------------------------------------------------------

@test "mantle install eza --help exits 0" {
	_mantle_install eza --help
	assert_success
	assert_output_contains "eza"
}

@test "mantle install eza --help uses canonical mantle install form" {
	_mantle_install eza --help
	assert_success
	assert_output_contains "mantle install"
}

@test "mantle install talisman --help exits 0" {
	_mantle_install talisman --help
	assert_success
}

@test "mantle install talisman --dry-run exits 0" {
	_mantle_install talisman --dry-run --version 1.32.0
	assert_success
	assert_output_contains "tool: talisman"
}

@test "GitHub installer defaults resolve from the lock without network" {
	stub_curl_failure 99
	_mantle_install eza --dry-run
	assert_success
	assert_output_contains "version: 0.23.5"
	assert_output_contains "resolution: lockfile"
}

@test "GitHub installer rejects mutable version selectors" {
	_mantle_install eza --dry-run --version latest
	assert_status 64
	assert_output_contains "Mutable installer selector"
}

@test "unchecksummed GitHub installer fails before download without explicit opt-out" {
	stub_curl_failure 99
	_mantle_install asdf
	assert_status 77
	assert_output_contains "explicitly rerun with --no-verify"
}

@test "Python installer defaults to its exact package lock" {
	create_recording_stub "uv" 0
	_mantle_install httpie --dry-run --manager uv
	assert_success
	assert_output_contains "httpie==3.2.4"
	assert_output_contains "resolution: lockfile"
}

@test "assurance diagnostics list the locked components and reject unknown installers" {
	_mantle_install --assurance pyenv
	assert_success
	assert_output_contains "commit-identity"
	assert_output_contains "pyenv-virtualenv"
	assert_output_contains "0f16606e4f906bac76a409bcab40974d579067bf"

	_mantle_install --assurance nonexistent-tool-xyz
	assert_status 64
	assert_output_contains "no assurance record"
}

@test "assurance diagnostics reject extra arguments and unsafe installer names" {
	_mantle_install --assurance eza extra
	assert_status 64
	_mantle_install --assurance ../eza
	assert_status 64
}

@test "GitHub dry runs use the locked addlicense and vale release metadata" {
	stub_curl_failure 99
	_mantle_install addlicense --dry-run
	assert_success
	assert_output_contains "addlicense_v1.2.0_"
	assert_output_contains "checksum_asset: checksums.txt"

	_mantle_install vale --dry-run
	assert_success
	assert_output_contains "github.com/vale-cli/vale/"
	assert_output_contains "checksum_asset: vale_3.17.1_checksums.txt"
}

@test "checksum-free releases expose the explicit verification opt-out" {
	_mantle_install eza --dry-run --no-verify
	assert_success
	assert_output_contains "verification: explicit-opt-out"
	assert_output_contains "checksum_asset: none"
}

@test "GitHub dry runs report effective verification without changing assurance capability" {
	create_recording_stub curl 99
	create_recording_stub wget 99
	create_recording_stub mktemp 99
	_mantle_install vale --dry-run
	assert_success
	assert_output_contains "verification: release-checksum"

	_mantle_install vale --dry-run --no-verify
	assert_success
	assert_output_contains "verification: explicit-opt-out"
	assert_output_not_contains "verification: release-checksum"

	_mantle_install --assurance vale
	assert_success
	assert_output_contains "release-checksum"
	[[ "$(stub_call_count curl)" -eq 0 ]]
	[[ "$(stub_call_count wget)" -eq 0 ]]
	[[ "$(stub_call_count mktemp)" -eq 0 ]]
}

@test "Nerd Fonts all-family dry runs defer enumeration without network or staging" {
	create_recording_stub curl 99
	create_recording_stub wget 99
	create_recording_stub mktemp 99
	create_recording_stub mkdir 99
	local destination="${TEST_HOME}/fonts-not-created"
	_mantle_install nerd-fonts --dry-run --all --destination "${destination}"
	assert_success
	assert_output_contains "version: 3.5.0"
	assert_output_contains "resolution: lockfile"
	assert_output_contains "selection: all"
	assert_output_contains "enumeration: deferred until installation"
	assert_output_contains "metadata_url: https://api.github.com/repos/ryanoasis/nerd-fonts/releases/tags/v3.5.0"
	assert_output_contains "destination: ${destination}"

	_mantle_install nerd-fonts --all --version 3.4.0 --dry-run --destination "${destination}"
	assert_success
	assert_output_contains "resolution: explicit"
	assert_output_contains "metadata_url: https://api.github.com/repos/ryanoasis/nerd-fonts/releases/tags/v3.4.0"
	[[ ! -e "${destination}" ]]
	[[ "$(stub_call_count curl)" -eq 0 ]]
	[[ "$(stub_call_count wget)" -eq 0 ]]
	[[ "$(stub_call_count mktemp)" -eq 0 ]]
	[[ "$(stub_call_count mkdir)" -eq 0 ]]
}

@test "repository installers reject branch and abbreviated commit overrides before network" {
	local installer=""
	local ref=""
	create_recording_stub git 99
	create_recording_stub curl 99
	for installer in pyenv shdoc google-fonts; do
		for ref in feature-branch 0123456789ab; do
			_mantle_install "${installer}" --dry-run --ref "${ref}"
			assert_status 64
			assert_output_contains "full 40-character Git commit ID"
		done
	done
	[[ "$(stub_call_count git)" -eq 0 ]]
	[[ "$(stub_call_count curl)" -eq 0 ]]
}

@test "repository dry runs accept full commit overrides and report explicit resolution" {
	local installer=""
	local commit_id="0123456789abcdef0123456789abcdef01234567"
	create_recording_stub git 99
	create_recording_stub curl 99
	for installer in pyenv shdoc google-fonts; do
		_mantle_install "${installer}" --dry-run --ref "${commit_id}"
		assert_success
		assert_output_contains "ref: ${commit_id}"
		assert_output_contains "resolution: explicit"
		assert_output_contains "verification: commit-identity"
	done
	[[ "$(stub_call_count git)" -eq 0 ]]
	[[ "$(stub_call_count curl)" -eq 0 ]]
}

@test "repository installers retain their locked defaults without contacting upstream" {
	local installer=""
	create_recording_stub git 99
	create_recording_stub curl 99
	for installer in pyenv shdoc google-fonts; do
		_mantle_install "${installer}" --dry-run
		assert_success
		assert_output_contains "resolution: lockfile"
		assert_output_contains "verification: commit-identity"
	done
	[[ "$(stub_call_count git)" -eq 0 ]]
	[[ "$(stub_call_count curl)" -eq 0 ]]
}

@test "Linuxbrew dry run uses its locked commit and digest" {
	[[ "$(uname -s)" == Linux ]] || skip "Linuxbrew only supports Linux"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="/usr/bin:/bin" \
		"${MANTLE_BIN}" install linuxbrew --dry-run
	assert_success
	assert_output_contains "Homebrew/install/6cb910c93f8194b1661a490278a488482399d380/install.sh"
	assert_output_contains "resolution: lockfile"
	assert_output_contains "verification: sha256"
	assert_output_contains "12479a24be3f5307eecac7cde670fad7118640f031229e964f544b1367b52a41"
}

@test "Linuxbrew custom URL never inherits the default lock digest" {
	[[ "$(uname -s)" == Linux ]] || skip "Linuxbrew only supports Linux"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="/usr/bin:/bin" \
		"${MANTLE_BIN}" install linuxbrew --dry-run --installer-url https://example.invalid/install.sh
	assert_status 77
	assert_output_contains "Refusing to execute a remote installer without verification"

	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="/usr/bin:/bin" \
		"${MANTLE_BIN}" install linuxbrew --dry-run --installer-url https://example.invalid/install.sh --accept-unverified-installer
	assert_success
	assert_output_contains "resolution: explicit"
	assert_output_contains "verification: explicit-opt-out"
	assert_output_contains "checksum: explicitly accepted as unverified"
}

@test "mantle install eza unknown-option exits 64" {
	_mantle_install eza --unknown-option-xyz
	assert_status 64
}

@test "mantle install shfmt --help exits 0" {
	_mantle_install shfmt --help
	assert_success
}

@test "mantle install shdoc --help exits 0" {
	_mantle_install shdoc --help
	assert_success
}

@test "mantle install pyenv --help exits 0" {
	_mantle_install pyenv --help
	assert_success
}

@test "mantle install linuxbrew --help exits 0" {
	_mantle_install linuxbrew --help
	assert_success
}

@test "mantle install docker-desktop --help exits 0" {
	_mantle_install docker-desktop --help
	assert_success
}
