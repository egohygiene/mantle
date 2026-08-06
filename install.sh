#!/usr/bin/env bash
# shellcheck shell=bash
#
# Install Mantle into a user-owned prefix and optionally add shell hooks.

set -o errexit
set -o nounset
set -o pipefail

readonly MANTLE_INSTALLER_BLOCK_BEGIN="# >>> mantle >>>"
readonly MANTLE_INSTALLER_BLOCK_END="# <<< mantle <<<"
readonly MANTLE_INSTALLER_VERSION_FALLBACK="development"

MANTLE_SOURCE_ROOT="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)"
readonly MANTLE_SOURCE_ROOT

MANTLE_PAYLOAD_ITEMS=(
	".shellrc"
	"bin"
	"lib"
	"init"
	"modules"
	"platforms"
	"runtime"
	"assets"
)

MANTLE_SUPPORTED_SHELLS=(
	"bash"
	"zsh"
	"fish"
)

MANTLE_TEMP_PATHS=()
MANTLE_RESOLVED_SHELLS=()

MANTLE_MODE="install"
MANTLE_DRY_RUN="0"
MANTLE_PREFIX_INPUT=""
MANTLE_METHOD="copy"
MANTLE_SHELL_SELECTION="all"
MANTLE_MANAGE_SHELL_HOOKS="1"

# @description Print a formatted line to stderr.
# @arg $1 Message text.
log_stderr() {
	printf "%s\n" "$1" >&2
}

# @description Print an informational installer message to stderr.
# @arg $1 Message text.
log_info() {
	log_stderr "[mantle:info] $1"
}

# @description Print a warning installer message to stderr.
# @arg $1 Message text.
log_warn() {
	log_stderr "[mantle:warn] $1"
}

# @description Print an error installer message to stderr.
# @arg $1 Message text.
log_error() {
	log_stderr "[mantle:error] $1"
}

# @description Remove tracked temporary paths on exit or interrupt.
cleanup() {
	local temp_path=""

	for temp_path in "${MANTLE_TEMP_PATHS[@]:-}"; do
		if [[ -n "${temp_path}" && (-e "${temp_path}" || -L "${temp_path}") ]]; then
			rm -rf "${temp_path}"
		fi
	done
}

trap cleanup EXIT INT TERM

# @description Register a temporary path for automatic cleanup.
# @arg $1 Path to remove during cleanup.
register_temp_path() {
	local temp_path="${1:-}"

	if [[ -n "${temp_path}" ]]; then
		MANTLE_TEMP_PATHS+=("${temp_path}")
	fi
}

# @description Resolve the current Mantle version identifier.
# @stdout Version identifier.
resolve_version() {
	local resolved_version="${MANTLE_VERSION:-}"
	local version_file="${MANTLE_SOURCE_ROOT}/VERSION"

	if [[ -n "${resolved_version}" ]]; then
		printf "%s\n" "${resolved_version}"
		return 0
	fi

	if [[ -r "${version_file}" ]]; then
		IFS= read -r resolved_version <"${version_file}" || true
		if [[ -n "${resolved_version}" ]]; then
			printf "%s\n" "${resolved_version}"
			return 0
		fi
	fi

	if command -v git >/dev/null 2>&1 && [[ -e "${MANTLE_SOURCE_ROOT}/.git" ]]; then
		resolved_version="$(git -C "${MANTLE_SOURCE_ROOT}" describe --tags --always --dirty 2>/dev/null)" || true
		if [[ -n "${resolved_version}" ]]; then
			printf "%s\n" "${resolved_version}"
			return 0
		fi
	fi

	printf "%s\n" "${MANTLE_INSTALLER_VERSION_FALLBACK}"
}

# @description Print installer usage information.
print_help() {
	printf "%s\n" \
		"Usage: ./install.sh [OPTIONS]" \
		"" \
		"Install Mantle into a user-owned prefix and optionally activate shell hooks." \
		"" \
		"Options:" \
		"  --dry-run            Describe the planned installation without changing files." \
		"  --environment-diff   Show PATH and MANTLE_* changes from sourcing .shellrc." \
		"  --shell SHELL        Manage shell activation for bash, zsh, fish, or all." \
		"  --prefix PATH        Install into PATH instead of the default data prefix." \
		"  --method METHOD      Install using copy or symlink (default: copy)." \
		"  --no-shell-hook      Skip shell activation changes." \
		"  --status             Report installation and shell activation state." \
		"  --uninstall          Remove an installer-owned installation and shell hooks." \
		"  --help               Show this help text and exit." \
		"  --version            Show the installer version and exit."
}

# @description Print the installer version.
print_version() {
	printf "%s\n" "$(resolve_version)"
}

# @description Set the requested operating mode, rejecting conflicting mode flags.
# @arg $1 Requested mode.
set_mode() {
	local requested_mode="${1:-}"

	if [[ -z "${requested_mode}" ]]; then
		log_error "internal error: missing mode"
		exit 70
	fi

	if [[ "${MANTLE_MODE}" != "install" && "${MANTLE_MODE}" != "${requested_mode}" ]]; then
		log_error "conflicting mode options were provided"
		exit 64
	fi

	MANTLE_MODE="${requested_mode}"
}

# @description Parse installer CLI arguments.
# @arg $@ Installer arguments.
parse_args() {
	while (($# > 0)); do
		case "$1" in
		--dry-run)
			MANTLE_DRY_RUN="1"
			shift
			;;
		--environment-diff)
			set_mode "environment-diff"
			shift
			;;
		--shell)
			if (($# < 2)); then
				log_error "--shell requires a value"
				exit 64
			fi
			MANTLE_SHELL_SELECTION="$2"
			shift 2
			;;
		--prefix)
			if (($# < 2)); then
				log_error "--prefix requires a value"
				exit 64
			fi
			MANTLE_PREFIX_INPUT="$2"
			shift 2
			;;
		--method)
			if (($# < 2)); then
				log_error "--method requires a value"
				exit 64
			fi
			MANTLE_METHOD="$2"
			shift 2
			;;
		--no-shell-hook)
			MANTLE_MANAGE_SHELL_HOOKS="0"
			shift
			;;
		--status)
			set_mode "status"
			shift
			;;
		--uninstall)
			set_mode "uninstall"
			shift
			;;
		--help | -h)
			set_mode "help"
			shift
			;;
		--version)
			set_mode "version"
			shift
			;;
		*)
			log_error "unknown option: $1"
			exit 64
			;;
		esac
	done

	case "${MANTLE_SHELL_SELECTION}" in
	bash | zsh | fish | all) ;;
	*)
		log_error "invalid shell selection: ${MANTLE_SHELL_SELECTION}"
		exit 64
		;;
	esac

	case "${MANTLE_METHOD}" in
	copy | symlink) ;;
	*)
		log_error "invalid install method: ${MANTLE_METHOD}"
		exit 64
		;;
	esac

	if [[ "${MANTLE_MODE}" != "install" && "${MANTLE_DRY_RUN}" == "1" ]]; then
		log_error "--dry-run can only be used with installation mode"
		exit 64
	fi
}

# @description Require a non-empty absolute HOME path.
require_home() {
	if [[ -z "${HOME:-}" ]]; then
		log_error "HOME must be set"
		exit 64
	fi

	if [[ "${HOME}" != /* ]]; then
		log_error "HOME must be an absolute path"
		exit 64
	fi
}

# @description Resolve an existing directory to an absolute physical path.
# @arg $1 Directory path.
# @stdout Resolved absolute directory path.
resolve_existing_directory() {
	local directory_path="${1:-}"
	local remainder=""
	local segment=""

	if [[ -z "${directory_path}" ]]; then
		log_error "cannot resolve an empty directory path"
		exit 64
	fi

	if [[ "${directory_path}" != /* ]]; then
		directory_path="${PWD}/${directory_path}"
	fi

	while [[ "${directory_path}" != "/" && "${directory_path}" == */ ]]; do
		directory_path="${directory_path%/}"
	done

	while [[ ! -d "${directory_path}" ]]; do
		if [[ "${directory_path}" == "/" || "${directory_path}" == "." || "${directory_path}" == "" ]]; then
			log_error "unable to resolve directory path"
			exit 64
		fi

		segment="$(basename -- "${directory_path}")"
		if [[ -n "${remainder}" ]]; then
			remainder="${segment}/${remainder}"
		else
			remainder="${segment}"
		fi
		directory_path="$(dirname -- "${directory_path}")"
	done

	directory_path="$(
		cd -- "${directory_path}" &&
			pwd -P
	)"

	if [[ -n "${remainder}" ]]; then
		printf "%s/%s\n" "${directory_path}" "${remainder}"
	else
		printf "%s\n" "${directory_path}"
	fi
}

# @description Resolve a path to an absolute physical or canonical location.
# @arg $1 File or directory path.
# @stdout Resolved absolute path.
resolve_path() {
	local input_path="${1:-}"
	local parent_path=""
	local base_name=""

	if [[ -z "${input_path}" ]]; then
		log_error "cannot resolve an empty path"
		exit 64
	fi

	if [[ "${input_path}" == "/" ]]; then
		printf "/\n"
		return 0
	fi

	if [[ "${input_path}" != /* ]]; then
		input_path="${PWD}/${input_path}"
	fi

	while [[ "${input_path}" != "/" && "${input_path}" == */ ]]; do
		input_path="${input_path%/}"
	done

	if [[ -d "${input_path}" ]]; then
		input_path="$(
			cd -- "${input_path}" &&
				pwd -P
		)"
		printf "%s\n" "${input_path}"
		return 0
	fi

	parent_path="$(dirname -- "${input_path}")"
	base_name="$(basename -- "${input_path}")"
	parent_path="$(resolve_existing_directory "${parent_path}")"
	printf "%s/%s\n" "${parent_path}" "${base_name}"
}

# @description Print the default Mantle installation prefix.
# @stdout Default installation prefix.
default_prefix() {
	printf "%s/mantle\n" "${XDG_DATA_HOME:-${HOME}/.local/share}"
}

# @description Resolve and validate the requested installation prefix.
# @stdout Resolved installation prefix.
resolve_prefix() {
	local raw_prefix="${MANTLE_PREFIX_INPUT:-}"
	local resolved_prefix=""

	if [[ -z "${raw_prefix}" ]]; then
		raw_prefix="$(default_prefix)"
	fi

	resolved_prefix="$(resolve_path "${raw_prefix}")"

	if [[ "${resolved_prefix}" == "/" ]]; then
		log_error "the installation prefix cannot be /"
		exit 64
	fi

	if [[ "$(dirname -- "${resolved_prefix}")" == "/" ]]; then
		log_error "the installation prefix cannot be a top-level root directory"
		exit 64
	fi

	printf "%s\n" "${resolved_prefix}"
}

# @description Return the installer metadata path for a prefix.
# @arg $1 Installation prefix.
# @stdout Metadata file path.
metadata_path() {
	printf "%s/.mantle-installer\n" "$1"
}

# @description Determine whether a prefix is installer-owned.
# @arg $1 Installation prefix.
is_installer_owned_prefix() {
	local prefix_path="${1:-}"
	local metadata_file=""

	if [[ -z "${prefix_path}" ]]; then
		return 1
	fi

	metadata_file="$(metadata_path "${prefix_path}")"
	[[ -f "${metadata_file}" && -r "${metadata_file}" ]]
}

# @description Read a simple string field from the installer metadata JSON.
# @arg $1 Metadata file path.
# @arg $2 Field name.
# @stdout Field value if present.
metadata_value() {
	local metadata_file="${1:-}"
	local field_name="${2:-}"
	local metadata_line=""

	if [[ ! -r "${metadata_file}" || -z "${field_name}" ]]; then
		return 1
	fi

	metadata_line="$(grep -E "\"${field_name}\"[[:space:]]*:" "${metadata_file}" | head -n 1 || true)"
	if [[ -z "${metadata_line}" ]]; then
		return 1
	fi

	metadata_line="${metadata_line#*\""${field_name}"\": \"}"
	metadata_line="${metadata_line%%\"*}"
	printf "%s\n" "${metadata_line}"
}

# @description Escape a string for JSON string output.
# @arg $1 Raw string.
# @stdout JSON-escaped string.
json_escape() {
	local raw_string="${1:-}"

	raw_string="${raw_string//\\/\\\\}"
	raw_string="${raw_string//\"/\\\"}"
	raw_string="${raw_string//$'\n'/\\n}"
	raw_string="${raw_string//$'\r'/\\r}"
	raw_string="${raw_string//$'\t'/\\t}"
	printf "%s" "${raw_string}"
}

# @description Return the startup file path for a shell.
# @arg $1 Shell name.
# @stdout Startup file path.
shell_startup_path() {
	local shell_name="${1:-}"
	local platform_name=""

	case "${shell_name}" in
	bash)
		platform_name="$(uname -s)"
		case "${platform_name}" in
		Darwin)
			printf "%s/.bash_profile\n" "${HOME}"
			;;
		*)
			printf "%s/.bashrc\n" "${HOME}"
			;;
		esac
		;;
	zsh)
		printf "%s/.zshrc\n" "${HOME}"
		;;
	fish)
		printf "%s/fish/conf.d/mantle.fish\n" "${XDG_CONFIG_HOME:-${HOME}/.config}"
		;;
	*)
		log_error "unsupported shell for startup path: ${shell_name}"
		exit 64
		;;
	esac
}

# @description Report whether a shell is available on the current system.
# @arg $1 Shell name.
shell_is_available() {
	local shell_name="${1:-}"

	case "${shell_name}" in
	bash)
		return 0
		;;
	zsh | fish)
		command -v "${shell_name}" >/dev/null 2>&1
		;;
	*)
		return 1
		;;
	esac
}

# @description Populate the selected-shell list for installation.
resolve_shells_for_install() {
	local shell_name=""

	MANTLE_RESOLVED_SHELLS=()

	case "${MANTLE_SHELL_SELECTION}" in
	all)
		for shell_name in "${MANTLE_SUPPORTED_SHELLS[@]}"; do
			if shell_is_available "${shell_name}"; then
				MANTLE_RESOLVED_SHELLS+=("${shell_name}")
			fi
		done
		;;
	*)
		MANTLE_RESOLVED_SHELLS+=("${MANTLE_SHELL_SELECTION}")
		;;
	esac
}

# @description Populate the selected-shell list for uninstall.
resolve_shells_for_uninstall() {
	MANTLE_RESOLVED_SHELLS=()

	case "${MANTLE_SHELL_SELECTION}" in
	all)
		MANTLE_RESOLVED_SHELLS=("${MANTLE_SUPPORTED_SHELLS[@]}")
		;;
	*)
		MANTLE_RESOLVED_SHELLS+=("${MANTLE_SHELL_SELECTION}")
		;;
	esac
}

# @description Print the managed activation block for Bash or Zsh.
# @arg $1 Installation prefix.
print_managed_block() {
	local prefix_path="${1:-}"

	printf "%s\n" \
		"${MANTLE_INSTALLER_BLOCK_BEGIN}" \
		"# Managed by Mantle's installer." \
		"if [ -r \"${prefix_path}/.shellrc\" ]; then" \
		"  . \"${prefix_path}/.shellrc\"" \
		"fi" \
		"${MANTLE_INSTALLER_BLOCK_END}"
}

# @description Print the managed Fish activation file contents.
# @arg $1 Installation prefix.
print_fish_hook() {
	local prefix_path="${1:-}"

	printf "%s\n" \
		"# Managed by Mantle's installer." \
		"if test -r \"${prefix_path}/runtime/shells/fish/runtime.fish\"" \
		"    set -gx MANTLE_ROOT \"${prefix_path}\"" \
		"    source \"${prefix_path}/runtime/shells/fish/runtime.fish\"" \
		"end"
}

# @description Create a temporary path inside a target directory.
# @arg $1 Parent directory.
# @arg $2 Prefix label.
# @stdout Temporary path.
make_temp_path() {
	local parent_directory="${1:-}"
	local label="${2:-mantle}"
	local temp_path=""

	mkdir -p "${parent_directory}"
	temp_path="$(mktemp -d "${parent_directory}/.${label}.XXXXXXXXXX")"
	register_temp_path "${temp_path}"
	printf "%s\n" "${temp_path}"
}

# @description Remove any managed Mantle block from a startup file.
# @arg $1 Startup file path.
remove_managed_block() {
	local startup_file="${1:-}"
	local temp_file=""
	local temp_root=""

	if [[ ! -e "${startup_file}" ]]; then
		return 0
	fi

	temp_root="$(make_temp_path "$(dirname -- "${startup_file}")" "mantle-hook")"
	temp_file="${temp_root}/stripped"

	awk '
	BEGIN {
		skip = 0
	}
	$0 == "'"${MANTLE_INSTALLER_BLOCK_BEGIN}"'" {
		skip = 1
		next
	}
	$0 == "'"${MANTLE_INSTALLER_BLOCK_END}"'" {
		skip = 0
		next
	}
	skip == 0 {
		print
	}
	' "${startup_file}" >"${temp_file}"

	mv "${temp_file}" "${startup_file}"
}

# @description Ensure a file ends with a trailing newline.
# @arg $1 File path.
ensure_trailing_newline() {
	local file_path="${1:-}"
	local last_byte=""

	if [[ ! -s "${file_path}" ]]; then
		return 0
	fi

	last_byte="$(tail -c 1 "${file_path}" 2>/dev/null || true)"
	if [[ -n "${last_byte}" ]]; then
		printf "\n" >>"${file_path}"
	fi
}

# @description Remove trailing blank lines from a file.
# @arg $1 File path.
trim_trailing_blank_lines() {
	local file_path="${1:-}"
	local temp_file=""
	local temp_root=""

	if [[ ! -e "${file_path}" ]]; then
		return 0
	fi

	temp_root="$(make_temp_path "$(dirname -- "${file_path}")" "mantle-trim")"
	temp_file="${temp_root}/trimmed"

	awk '
	{
		lines[++count] = $0
		if ($0 ~ /[^[:space:]]/) {
			last_nonblank = count
		}
	}
	END {
		for (line_number = 1; line_number <= last_nonblank; line_number += 1) {
			print lines[line_number]
		}
	}
	' "${file_path}" >"${temp_file}"

	mv "${temp_file}" "${file_path}"
}

# @description Install or update the managed Bash or Zsh activation block.
# @arg $1 Shell name.
# @arg $2 Installation prefix.
install_block_hook() {
	local shell_name="${1:-}"
	local prefix_path="${2:-}"
	local startup_file=""

	startup_file="$(shell_startup_path "${shell_name}")"
	mkdir -p "$(dirname -- "${startup_file}")"
	if [[ ! -e "${startup_file}" ]]; then
		: >"${startup_file}"
	fi

	remove_managed_block "${startup_file}"
	trim_trailing_blank_lines "${startup_file}"
	ensure_trailing_newline "${startup_file}"

	if [[ -s "${startup_file}" ]]; then
		printf "\n" >>"${startup_file}"
	fi

	print_managed_block "${prefix_path}" >>"${startup_file}"
	printf "\n" >>"${startup_file}"
}

# @description Install or update the managed Fish activation file.
# @arg $1 Installation prefix.
install_fish_hook() {
	local prefix_path="${1:-}"
	local fish_file=""

	fish_file="$(shell_startup_path "fish")"
	mkdir -p "$(dirname -- "${fish_file}")"
	print_fish_hook "${prefix_path}" >"${fish_file}"
	printf "\n" >>"${fish_file}"
}

# @description Remove the managed activation hook for a shell.
# @arg $1 Shell name.
remove_shell_hook() {
	local shell_name="${1:-}"
	local startup_file=""

	startup_file="$(shell_startup_path "${shell_name}")"
	case "${shell_name}" in
	bash | zsh)
		if [[ -e "${startup_file}" ]]; then
			remove_managed_block "${startup_file}"
			trim_trailing_blank_lines "${startup_file}"
		fi
		;;
	fish)
		if [[ -e "${startup_file}" ]]; then
			rm -f "${startup_file}"
		fi
		;;
	*)
		log_error "unsupported shell for hook removal: ${shell_name}"
		exit 64
		;;
	esac
}

# @description Report whether a shell hook currently points at the prefix.
# @arg $1 Shell name.
# @arg $2 Installation prefix.
# @stdout yes or no.
shell_hook_state() {
	local shell_name="${1:-}"
	local prefix_path="${2:-}"
	local startup_file=""
	local expected_path=""

	startup_file="$(shell_startup_path "${shell_name}")"
	if [[ ! -r "${startup_file}" ]]; then
		printf "no\n"
		return 0
	fi

	case "${shell_name}" in
	bash | zsh)
		expected_path="${prefix_path}/.shellrc"
		if grep -Fq "${MANTLE_INSTALLER_BLOCK_BEGIN}" "${startup_file}" &&
			grep -Fq "${expected_path}" "${startup_file}"; then
			printf "yes\n"
		else
			printf "no\n"
		fi
		;;
	fish)
		expected_path="${prefix_path}/runtime/shells/fish/runtime.fish"
		if grep -Fq "# Managed by Mantle's installer." "${startup_file}" &&
			grep -Fq "${expected_path}" "${startup_file}"; then
			printf "yes\n"
		else
			printf "no\n"
		fi
		;;
	*)
		printf "no\n"
		;;
	esac
}

# @description Validate that an existing prefix may be replaced.
# @arg $1 Installation prefix.
validate_destination_ownership() {
	local prefix_path="${1:-}"

	if [[ -z "${prefix_path}" ]]; then
		log_error "internal error: missing prefix for ownership validation"
		exit 70
	fi

	if [[ -e "${prefix_path}" || -L "${prefix_path}" ]]; then
		if ! is_installer_owned_prefix "${prefix_path}"; then
			log_error "refusing to overwrite a non-installer-owned destination: ${prefix_path}"
			exit 73
		fi
	fi
}

# @description Create a staged Mantle installation.
# @arg $1 Installation prefix.
# @arg $2 Install method.
# @stdout Staged installation directory.
stage_installation() {
	local prefix_path="${1:-}"
	local method_name="${2:-}"
	local prefix_parent=""
	local staging_root=""
	local staged_prefix=""
	local payload_item=""
	local item_source=""
	local metadata_file=""
	local installed_at=""

	prefix_parent="$(dirname -- "${prefix_path}")"
	staging_root="$(make_temp_path "${prefix_parent}" "mantle-install")"
	staged_prefix="${staging_root}/install-root"
	mkdir -p "${staged_prefix}"

	for payload_item in "${MANTLE_PAYLOAD_ITEMS[@]}"; do
		item_source="${MANTLE_SOURCE_ROOT}/${payload_item}"
		if [[ ! -e "${item_source}" ]]; then
			log_error "missing runtime payload: ${item_source}"
			exit 66
		fi

		case "${method_name}" in
		copy)
			cp -R "${item_source}" "${staged_prefix}/${payload_item}"
			;;
		symlink)
			ln -s "${item_source}" "${staged_prefix}/${payload_item}"
			;;
		*)
			log_error "unsupported install method: ${method_name}"
			exit 64
			;;
		esac
	done

	metadata_file="$(metadata_path "${staged_prefix}")"
	installed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
	printf "%s\n" \
		"{" \
		"  \"version\": \"$(json_escape "$(resolve_version)")\"," \
		"  \"method\": \"$(json_escape "${method_name}")\"," \
		"  \"source\": \"$(json_escape "${MANTLE_SOURCE_ROOT}")\"," \
		"  \"installed_at\": \"$(json_escape "${installed_at}")\"" \
		"}" >"${metadata_file}"

	printf "%s\n" "${staged_prefix}"
}

# @description Publish a staged installation atomically, restoring any backup on failure.
# @arg $1 Staged installation directory.
# @arg $2 Destination prefix.
publish_installation() {
	local staged_prefix="${1:-}"
	local prefix_path="${2:-}"
	local backup_path=""

	if [[ -e "${prefix_path}" || -L "${prefix_path}" ]]; then
		backup_path="${prefix_path}.previous.$$"
		rm -rf "${backup_path}"
		mv "${prefix_path}" "${backup_path}"
		register_temp_path "${backup_path}"
	fi

	if mv "${staged_prefix}" "${prefix_path}"; then
		if [[ -n "${backup_path}" ]]; then
			rm -rf "${backup_path}"
		fi
		return 0
	fi

	if [[ -e "${prefix_path}" || -L "${prefix_path}" ]]; then
		rm -rf "${prefix_path}"
	fi

	if [[ -n "${backup_path}" && (-e "${backup_path}" || -L "${backup_path}") ]]; then
		mv "${backup_path}" "${prefix_path}"
	fi

	return 1
}

# @description Apply shell activation hooks for the selected shells.
# @arg $1 Installation prefix.
install_shell_hooks() {
	local prefix_path="${1:-}"
	local shell_name=""

	resolve_shells_for_install

	if ((${#MANTLE_RESOLVED_SHELLS[@]} == 0)); then
		log_warn "no available shells were selected for activation"
		return 0
	fi

	for shell_name in "${MANTLE_RESOLVED_SHELLS[@]}"; do
		case "${shell_name}" in
		bash | zsh)
			log_info "updating ${shell_name} startup hook"
			install_block_hook "${shell_name}" "${prefix_path}"
			;;
		fish)
			log_info "updating fish startup hook"
			install_fish_hook "${prefix_path}"
			;;
		esac
	done
}

# @description Remove shell activation hooks for the selected shells.
remove_selected_shell_hooks() {
	local shell_name=""

	resolve_shells_for_uninstall

	for shell_name in "${MANTLE_RESOLVED_SHELLS[@]}"; do
		log_info "removing ${shell_name} startup hook"
		remove_shell_hook "${shell_name}"
	done
}

# @description Print the planned installation actions without mutating the filesystem.
# @arg $1 Installation prefix.
run_dry_run() {
	local prefix_path="${1:-}"
	local shell_name=""
	local action_word="${MANTLE_METHOD}"

	validate_destination_ownership "${prefix_path}"
	resolve_shells_for_install

	printf "%s\n" "mode: dry-run"
	printf "%s\n" "source: ${MANTLE_SOURCE_ROOT}"
	printf "%s\n" "prefix: ${prefix_path}"
	printf "%s\n" "method: ${MANTLE_METHOD}"
	printf "%s\n" "metadata: $(metadata_path "${prefix_path}")"
	printf "%s\n" "payload:"
	for shell_name in "${MANTLE_PAYLOAD_ITEMS[@]}"; do
		printf "%s\n" "  - ${shell_name}"
	done

	printf "%s\n" "publish: ${action_word} runtime payload into ${prefix_path}"

	if [[ "${MANTLE_MANAGE_SHELL_HOOKS}" == "1" ]]; then
		printf "%s\n" "shell-hooks:"
		if ((${#MANTLE_RESOLVED_SHELLS[@]} == 0)); then
			printf "%s\n" "  - none (no available shells)"
		else
			for shell_name in "${MANTLE_RESOLVED_SHELLS[@]}"; do
				printf "%s\n" "  - ${shell_name}: $(shell_startup_path "${shell_name}")"
			done
		fi
	else
		printf "%s\n" "shell-hooks: skipped"
	fi
}

# @description Install Mantle into the resolved prefix.
# @arg $1 Installation prefix.
run_install() {
	local prefix_path="${1:-}"
	local staged_prefix=""

	validate_destination_ownership "${prefix_path}"
	log_info "staging Mantle payload with method=${MANTLE_METHOD}"
	staged_prefix="$(stage_installation "${prefix_path}" "${MANTLE_METHOD}")"

	log_info "publishing Mantle to ${prefix_path}"
	if ! publish_installation "${staged_prefix}" "${prefix_path}"; then
		log_error "failed to publish the staged installation"
		exit 1
	fi

	if [[ "${MANTLE_MANAGE_SHELL_HOOKS}" == "1" ]]; then
		install_shell_hooks "${prefix_path}"
	else
		log_info "skipping shell hook installation"
	fi

	log_info "installation complete"
}

# @description Report installation ownership and activation state.
# @arg $1 Installation prefix.
run_status() {
	local prefix_path="${1:-}"
	local installed_state="no"
	local ownership_state="absent"
	local metadata_file=""
	local shell_name=""
	local hook_state=""
	local availability_state=""
	local version_value=""
	local method_value=""
	local source_value=""

	if [[ -e "${prefix_path}" || -L "${prefix_path}" ]]; then
		if is_installer_owned_prefix "${prefix_path}"; then
			installed_state="yes"
			ownership_state="installer-owned"
		else
			ownership_state="unmanaged"
		fi
	fi

	printf "%s\n" "prefix: ${prefix_path}"
	printf "%s\n" "installed: ${installed_state}"
	printf "%s\n" "ownership: ${ownership_state}"

	if [[ "${installed_state}" == "yes" ]]; then
		metadata_file="$(metadata_path "${prefix_path}")"
		version_value="$(metadata_value "${metadata_file}" "version" || true)"
		method_value="$(metadata_value "${metadata_file}" "method" || true)"
		source_value="$(metadata_value "${metadata_file}" "source" || true)"
		printf "%s\n" "version: ${version_value:-unknown}"
		printf "%s\n" "method: ${method_value:-unknown}"
		printf "%s\n" "source: ${source_value:-unknown}"
	fi

	for shell_name in "${MANTLE_SUPPORTED_SHELLS[@]}"; do
		if shell_is_available "${shell_name}"; then
			availability_state="yes"
		else
			availability_state="no"
		fi
		hook_state="$(shell_hook_state "${shell_name}" "${prefix_path}")"
		printf "%s\n" "${shell_name}: available=${availability_state} hook=${hook_state} file=$(shell_startup_path "${shell_name}")"
	done
}

# @description Remove an installer-owned Mantle installation and managed hooks.
# @arg $1 Installation prefix.
run_uninstall() {
	local prefix_path="${1:-}"

	if [[ -e "${prefix_path}" || -L "${prefix_path}" ]]; then
		if ! is_installer_owned_prefix "${prefix_path}"; then
			log_error "refusing to remove a non-installer-owned destination: ${prefix_path}"
			exit 73
		fi

		log_info "removing ${prefix_path}"
		rm -rf "${prefix_path}"
	else
		log_info "prefix is not installed: ${prefix_path}"
	fi

	if [[ "${MANTLE_MANAGE_SHELL_HOOKS}" == "1" ]]; then
		remove_selected_shell_hooks
	fi
}

# @description Capture PATH and MANTLE_* variables from a Bash process.
# @arg $1 Entry point to source, or empty to capture the current child environment only.
# @stdout Selected environment variable assignments.
capture_environment() {
	local entrypoint_path="${1:-}"

	CHILD_ENTRYPOINT="${entrypoint_path}" bash --noprofile --norc <<'EOF'
set -o errexit
set -o nounset
set -o pipefail

print_selected_environment() {
	local variable_name=""

	printf "PATH=%s\n" "${PATH:-}"
	while IFS= read -r variable_name; do
		printf "%s=%s\n" "${variable_name}" "${!variable_name}"
	done < <(compgen -v MANTLE_ | LC_ALL=C sort)
}

if [[ -n "${CHILD_ENTRYPOINT}" ]]; then
	# shellcheck disable=SC1090
	source "${CHILD_ENTRYPOINT}"
fi

print_selected_environment
EOF
}

# @description Show the environment changes caused by sourcing Mantle's Bash entrypoint.
# @arg $1 Installation prefix.
run_environment_diff() {
	local prefix_path="${1:-}"
	local entrypoint_path="${MANTLE_SOURCE_ROOT}/.shellrc"
	local diff_status=0

	if [[ -r "${prefix_path}/.shellrc" ]]; then
		entrypoint_path="${prefix_path}/.shellrc"
	fi

	log_info "capturing environment diff using ${entrypoint_path}"
	set +o errexit
	diff -u \
		--label before \
		--label after \
		<(capture_environment "") \
		<(capture_environment "${entrypoint_path}")
	diff_status=$?
	set -o errexit

	case "${diff_status}" in
	0)
		printf "%s\n" "No environment changes."
		;;
	1) ;;
	*)
		log_error "failed to compute the environment diff"
		exit "${diff_status}"
		;;
	esac
}

# @description Run the installer in the requested mode.
main() {
	local prefix_path=""

	parse_args "$@"

	case "${MANTLE_MODE}" in
	help)
		print_help
		return 0
		;;
	version)
		print_version
		return 0
		;;
	esac

	require_home
	prefix_path="$(resolve_prefix)"

	case "${MANTLE_MODE}" in
	install)
		if [[ "${MANTLE_DRY_RUN}" == "1" ]]; then
			run_dry_run "${prefix_path}"
		else
			run_install "${prefix_path}"
		fi
		;;
	status)
		run_status "${prefix_path}"
		;;
	uninstall)
		run_uninstall "${prefix_path}"
		;;
	environment-diff)
		run_environment_diff "${prefix_path}"
		;;
	*)
		log_error "unsupported mode: ${MANTLE_MODE}"
		exit 64
		;;
	esac
}

main "$@"
