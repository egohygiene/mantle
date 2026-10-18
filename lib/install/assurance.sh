# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# Read and validate Mantle's installer-resolution contract.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/assurance.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INSTALL_ASSURANCE_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Print the canonical installer lock registry path.
mantle_install_assurance_registry() {
	printf "%s\n" "${MANTLE_ROOT}/config/installers.lock.tsv"
}

# @description Read one field from an installer component's lock row.
# @arg $1 string Installer name.
# @arg $2 string Component name.
# @arg $3 string Column name.
# @stdout The selected field.
# @exitcode 1 The component or field was not found.
# @exitcode 64 Arguments or the registry are invalid.
mantle_install_assurance_field() {
	local installer="${1:-}"
	local component="${2:-}"
	local field="${3:-}"
	local registry=""

	if (($# != 3)) || [[ ! "${installer}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
		[[ ! "${component}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
		[[ ! "${field}" =~ ^[a-z_][a-z0-9_]*$ ]]; then
		return 64
	fi
	registry="$(mantle_install_assurance_registry)"
	if [[ ! -r "${registry}" ]]; then
		mantle_log_error "Missing installer assurance registry: ${registry}"
		return 64
	fi

	awk -F '\t' -v installer="${installer}" -v component="${component}" -v field="${field}" '
		/^#/ { next }
		$1 == "installer" {
			for (field_index = 1; field_index <= NF; field_index++) {
				if ($field_index == field) column_index = field_index
			}
			next
		}
		$1 == installer && $2 == component && column_index > 0 {
			print $column_index
			found = 1
			exit
		}
		END { if (!found) exit 1 }
	' "${registry}"
}

# @description Read the locked value for one installer component.
mantle_install_assurance_locked_value() {
	mantle_install_assurance_field "${1:-}" "${2:-}" "locked_value"
}

# @description Reject well-known mutable selectors and unsafe lock tokens.
# @arg $1 string Version, tag, or commit selector.
# @exitcode 0 The selector is suitable for deterministic resolution.
# @exitcode 64 The selector is empty, unsafe, or explicitly floating.
mantle_install_assurance_validate_selector() {
	local selector="${1:-}"

	if (($# != 1)) || [[ ! "${selector}" =~ ^[A-Za-z0-9._+@-]+$ ]]; then
		mantle_log_error "Invalid installer version or ref: ${selector:-<empty>}"
		return 64
	fi
	case "${selector}" in
	HEAD | head | latest | main | master | nightly | stable)
		mantle_log_error "Mutable installer selector is not allowed: ${selector}"
		return 64
		;;
	esac
}

# @description Require a full Git commit identity for repository installations.
# @arg $1 string Full 40-character hexadecimal commit ID.
# @exitcode 64 The selector is not a full commit ID.
mantle_install_assurance_validate_commit() {
	local commit_id="${1:-}"

	if (($# != 1)) || [[ ! "${commit_id}" =~ ^[[:xdigit:]]{40}$ ]]; then
		mantle_log_error "Installer repository ref must be a full 40-character Git commit ID: ${commit_id:-<empty>}"
		return 64
	fi
}

# @description Resolve an explicit selector or the registry default.
# @arg $1 string Installer name.
# @arg $2 string Component name.
# @arg $3 string Optional explicit selector.
# @stdout Deterministic selector.
mantle_install_assurance_resolve() {
	local installer="${1:-}"
	local component="${2:-}"
	local requested="${3:-}"
	local resolved=""

	if (($# != 3)); then return 64; fi
	if [[ -n "${requested}" ]]; then
		resolved="${requested}"
	else
		resolved="$(mantle_install_assurance_locked_value "${installer}" "${component}")" || {
			mantle_log_error "No locked default exists for ${installer}/${component}"
			return 64
		}
	fi
	if [[ "${resolved}" == "manager" ]]; then
		mantle_log_error "${installer}/${component} is resolved by its package manager"
		return 64
	fi
	mantle_install_assurance_validate_selector "${resolved}" || return $?
	printf "%s\n" "${resolved}"
}

MANTLE_INSTALL_ASSURANCE_LIBRARY_LOADED="1"

return 0
