#!/usr/bin/env bash
# shellcheck shell=bash
#
# Install versioned executables from GitHub Releases using declarative metadata.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/github.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INSTALL_GITHUB_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Confirm that MANTLE_INSTALL_VERIFY_ARGUMENTS is an indexed Bash array.
# @exitcode 0 The variable exists and is indexed.
# @exitcode 1 The variable is absent or has another type.
__mantle_install_github_copy_verify_arguments() {
	local declaration=""

	declaration="$(declare -p MANTLE_INSTALL_VERIFY_ARGUMENTS 2>/dev/null)" || return 1
	[[ "${declaration}" =~ ^declare\ -[[:alpha:]]*a[[:alpha:]]*\ MANTLE_INSTALL_VERIFY_ARGUMENTS= ]]
}

# @description Locate exactly one executable with the requested name in an extracted release.
# @arg $1 string Extracted release directory.
# @arg $2 string Expected executable filename.
# @stdout Absolute or caller-relative path to the matched executable.
# @exitcode 1 The archive contains zero or multiple matching files.
__mantle_install_github_find_binary() {
	local extracted_directory="${1:-}"
	local destination_name="${2:-}"
	local candidate_path=""
	local -a candidate_paths=()

	while IFS= read -r candidate_path; do
		candidate_paths+=("${candidate_path}")
	done < <(find "${extracted_directory}" -type f -name "${destination_name}" -print 2>/dev/null)

	if ((${#candidate_paths[@]} != 1)); then
		mantle_log_error "Expected exactly one ${destination_name} executable in the release archive; found ${#candidate_paths[@]}"
		return 1
	fi

	printf "%s\n" "${candidate_paths[0]}"
}

# @description Download, verify, extract, and atomically install one resolved GitHub release asset.
# @arg $1 string Resolved version without the tag prefix.
# @arg $2 string Resolved platform identifier.
# @arg $3 string Resolved architecture identifier.
# @arg $4 string Complete release tag.
# @arg $5 string Release asset filename.
# @arg $6 string Release asset URL.
# @arg $7 string Destination directory.
# @arg $8 string Destination executable filename.
# @arg $9 string Archive format or raw.
# @arg $10 string Optional archive member path.
# @arg $11 string Optional checksum asset filename.
# @arg $12 string Whether checksum verification was explicitly disabled.
__mantle_install_github_execute() (
	local version="${1}"
	local platform="${2}"
	local architecture="${3}"
	local tag="${4}"
	local asset="${5}"
	local asset_url="${6}"
	local target_directory="${7}"
	local destination_name="${8}"
	local archive_format="${9}"
	local archive_member="${10}"
	local checksum_asset="${11}"
	local skip_verification="${12}"
	local temporary_directory=""
	local artifact_path=""
	local extraction_directory=""
	local source_path=""
	local expected_checksum=""
	local install_path=""
	local verify_declaration=""
	local -a verify_arguments=()

	temporary_directory="$(mantle_install_filesystem_make_temporary_directory)" || return $?
	trap 'mantle_install_filesystem_cleanup "${temporary_directory:-}" >/dev/null 2>&1 || true' EXIT
	trap 'exit 129' HUP
	trap 'exit 130' INT
	trap 'exit 143' TERM

	artifact_path="${temporary_directory}/${asset}"
	extraction_directory="${temporary_directory}/extract"

	mantle_log_info "Downloading ${MANTLE_INSTALL_TOOL_NAME} ${version} (${platform}/${architecture})"
	mantle_install_download_file "${asset_url}" "${artifact_path}" || return $?
	if [[ ! -s "${artifact_path}" ]]; then
		mantle_log_error "Downloaded release asset is empty: ${asset}"
		return 1
	fi

	if [[ "${skip_verification}" == "1" ]]; then
		mantle_log_warn "Checksum verification was explicitly disabled"
	elif [[ -n "${checksum_asset}" ]]; then
		expected_checksum="$(
			mantle_install_github_checksum_from_release \
				"${MANTLE_INSTALL_GITHUB_OWNER}" \
				"${MANTLE_INSTALL_GITHUB_REPOSITORY}" \
				"${tag}" \
				"${checksum_asset}" \
				"${asset}"
		)" || {
			mantle_log_error "Unable to resolve a checksum for ${asset}"
			return 1
		}
		mantle_install_checksum_verify \
			"${MANTLE_INSTALL_CHECKSUM_ALGORITHM:-sha256}" \
			"${artifact_path}" \
			"${expected_checksum}" || return $?
	else
		mantle_log_warn "No checksum asset is configured for ${MANTLE_INSTALL_TOOL_NAME}"
	fi

	if [[ "${archive_format}" == "raw" ]]; then
		source_path="${artifact_path}"
	else
		mantle_install_archive_extract \
			"${artifact_path}" \
			"${extraction_directory}" \
			"${archive_member}" \
			"${archive_format}" || return $?

		if [[ -n "${archive_member}" ]]; then
			source_path="${extraction_directory}/${archive_member#./}"
		else
			source_path="$(__mantle_install_github_find_binary "${extraction_directory}" "${destination_name}")" || return $?
		fi
	fi

	if [[ ! -f "${source_path}" || ! -r "${source_path}" ]]; then
		mantle_log_error "Expected installable executable was not found: ${source_path}"
		return 1
	fi

	verify_declaration="$(declare -p MANTLE_INSTALL_VERIFY_ARGUMENTS 2>/dev/null)" || true
	if [[ -n "${verify_declaration}" ]]; then
		if ! __mantle_install_github_copy_verify_arguments; then
			mantle_log_error "MANTLE_INSTALL_VERIFY_ARGUMENTS must be an indexed array"
			return 64
		fi
		verify_arguments=("${MANTLE_INSTALL_VERIFY_ARGUMENTS[@]}")
	fi

	if ((${#verify_arguments[@]} > 0)); then
		chmod 0755 "${source_path}" || return 1
		if ! "${source_path}" "${verify_arguments[@]}"; then
			mantle_log_error "Pre-install verification failed for ${MANTLE_INSTALL_TOOL_NAME}"
			return 1
		fi
	fi

	install_path="$(
		mantle_install_filesystem_install_executable \
			"${source_path}" \
			"${target_directory}" \
			"${destination_name}"
	)" || return $?

	mantle_log_success "Installed ${MANTLE_INSTALL_TOOL_NAME} ${version} to ${install_path}"
)

# @description Render supported placeholders in an installer metadata template.
# @arg $1 string Template containing version, platform, arch, asset, or tag placeholders.
# @arg $2 string Optional version value.
# @arg $3 string Optional platform value.
# @arg $4 string Optional architecture value.
# @arg $5 string Optional asset value.
# @arg $6 string Optional tag value.
# @stdout Rendered template.
# @exitcode 64 Too many arguments were supplied.
mantle_install_template_render() {
	local template="${1:-}"
	local version="${2:-}"
	local platform="${3:-}"
	local architecture="${4:-}"
	local asset="${5:-}"
	local tag="${6:-}"

	if (($# < 1 || $# > 6)); then
		return 64
	fi

	template="${template//\{\{version\}\}/${version}}"
	template="${template//\{\{platform\}\}/${platform}}"
	template="${template//\{\{arch\}\}/${architecture}}"
	template="${template//\{\{asset\}\}/${asset}}"
	template="${template//\{\{tag\}\}/${tag}}"

	printf "%s\n" "${template}"
}

# @description Construct a GitHub Releases asset URL.
# @arg $1 string Repository owner.
# @arg $2 string Repository name.
# @arg $3 string Release tag.
# @arg $4 string Release asset filename.
# @stdout GitHub release asset URL.
# @exitcode 64 Usage is invalid.
mantle_install_github_release_asset_url() {
	local owner="${1:-}"
	local repository="${2:-}"
	local tag="${3:-}"
	local asset="${4:-}"

	if (($# != 4)) || [[ ! "${owner}" =~ ^[A-Za-z0-9_.-]+$ ]] ||
		[[ ! "${repository}" =~ ^[A-Za-z0-9_.-]+$ ]] || [[ ! "${tag}" =~ ^[A-Za-z0-9._+@-]+$ ]] ||
		[[ ! "${asset}" =~ ^[A-Za-z0-9._+@-]+$ ]]; then
		return 64
	fi

	printf "https://github.com/%s/%s/releases/download/%s/%s\n" \
		"${owner}" \
		"${repository}" \
		"${tag}" \
		"${asset}"
}

# @description Resolve the latest non-draft GitHub release tag through the API.
# @arg $1 string Repository owner.
# @arg $2 string Repository name.
# @stdout Latest release tag.
# @exitcode 69 Neither jq nor Python 3 is available to parse JSON safely.
mantle_install_github_latest_tag() {
	local owner="${1:-}"
	local repository="${2:-}"
	local temporary_directory=""
	local metadata_path=""
	local latest_tag=""
	local github_token="${MANTLE_INSTALL_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}"
	local -a request_headers=(
		"Accept: application/vnd.github+json"
		"X-GitHub-Api-Version: 2022-11-28"
		"User-Agent: mantle-installer"
	)

	if (($# != 2)) || [[ ! "${owner}" =~ ^[A-Za-z0-9_.-]+$ ]] ||
		[[ ! "${repository}" =~ ^[A-Za-z0-9_.-]+$ ]]; then
		return 64
	fi
	if [[ -n "${github_token}" ]]; then
		request_headers+=("Authorization: Bearer ${github_token}")
	fi

	temporary_directory="$(mantle_install_filesystem_make_temporary_directory)" || return $?
	metadata_path="${temporary_directory}/release.json"
	if ! mantle_install_download_file \
		"https://api.github.com/repos/${owner}/${repository}/releases/latest" \
		"${metadata_path}" \
		"${request_headers[@]}"; then
		mantle_install_filesystem_cleanup "${temporary_directory}" || true
		return 1
	fi

	if mantle_guard_has_command jq; then
		latest_tag="$(jq --exit-status --raw-output '.tag_name | select(type == "string" and length > 0)' "${metadata_path}")" || true
	elif mantle_guard_has_command python3; then
		latest_tag="$(python3 -c 'import json, sys; value = json.load(open(sys.argv[1], encoding="utf-8")).get("tag_name"); print(value if isinstance(value, str) else "")' "${metadata_path}")" || true
	else
		mantle_log_error "Resolving GitHub release metadata requires jq or Python 3"
		mantle_install_filesystem_cleanup "${temporary_directory}" || true
		return 69
	fi

	mantle_install_filesystem_cleanup "${temporary_directory}" || true
	if [[ -z "${latest_tag}" || "${latest_tag}" == "null" ]]; then
		mantle_log_error "Unable to resolve the latest release for ${owner}/${repository}"
		return 1
	fi

	printf "%s\n" "${latest_tag}"
}

# @description Resolve an explicit or latest GitHub release version.
# @arg $1 string Repository owner.
# @arg $2 string Repository name.
# @arg $3 string Optional requested version.
# @arg $4 string Optional tag prefix to strip, default v.
# @stdout Normalized version without the configured prefix.
mantle_install_github_resolve_version() {
	local owner="${1:-}"
	local repository="${2:-}"
	local requested_version="${3:-}"
	local strip_prefix="${4:-v}"
	local resolved_version=""

	if (($# < 2 || $# > 4)); then
		return 64
	fi
	if [[ -n "${requested_version}" ]]; then
		resolved_version="${requested_version}"
	else
		resolved_version="$(mantle_install_github_latest_tag "${owner}" "${repository}")" || return $?
	fi

	if [[ -n "${strip_prefix}" && "${resolved_version}" == "${strip_prefix}"* ]]; then
		resolved_version="${resolved_version#"${strip_prefix}"}"
	fi
	if [[ -z "${resolved_version}" ]]; then
		return 1
	fi

	printf "%s\n" "${resolved_version}"
}

# @description Read a target asset's digest from a GitHub release checksum asset.
# @arg $1 string Repository owner.
# @arg $2 string Repository name.
# @arg $3 string Release tag.
# @arg $4 string Checksum asset filename.
# @arg $5 string Target release asset filename.
# @stdout Matching hexadecimal checksum.
# @exitcode 1 The checksum asset is unavailable or contains no matching entry.
mantle_install_github_checksum_from_release() {
	local owner="${1:-}"
	local repository="${2:-}"
	local tag="${3:-}"
	local checksum_asset="${4:-}"
	local target_asset="${5:-}"
	local checksum_url=""
	local temporary_directory=""
	local checksum_path=""
	local expected_checksum=""

	if (($# != 5)); then
		return 64
	fi
	checksum_url="$(mantle_install_github_release_asset_url "${owner}" "${repository}" "${tag}" "${checksum_asset}")" || return $?
	temporary_directory="$(mantle_install_filesystem_make_temporary_directory)" || return $?
	checksum_path="${temporary_directory}/checksums.txt"

	if ! mantle_install_download_file "${checksum_url}" "${checksum_path}"; then
		mantle_install_filesystem_cleanup "${temporary_directory}" || true
		return 1
	fi

	expected_checksum="$(
		awk -v target="${target_asset}" '
			{
				candidate = $2
				sub(/^\*/, "", candidate)
				sub(/^\.\//, "", candidate)
				if ($1 ~ /^[[:xdigit:]]+$/ && candidate == target) {
					found = 1
					print $1
					exit
				}
				if ($2 == "(" target ")" && $3 == "=" && $4 ~ /^[[:xdigit:]]+$/) {
					found = 1
					print $4
					exit
				}
				if (NF == 1 && $1 ~ /^[[:xdigit:]]+$/) {
					fallback = $1
					fallback_count++
				}
			}
			END {
				if (!found && fallback_count == 1) {
					print fallback
				}
			}
		' "${checksum_path}"
	)"
	mantle_install_filesystem_cleanup "${temporary_directory}" || true

	if [[ -z "${expected_checksum}" ]]; then
		return 1
	fi
	printf "%s\n" "${expected_checksum}"
}

# @description Print the shared GitHub-release installer command usage.
mantle_install_github_usage() {
	local tool_name="${MANTLE_INSTALLER_NAME:-${MANTLE_INSTALL_TOOL_NAME:-TOOL}}"

	printf "Usage: mantle install %s [--version VERSION] [--install-dir DIRECTORY] [--dry-run] [--no-verify] [--help]\n" "${tool_name}"
}

# @description Validate required declarative GitHub installer metadata.
# @exitcode 1 Required metadata is missing.
mantle_install_github_assert_configuration() {
	local variable_name=""
	local -a required_variables=(
		"MANTLE_INSTALL_TOOL_NAME"
		"MANTLE_INSTALL_GITHUB_OWNER"
		"MANTLE_INSTALL_GITHUB_REPOSITORY"
		"MANTLE_INSTALL_ASSET_TEMPLATE"
	)

	for variable_name in "${required_variables[@]}"; do
		if [[ -z "${!variable_name:-}" ]]; then
			mantle_log_error "Missing installer configuration: ${variable_name}"
			return 1
		fi
	done

	if [[ ! "${MANTLE_INSTALL_TOOL_NAME}" =~ ^[A-Za-z0-9._+-]+$ ]] ||
		[[ ! "${MANTLE_INSTALL_GITHUB_OWNER}" =~ ^[A-Za-z0-9_.-]+$ ]] ||
		[[ ! "${MANTLE_INSTALL_GITHUB_REPOSITORY}" =~ ^[A-Za-z0-9_.-]+$ ]]; then
		mantle_log_error "Installer metadata contains an invalid tool or repository identifier"
		return 64
	fi
}

# @description Execute a declarative GitHub Releases installer wrapper.
# @arg $@ string Shared installer command-line arguments.
mantle_install_github_main() {
	local requested_version="${MANTLE_INSTALL_VERSION:-}"
	local target_directory="${MANTLE_INSTALL_DIRECTORY:-}"
	local dry_run="0"
	local skip_verification="0"
	local version=""
	local platform=""
	local architecture=""
	local tag=""
	local tag_template="${MANTLE_INSTALL_TAG_TEMPLATE:-}"
	local asset=""
	local asset_url=""
	local archive_format=""
	local archive_member=""
	local checksum_asset=""
	local destination_name=""

	mantle_install_github_assert_configuration || return $?

	if [[ -z "${target_directory}" ]]; then
		if [[ -n "${XDG_BIN_HOME:-}" ]]; then
			target_directory="${XDG_BIN_HOME}"
		elif [[ -n "${HOME:-}" ]]; then
			target_directory="${HOME}/.local/bin"
		else
			target_directory="/usr/local/bin"
		fi
	fi

	while (($# > 0)); do
		case "$1" in
		--version)
			if (($# < 2)) || [[ -z "${2:-}" ]]; then
				mantle_log_error "--version requires a value"
				return 64
			fi
			requested_version="$2"
			shift 2
			;;
		--install-dir)
			if (($# < 2)) || [[ -z "${2:-}" ]]; then
				mantle_log_error "--install-dir requires a directory"
				return 64
			fi
			target_directory="$2"
			shift 2
			;;
		--dry-run)
			dry_run="1"
			shift
			;;
		--no-verify)
			skip_verification="1"
			shift
			;;
		--help | -h)
			mantle_install_github_usage
			return 0
			;;
		--)
			shift
			if (($# > 0)); then
				mantle_log_error "Positional arguments are not supported"
				return 64
			fi
			;;
		*)
			mantle_log_error "Unknown argument: $1"
			mantle_install_github_usage >&2
			return 64
			;;
		esac
	done

	version="$(
		mantle_install_github_resolve_version \
			"${MANTLE_INSTALL_GITHUB_OWNER}" \
			"${MANTLE_INSTALL_GITHUB_REPOSITORY}" \
			"${requested_version}" \
			"${MANTLE_INSTALL_VERSION_PREFIX_TO_STRIP:-v}"
	)" || return $?
	platform="$(
		mantle_install_platform_map_family \
			"${MANTLE_INSTALL_PLATFORM_LINUX:-linux}" \
			"${MANTLE_INSTALL_PLATFORM_DARWIN:-darwin}" \
			"${MANTLE_INSTALL_PLATFORM_WINDOWS:-windows}"
	)" || return $?
	architecture="$(
		mantle_install_platform_map_architecture \
			"${MANTLE_INSTALL_ARCH_X86_64:-amd64}" \
			"${MANTLE_INSTALL_ARCH_ARM64:-arm64}" \
			"${MANTLE_INSTALL_ARCH_ARMV7:-armv7}" \
			"${MANTLE_INSTALL_ARCH_ARMV6:-armv6}" \
			"${MANTLE_INSTALL_ARCH_X86:-386}" \
			"${MANTLE_INSTALL_ARCH_PPC64LE:-ppc64le}" \
			"${MANTLE_INSTALL_ARCH_RISCV64:-riscv64}" \
			"${MANTLE_INSTALL_ARCH_S390X:-s390x}"
	)" || return $?

	if [[ -z "${tag_template}" ]]; then
		tag_template='v{{version}}'
	fi
	tag="$(
		mantle_install_template_render \
			"${tag_template}" \
			"${version}" \
			"${platform}" \
			"${architecture}"
	)" || return $?
	asset="$(
		mantle_install_template_render \
			"${MANTLE_INSTALL_ASSET_TEMPLATE}" \
			"${version}" \
			"${platform}" \
			"${architecture}" \
			"" \
			"${tag}"
	)" || return $?
	if [[ ! "${asset}" =~ ^[A-Za-z0-9._+@-]+$ ]]; then
		mantle_log_error "Rendered release asset name is invalid: ${asset}"
		return 64
	fi

	destination_name="${MANTLE_INSTALL_BINARY_NAME:-${MANTLE_INSTALL_TOOL_NAME}}"
	if [[ ! "${destination_name}" =~ ^[A-Za-z0-9._+-]+$ ]] ||
		[[ "${destination_name}" == "." || "${destination_name}" == ".." ]]; then
		mantle_log_error "Configured binary name is invalid: ${destination_name}"
		return 64
	fi
	archive_format="${MANTLE_INSTALL_ARCHIVE_FORMAT:-$(mantle_install_archive_format "${asset}")}" || return $?
	if [[ -n "${MANTLE_INSTALL_ARCHIVE_MEMBER_TEMPLATE:-}" ]]; then
		archive_member="$(
			mantle_install_template_render \
				"${MANTLE_INSTALL_ARCHIVE_MEMBER_TEMPLATE}" \
				"${version}" \
				"${platform}" \
				"${architecture}" \
				"${asset}" \
				"${tag}"
		)" || return $?
	fi
	if [[ -n "${MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE:-}" ]]; then
		checksum_asset="$(
			mantle_install_template_render \
				"${MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE}" \
				"${version}" \
				"${platform}" \
				"${architecture}" \
				"${asset}" \
				"${tag}"
		)" || return $?
	fi
	asset_url="$(
		mantle_install_github_release_asset_url \
			"${MANTLE_INSTALL_GITHUB_OWNER}" \
			"${MANTLE_INSTALL_GITHUB_REPOSITORY}" \
			"${tag}" \
			"${asset}"
	)" || return $?

	if [[ "${dry_run}" == "1" ]]; then
		printf "tool: %s\n" "${MANTLE_INSTALL_TOOL_NAME}"
		printf "version: %s\n" "${version}"
		printf "platform: %s\n" "${platform}"
		printf "architecture: %s\n" "${architecture}"
		printf "tag: %s\n" "${tag}"
		printf "asset: %s\n" "${asset}"
		printf "url: %s\n" "${asset_url}"
		printf "archive_format: %s\n" "${archive_format}"
		printf "archive_member: %s\n" "${archive_member:-none}"
		printf "checksum_asset: %s\n" "${checksum_asset:-none}"
		printf "install_dir: %s\n" "${target_directory}"
		return 0
	fi

	__mantle_install_github_execute \
		"${version}" \
		"${platform}" \
		"${architecture}" \
		"${tag}" \
		"${asset}" \
		"${asset_url}" \
		"${target_directory}" \
		"${destination_name}" \
		"${archive_format}" \
		"${archive_member}" \
		"${checksum_asset}" \
		"${skip_verification}"
}

MANTLE_INSTALL_GITHUB_LIBRARY_LOADED="1"

return 0
