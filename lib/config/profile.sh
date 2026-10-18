# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# shellcheck disable=SC2249 # Closed case statements intentionally treat unmatched values as no-ops.
# Resolve Mantle's versioned profile and configuration policy without executing
# user configuration as shell code.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/config/profile.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_CONFIG_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] config library requires MANTLE_ROOT\n" >&2
	return 1
fi

if ! command -v mantle_profile_select >/dev/null 2>&1; then
	# shellcheck disable=SC1091
	source "${MANTLE_ROOT}/lib/core/profiles.sh" || return $?
fi

MANTLE_CONFIG_SUPPORTED_SCHEMA_VERSION="1"

# @description Normalize a literal boolean without evaluating configuration text.
mantle_config_boolean_normalize() {
	case "${1:-}" in
	1 | true | yes | on) printf "true\n" ;;
	0 | false | no | off) printf "false\n" ;;
	*) return 64 ;;
	esac
}

# @description Map one supported setting key to its fixed policy suffix.
mantle_config_setting_variable() {
	case "${1:-}" in
	aliases.safe) printf "ALIASES_SAFE\n" ;;
	aliases.network) printf "ALIASES_NETWORK\n" ;;
	aliases.system) printf "ALIASES_SYSTEM\n" ;;
	aliases.legacy) printf "ALIASES_LEGACY\n" ;;
	aliases.safety) printf "ALIASES_SAFETY\n" ;;
	history) printf "HISTORY\n" ;;
	updates.suppress_checks) printf "SUPPRESS_UPDATE_CHECKS\n" ;;
	experimental) printf "EXPERIMENTAL\n" ;;
	presentation) printf "PRESENTATION\n" ;;
	*) return 64 ;;
	esac
}

# @description Validate a supported setting against its declared value type.
mantle_config_validate_setting() {
	local setting_name="${1:-}"
	local setting_value="${2:-}"

	case "${setting_name}" in
	aliases.safe | aliases.network | aliases.system | aliases.legacy | aliases.safety | history | updates.suppress_checks)
		mantle_config_boolean_normalize "${setting_value}" >/dev/null
		;;
	experimental)
		setting_value="$(mantle_config_boolean_normalize "${setting_value}")" || return 64
		if [[ "${setting_value}" == "true" ]]; then
			printf "[mantle:error] experimental behavior is unavailable\n" >&2
			return 64
		fi
		;;
	presentation)
		case "${setting_value}" in private | share-safe | ci | off) ;; *) return 64 ;; esac
		;;
	*) return 64 ;;
	esac
}

# @description Clear file-derived values before a fresh configuration read.
mantle_config_reset_parsed() {
	MANTLE_CONFIG_REQUESTED_PROFILE=""
	MANTLE_CONFIG_DECLARED_SCHEMA=""
	MANTLE_CONFIG_SEEN_KEYS=":"
	MANTLE_CONFIG_VALUE_ALIASES_SAFE=""
	MANTLE_CONFIG_VALUE_ALIASES_NETWORK=""
	MANTLE_CONFIG_VALUE_ALIASES_SYSTEM=""
	MANTLE_CONFIG_VALUE_ALIASES_LEGACY=""
	MANTLE_CONFIG_VALUE_ALIASES_SAFETY=""
	MANTLE_CONFIG_VALUE_HISTORY=""
	MANTLE_CONFIG_VALUE_SUPPRESS_UPDATE_CHECKS=""
	MANTLE_CONFIG_VALUE_EXPERIMENTAL=""
	MANTLE_CONFIG_VALUE_PRESENTATION=""
}

# @description Store a validated value in a fixed file-policy variable.
mantle_config_set_parsed_value() {
	local setting_variable="${1:-}"
	local setting_value="${2:-}"

	case "${setting_variable}" in
	ALIASES_SAFE) MANTLE_CONFIG_VALUE_ALIASES_SAFE="${setting_value}" ;;
	ALIASES_NETWORK) MANTLE_CONFIG_VALUE_ALIASES_NETWORK="${setting_value}" ;;
	ALIASES_SYSTEM) MANTLE_CONFIG_VALUE_ALIASES_SYSTEM="${setting_value}" ;;
	ALIASES_LEGACY) MANTLE_CONFIG_VALUE_ALIASES_LEGACY="${setting_value}" ;;
	ALIASES_SAFETY) MANTLE_CONFIG_VALUE_ALIASES_SAFETY="${setting_value}" ;;
	HISTORY) MANTLE_CONFIG_VALUE_HISTORY="${setting_value}" ;;
	SUPPRESS_UPDATE_CHECKS) MANTLE_CONFIG_VALUE_SUPPRESS_UPDATE_CHECKS="${setting_value}" ;;
	EXPERIMENTAL) MANTLE_CONFIG_VALUE_EXPERIMENTAL="${setting_value}" ;;
	PRESENTATION) MANTLE_CONFIG_VALUE_PRESENTATION="${setting_value}" ;;
	*) return 64 ;;
	esac
}

# @description Print one fixed file-policy value.
mantle_config_get_parsed_value() {
	case "${1:-}" in
	ALIASES_SAFE) printf "%s\n" "${MANTLE_CONFIG_VALUE_ALIASES_SAFE}" ;;
	ALIASES_NETWORK) printf "%s\n" "${MANTLE_CONFIG_VALUE_ALIASES_NETWORK}" ;;
	ALIASES_SYSTEM) printf "%s\n" "${MANTLE_CONFIG_VALUE_ALIASES_SYSTEM}" ;;
	ALIASES_LEGACY) printf "%s\n" "${MANTLE_CONFIG_VALUE_ALIASES_LEGACY}" ;;
	ALIASES_SAFETY) printf "%s\n" "${MANTLE_CONFIG_VALUE_ALIASES_SAFETY}" ;;
	HISTORY) printf "%s\n" "${MANTLE_CONFIG_VALUE_HISTORY}" ;;
	SUPPRESS_UPDATE_CHECKS) printf "%s\n" "${MANTLE_CONFIG_VALUE_SUPPRESS_UPDATE_CHECKS}" ;;
	EXPERIMENTAL) printf "%s\n" "${MANTLE_CONFIG_VALUE_EXPERIMENTAL}" ;;
	PRESENTATION) printf "%s\n" "${MANTLE_CONFIG_VALUE_PRESENTATION}" ;;
	*) return 64 ;;
	esac
}

# @description Parse a literal versioned key=value configuration file without sourcing it.
mantle_config_read_file() {
	local config_path="${1:-}"
	local config_line=""
	local config_key=""
	local config_value=""
	local setting_variable=""
	local line_number=0

	if (($# != 1)) || [[ -z "${config_path}" || ! -f "${config_path}" || ! -r "${config_path}" ]]; then
		return 66
	fi

	mantle_config_reset_parsed
	while IFS= read -r config_line || [[ -n "${config_line}" ]]; do
		line_number=$((line_number + 1))
		config_line="${config_line%$'\r'}"
		case "${config_line}" in "" | \#*) continue ;; esac

		if [[ "${config_line}" != *=* ]]; then
			printf "[mantle:error] invalid config line %d: expected key=value\n" "${line_number}" >&2
			return 78
		fi
		config_key="${config_line%%=*}"
		config_value="${config_line#*=}"
		if [[ -z "${config_key}" || "${config_key}" == *[[:space:]]* ||
			"${config_value}" == *[[:space:]]* ]]; then
			printf "[mantle:error] invalid config line %d: whitespace is not permitted around keys or values\n" "${line_number}" >&2
			return 78
		fi
		case "${MANTLE_CONFIG_SEEN_KEYS}" in
		*":${config_key}:"*)
			printf "[mantle:error] duplicate config key on line %d\n" "${line_number}" >&2
			return 78
			;;
		esac
		MANTLE_CONFIG_SEEN_KEYS="${MANTLE_CONFIG_SEEN_KEYS}${config_key}:"

		case "${config_key}" in
		schema_version)
			MANTLE_CONFIG_DECLARED_SCHEMA="${config_value}"
			;;
		profile)
			case "${config_value}" in
			"" | [!a-z0-9]* | *[!a-z0-9-]*)
				printf "[mantle:error] invalid profile name on line %d\n" "${line_number}" >&2
				return 78
				;;
			esac
			MANTLE_CONFIG_REQUESTED_PROFILE="${config_value}"
			;;
		*)
			setting_variable="$(mantle_config_setting_variable "${config_key}")" || {
				printf "[mantle:error] unknown config key on line %d\n" "${line_number}" >&2
				return 78
			}
			if ! mantle_config_validate_setting "${config_key}" "${config_value}"; then
				printf "[mantle:error] invalid value on line %d for %s\n" \
					"${line_number}" "${config_key}" >&2
				return 78
			fi
			case "${config_key}" in
			presentation) ;;
			*) config_value="$(mantle_config_boolean_normalize "${config_value}")" ;;
			esac
			mantle_config_set_parsed_value "${setting_variable}" "${config_value}" || return 78
			;;
		esac
	done <"${config_path}"

	if [[ "${MANTLE_CONFIG_DECLARED_SCHEMA}" != "${MANTLE_CONFIG_SUPPORTED_SCHEMA_VERSION}" ]]; then
		printf "[mantle:error] config schema_version must be %s\n" \
			"${MANTLE_CONFIG_SUPPORTED_SCHEMA_VERSION}" >&2
		return 78
	fi
}

# @description Resolve the existing profile graph and initialize compatible policy defaults.
mantle_config_load_profile() {
	local requested_profile="${1:-workstation}"
	local setting_variable=""

	mantle_profile_select "${requested_profile}" || return $?
	MANTLE_POLICY_ALIASES_SAFE="false"
	MANTLE_POLICY_ALIASES_NETWORK="false"
	MANTLE_POLICY_ALIASES_SYSTEM="false"
	MANTLE_POLICY_ALIASES_LEGACY="false"
	MANTLE_POLICY_ALIASES_SAFETY="false"
	MANTLE_POLICY_HISTORY="false"
	if mantle_profile_has "interactive"; then
		# Preserve the existing alias corpus until an explicit policy chooses groups.
		MANTLE_POLICY_ALIASES_LEGACY="true"
		MANTLE_POLICY_HISTORY="true"
	fi
	MANTLE_POLICY_SUPPRESS_UPDATE_CHECKS="false"
	MANTLE_POLICY_EXPERIMENTAL="false"
	MANTLE_POLICY_PRESENTATION="private"
	for setting_variable in ALIASES_SAFE ALIASES_NETWORK ALIASES_SYSTEM ALIASES_LEGACY ALIASES_SAFETY HISTORY SUPPRESS_UPDATE_CHECKS EXPERIMENTAL PRESENTATION; do
		mantle_config_set_policy_source "${setting_variable}" "profile:${requested_profile}" || return 78
	done
}

# @description Set one fixed effective policy variable.
mantle_config_set_policy_value() {
	local setting_variable="${1:-}"
	local setting_value="${2:-}"

	case "${setting_variable}" in
	ALIASES_SAFE) MANTLE_POLICY_ALIASES_SAFE="${setting_value}" ;;
	ALIASES_NETWORK) MANTLE_POLICY_ALIASES_NETWORK="${setting_value}" ;;
	ALIASES_SYSTEM) MANTLE_POLICY_ALIASES_SYSTEM="${setting_value}" ;;
	ALIASES_LEGACY) MANTLE_POLICY_ALIASES_LEGACY="${setting_value}" ;;
	ALIASES_SAFETY) MANTLE_POLICY_ALIASES_SAFETY="${setting_value}" ;;
	HISTORY) MANTLE_POLICY_HISTORY="${setting_value}" ;;
	SUPPRESS_UPDATE_CHECKS) MANTLE_POLICY_SUPPRESS_UPDATE_CHECKS="${setting_value}" ;;
	EXPERIMENTAL) MANTLE_POLICY_EXPERIMENTAL="${setting_value}" ;;
	PRESENTATION) MANTLE_POLICY_PRESENTATION="${setting_value}" ;;
	*) return 64 ;;
	esac
}

# @description Record where one effective policy value originated.
mantle_config_set_policy_source() {
	local setting_variable="${1:-}"
	local setting_source="${2:-}"

	case "${setting_variable}" in
	ALIASES_SAFE) MANTLE_POLICY_SOURCE_ALIASES_SAFE="${setting_source}" ;;
	ALIASES_NETWORK) MANTLE_POLICY_SOURCE_ALIASES_NETWORK="${setting_source}" ;;
	ALIASES_SYSTEM) MANTLE_POLICY_SOURCE_ALIASES_SYSTEM="${setting_source}" ;;
	ALIASES_LEGACY) MANTLE_POLICY_SOURCE_ALIASES_LEGACY="${setting_source}" ;;
	ALIASES_SAFETY) MANTLE_POLICY_SOURCE_ALIASES_SAFETY="${setting_source}" ;;
	HISTORY) MANTLE_POLICY_SOURCE_HISTORY="${setting_source}" ;;
	SUPPRESS_UPDATE_CHECKS) MANTLE_POLICY_SOURCE_SUPPRESS_UPDATE_CHECKS="${setting_source}" ;;
	EXPERIMENTAL) MANTLE_POLICY_SOURCE_EXPERIMENTAL="${setting_source}" ;;
	PRESENTATION) MANTLE_POLICY_SOURCE_PRESENTATION="${setting_source}" ;;
	*) return 64 ;;
	esac
}

# @description Apply a nonempty validated value with its provenance.
mantle_config_apply_value() {
	local setting_variable="${1:-}"
	local setting_value="${2:-}"
	local setting_source="${3:-}"
	[[ -n "${setting_value}" ]] || return 0
	mantle_config_set_policy_value "${setting_variable}" "${setting_value}" || return 64
	mantle_config_set_policy_source "${setting_variable}" "${setting_source}" || return 64
}

# @description Print an allowlisted policy environment override.
mantle_config_environment_value() {
	case "${1:-}" in
	MANTLE_ENABLE_SAFE_ALIASES) printf "%s\n" "${MANTLE_ENABLE_SAFE_ALIASES:-}" ;;
	MANTLE_ENABLE_NETWORK_ALIASES) printf "%s\n" "${MANTLE_ENABLE_NETWORK_ALIASES:-}" ;;
	MANTLE_ENABLE_SYSTEM_ALIASES) printf "%s\n" "${MANTLE_ENABLE_SYSTEM_ALIASES:-}" ;;
	MANTLE_ENABLE_LEGACY_ALIASES) printf "%s\n" "${MANTLE_ENABLE_LEGACY_ALIASES:-}" ;;
	MANTLE_ENABLE_SAFETY_ALIASES) printf "%s\n" "${MANTLE_ENABLE_SAFETY_ALIASES:-}" ;;
	MANTLE_ENABLE_HISTORY) printf "%s\n" "${MANTLE_ENABLE_HISTORY:-}" ;;
	MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS) printf "%s\n" "${MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS:-}" ;;
	MANTLE_ENABLE_EXPERIMENTAL) printf "%s\n" "${MANTLE_ENABLE_EXPERIMENTAL:-}" ;;
	MANTLE_PRESENTATION_MODE) printf "%s\n" "${MANTLE_PRESENTATION_MODE:-}" ;;
	*) return 64 ;;
	esac

}

# @description Print one fixed effective policy value.
mantle_config_get_policy_value() {
	case "${1:-}" in
	ALIASES_SAFE) printf "%s\n" "${MANTLE_POLICY_ALIASES_SAFE}" ;;
	ALIASES_NETWORK) printf "%s\n" "${MANTLE_POLICY_ALIASES_NETWORK}" ;;
	ALIASES_SYSTEM) printf "%s\n" "${MANTLE_POLICY_ALIASES_SYSTEM}" ;;
	ALIASES_LEGACY) printf "%s\n" "${MANTLE_POLICY_ALIASES_LEGACY}" ;;
	ALIASES_SAFETY) printf "%s\n" "${MANTLE_POLICY_ALIASES_SAFETY}" ;;
	HISTORY) printf "%s\n" "${MANTLE_POLICY_HISTORY}" ;;
	SUPPRESS_UPDATE_CHECKS) printf "%s\n" "${MANTLE_POLICY_SUPPRESS_UPDATE_CHECKS}" ;;
	EXPERIMENTAL) printf "%s\n" "${MANTLE_POLICY_EXPERIMENTAL}" ;;
	PRESENTATION) printf "%s\n" "${MANTLE_POLICY_PRESENTATION}" ;;
	*) return 64 ;;
	esac
}

# @description Print the provenance of one effective policy value.
mantle_config_get_policy_source() {
	case "${1:-}" in
	ALIASES_SAFE) printf "%s\n" "${MANTLE_POLICY_SOURCE_ALIASES_SAFE}" ;;
	ALIASES_NETWORK) printf "%s\n" "${MANTLE_POLICY_SOURCE_ALIASES_NETWORK}" ;;
	ALIASES_SYSTEM) printf "%s\n" "${MANTLE_POLICY_SOURCE_ALIASES_SYSTEM}" ;;
	ALIASES_LEGACY) printf "%s\n" "${MANTLE_POLICY_SOURCE_ALIASES_LEGACY}" ;;
	ALIASES_SAFETY) printf "%s\n" "${MANTLE_POLICY_SOURCE_ALIASES_SAFETY}" ;;
	HISTORY) printf "%s\n" "${MANTLE_POLICY_SOURCE_HISTORY}" ;;
	SUPPRESS_UPDATE_CHECKS) printf "%s\n" "${MANTLE_POLICY_SOURCE_SUPPRESS_UPDATE_CHECKS}" ;;
	EXPERIMENTAL) printf "%s\n" "${MANTLE_POLICY_SOURCE_EXPERIMENTAL}" ;;
	PRESENTATION) printf "%s\n" "${MANTLE_POLICY_SOURCE_PRESENTATION}" ;;
	*) return 64 ;;
	esac
}

# @description Resolve profile defaults, literal configuration, and explicit environment overrides.
mantle_config_resolve() {
	local environment_profile=""
	local config_path=""
	local selected_profile="workstation"
	local setting_variable=""
	local environment_name=""
	local environment_value=""
	local normalized_value=""
	local config_value=""
	local setting_name=""
	local setting_type=""
	local _setting_metadata=""

	# A parent Mantle shell exports its resolved profile for diagnostics. Do not
	# reinterpret that derived value as a user override in child commands or a
	# repeated resolution; only an original/environment-sourced value overrides.
	case "${MANTLE_CONFIG_RESOLVED:-0}:${MANTLE_PROFILE_SOURCE:-}" in
	1:default | 1:config:*)
		if [[ -n "${MANTLE_PROFILE:-}" && "${MANTLE_PROFILE}" != "${MANTLE_PROFILE_RESOLVED_VALUE:-}" ]]; then
			environment_profile="${MANTLE_PROFILE}"
		fi
		;;
	*) environment_profile="${MANTLE_PROFILE:-}" ;;
	esac

	if [[ -n "${MANTLE_CONFIG_FILE:-}" ]]; then
		config_path="${MANTLE_CONFIG_FILE}"
	elif [[ "${XDG_CONFIG_HOME:-}" == /* ]]; then
		config_path="${XDG_CONFIG_HOME}/mantle/config.conf"
	elif [[ "${HOME:-}" == /* ]]; then
		config_path="${HOME:-}/.config/mantle/config.conf"
	else
		printf "[mantle:error] HOME must be absolute when no config path is set\n" >&2
		return 78
	fi
	if [[ "${config_path}" != /* ]]; then
		printf "[mantle:error] Mantle config path must be absolute\n" >&2
		return 78
	fi

	mantle_config_reset_parsed
	MANTLE_CONFIG_FILE_RESOLVED="${config_path}"
	MANTLE_CONFIG_FILE_STATUS="absent"
	if [[ -e "${config_path}" ]]; then
		mantle_config_read_file "${config_path}" || return $?
		MANTLE_CONFIG_FILE_STATUS="loaded"
	elif [[ -n "${MANTLE_CONFIG_FILE:-}" ]]; then
		printf "[mantle:error] configured Mantle config file is unavailable\n" >&2
		return 66
	fi

	# Validate a profile named by the file even when MANTLE_PROFILE will take
	# precedence. A higher-precedence override must not hide an invalid file.
	if [[ -n "${MANTLE_CONFIG_REQUESTED_PROFILE}" ]]; then
		case "${MANTLE_CONFIG_REQUESTED_PROFILE}" in
		core | interactive | workstation | container | ci | full) ;;
		*)
			printf "[mantle:error] configured profile must name an existing Mantle base profile\n" >&2
			return 78
			;;
		esac
	fi

	[[ -n "${MANTLE_CONFIG_REQUESTED_PROFILE}" ]] && selected_profile="${MANTLE_CONFIG_REQUESTED_PROFILE}"
	[[ -n "${environment_profile}" ]] && selected_profile="${environment_profile}"
	mantle_config_load_profile "${selected_profile}" || return $?
	MANTLE_PROFILE="${selected_profile}"
	MANTLE_PROFILE_SOURCE="default"
	[[ -n "${MANTLE_CONFIG_REQUESTED_PROFILE}" ]] && MANTLE_PROFILE_SOURCE="config:${config_path}"
	[[ -n "${environment_profile}" ]] && MANTLE_PROFILE_SOURCE="environment:MANTLE_PROFILE"

	for setting_variable in ALIASES_SAFE ALIASES_NETWORK ALIASES_SYSTEM ALIASES_LEGACY ALIASES_SAFETY HISTORY SUPPRESS_UPDATE_CHECKS EXPERIMENTAL PRESENTATION; do
		config_value="$(mantle_config_get_parsed_value "${setting_variable}")" || return 78
		mantle_config_apply_value "${setting_variable}" "${config_value}" "config:${config_path}"
	done

	while IFS=$'\t' read -r setting_name setting_type environment_name _setting_metadata; do
		[[ "${setting_name}" == "setting" ]] && continue
		setting_variable="$(mantle_config_setting_variable "${setting_name}")" || return 78
		environment_value="$(mantle_config_environment_value "${environment_name}")" || return 78
		[[ -n "${environment_value}" ]] || continue
		if [[ "${setting_type}" == "boolean" ]]; then
			normalized_value="$(mantle_config_boolean_normalize "${environment_value}")" || {
				printf "[mantle:error] %s must be a boolean value\n" "${environment_name}" >&2
				return 78
			}
			mantle_config_validate_setting "${setting_name}" "${normalized_value}" || return 78
		else
			normalized_value="${environment_value}"
			mantle_config_validate_setting "${setting_name}" "${normalized_value}" || {
				printf "[mantle:error] invalid %s value\n" "${environment_name}" >&2
				return 78
			}
		fi
		mantle_config_apply_value "${setting_variable}" "${normalized_value}" "environment:${environment_name}"
	done <"${MANTLE_ROOT}/config/settings.tsv"

	MANTLE_CONFIG_SCHEMA_VERSION="${MANTLE_CONFIG_SUPPORTED_SCHEMA_VERSION}"
	MANTLE_PROFILE_RESOLVED_VALUE="${MANTLE_PROFILE}"
	export MANTLE_CONFIG_SCHEMA_VERSION MANTLE_CONFIG_FILE_RESOLVED MANTLE_CONFIG_FILE_STATUS
	export MANTLE_PROFILE MANTLE_PROFILE_SOURCE MANTLE_PROFILE_RESOLVED_VALUE
	export MANTLE_POLICY_ALIASES_SAFE MANTLE_POLICY_ALIASES_NETWORK MANTLE_POLICY_ALIASES_SYSTEM
	export MANTLE_POLICY_ALIASES_LEGACY MANTLE_POLICY_ALIASES_SAFETY MANTLE_POLICY_HISTORY
	export MANTLE_POLICY_SUPPRESS_UPDATE_CHECKS MANTLE_POLICY_EXPERIMENTAL MANTLE_POLICY_PRESENTATION
	MANTLE_CONFIG_RESOLVED="1"
	export MANTLE_CONFIG_RESOLVED
}

# @description Print supported effective settings and their sources for diagnostics.
mantle_config_print_effective() {
	local requested_setting="${1:-}"
	local setting_name=""
	local setting_type=""
	local _environment_name=""
	local _allowed_values=""
	local applicability=""
	local _description=""
	local setting_variable=""
	local effective_value=""
	local effective_source=""

	printf "setting\ttype\tvalue\tsource\tapplicability\n"
	printf "profile\tprofile\t%s\t%s\tall\n" "${MANTLE_PROFILE}" "${MANTLE_PROFILE_SOURCE}"
	while IFS=$'\t' read -r setting_name setting_type _environment_name _allowed_values applicability _description; do
		[[ "${setting_name}" == "setting" ]] && continue
		[[ -n "${requested_setting}" && "${requested_setting}" != "${setting_name}" ]] && continue
		setting_variable="$(mantle_config_setting_variable "${setting_name}")" || return 78
		effective_value="$(mantle_config_get_policy_value "${setting_variable}")" || return 78
		effective_source="$(mantle_config_get_policy_source "${setting_variable}")" || return 78
		printf "%s\t%s\t%s\t%s\t%s\n" \
			"${setting_name}" "${setting_type}" "${effective_value}" "${effective_source}" "${applicability}"
	done <"${MANTLE_ROOT}/config/settings.tsv"
}

MANTLE_CONFIG_LIBRARY_LOADED="1"
return 0
