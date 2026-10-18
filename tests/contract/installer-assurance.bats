# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Installer assurance registry contracts.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	INSTALLERS_DIR="${MANTLE_ROOT}/libexec/mantle/installers"
	ASSURANCE_REGISTRY="${MANTLE_ROOT}/config/installers.lock.tsv"
}

@test "assurance registry declares schema version and canonical columns" {
	run awk -F '\t' '
		/^# schema_version=1$/ { schema = 1; next }
		$1 == "installer" {
			if ($0 == "installer\tcomponent\tresolver\tsource\tlock_policy\tlocked_value\tverification\tdigest") header = 1
		}
		END { exit !(schema && header) }
	' "${ASSURANCE_REGISTRY}"
	assert_success
}

@test "every installer has an assurance record" {
	local installer=""
	local installer_name=""
	local failed=0

	for installer in "${INSTALLERS_DIR}"/*.sh; do
		installer_name="${installer##*/}"
		installer_name="${installer_name%.sh}"
		if ! awk -F '\t' -v name="${installer_name}" '$1 == name { found = 1 } END { exit !found }' "${ASSURANCE_REGISTRY}"; then
			printf "Missing assurance record: %s\n" "${installer_name}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

@test "assurance component keys are unique and policies are valid" {
	run awk -F '\t' '
		/^#/ || $1 == "installer" { next }
		{
			key = $1 SUBSEP $2
			if (seen[key]++) exit 1
			if ($3 !~ /^(github-release|python-package|git-commit|ruby-gem|npm-package|remote-script|native-package)$/) exit 1
			if ($5 !~ /^(exact|manager)$/) exit 1
			if ($7 !~ /^(release-checksum|explicit-opt-out|package-manager|commit-identity|sha256)$/) exit 1
			if ($5 == "exact" && $6 ~ /^(HEAD|head|latest|main|master|nightly|stable)$/) exit 1
			if ($5 == "manager" && $6 != "manager") exit 1
			if ($7 == "commit-identity" && (length($6) != 40 || $6 !~ /^[[:xdigit:]]+$/)) exit 1
			if ($7 == "sha256" && $8 !~ /^[[:xdigit:]]{64}$/) exit 1
		}
	' "${ASSURANCE_REGISTRY}"
	assert_success
}

@test "GitHub installers publish their checksum capability truthfully" {
	local installer=""
	local installer_name=""
	local expected_verification=""
	local actual_verification=""
	local failed=0

	for installer in "${INSTALLERS_DIR}"/*.sh; do
		grep -q 'mantle_install_github_main' "${installer}" || continue
		installer_name="${installer##*/}"
		installer_name="${installer_name%.sh}"
		if grep -q '^MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE=' "${installer}"; then
			expected_verification="release-checksum"
		else
			expected_verification="explicit-opt-out"
		fi
		actual_verification="$(awk -F '\t' -v name="${installer_name}" '$1 == name && $2 == "artifact" { print $7 }' "${ASSURANCE_REGISTRY}")"
		if [[ "${actual_verification}" != "${expected_verification}" ]]; then
			printf "%s: expected %s, found %s\n" "${installer_name}" "${expected_verification}" "${actual_verification}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}
