#!/usr/bin/env bash
# shellcheck shell=bash
# Install selected Nerd Font families from checksummed release archives.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

nerd_fonts_version="${NERD_FONTS_VERSION:-}"
install_all_fonts="0"
force_install="0"
dry_run="0"
custom_families="0"
declare -a nerd_font_families=("FiraCode" "Hack" "JetBrainsMono" "Meslo")

case "${MANTLE_OS_FAMILY:-unknown}" in
	darwin) nerd_fonts_destination="${NERD_FONTS_DIRECTORY:-${HOME}/Library/Fonts/NerdFonts}" ;;
	linux) nerd_fonts_destination="${NERD_FONTS_DIRECTORY:-${XDG_DATA_HOME:-${HOME}/.local/share}/fonts/nerd-fonts}" ;;
	*)
		mantle_log_error "Nerd Fonts installation supports macOS and Linux"
		exit 69
		;;
esac

# @description Print mantle install nerd-fonts usage.
mantle_install_nerd_fonts_usage() {
	printf "%s\n" \
		"Usage: mantle install nerd-fonts [--font FAMILY ... | --all] [--version VERSION]" \
		"                           [--destination DIRECTORY] [--force] [--dry-run] [--help]"
}

# @description Resolve all font archive names from a Nerd Fonts release.
# @arg $1 string Release tag.
# @stdout One font family name per line.
mantle_install_nerd_fonts_all_families() {
	local release_tag="${1:-}"
	local temporary_directory=""
	local metadata_path=""

	if (($# != 1)) || [[ -z "${release_tag}" ]]; then return 64; fi
	temporary_directory="$(mantle_install_filesystem_make_temporary_directory)" || return $?
	metadata_path="${temporary_directory}/release.json"
	mantle_install_download_file \
		"https://api.github.com/repos/ryanoasis/nerd-fonts/releases/tags/${release_tag}" \
		"${metadata_path}" \
		"Accept: application/vnd.github+json" \
		"X-GitHub-Api-Version: 2022-11-28" \
		"User-Agent: mantle-installer" || {
		mantle_install_filesystem_cleanup "${temporary_directory}" || true
		return 1
	}
	if mantle_guard_has_command jq; then
		jq --raw-output '.assets[].name | select(endswith(".tar.xz")) | sub("\\.tar\\.xz$"; "")' "${metadata_path}"
	elif mantle_guard_has_command python3; then
		python3 -c 'import json, sys
for asset in json.load(open(sys.argv[1], encoding="utf-8")).get("assets", []):
    name = asset.get("name", "")
    if name.endswith(".tar.xz"):
        print(name[:-7])' "${metadata_path}"
	else
		mantle_log_error "Enumerating all Nerd Fonts requires jq or Python 3"
		mantle_install_filesystem_cleanup "${temporary_directory}" || true
		return 69
	fi
	mantle_install_filesystem_cleanup "${temporary_directory}" || true
}

# @description Install one Nerd Font family from a checksummed release archive.
# @arg $1 string Release version without a leading v.
# @arg $2 string Font family asset name.
# @arg $3 string Temporary work directory.
mantle_install_nerd_fonts_family() {
	local version="${1:-}"
	local family="${2:-}"
	local temporary_root="${3:-}"
	local tag="v${version}"
	local asset="${family}.tar.xz"
	local family_directory="${nerd_fonts_destination%/}/${family}"
	local archive_path="${temporary_root}/${asset}"
	local extraction_path="${temporary_root}/extract-${family}"
	local expected_checksum=""
	local installed_count=0
	local font_file=""

	if (($# != 3)) || [[ ! "${family}" =~ ^[A-Za-z0-9._+-]+$ ]]; then return 64; fi
	if [[ -d "${family_directory}" && "${force_install}" == "0" ]]; then
		mantle_log_info "Skipping ${family}; destination already exists"
		return 0
	fi
	if [[ "${dry_run}" == "1" ]]; then
		printf "font: %s\n" "${family}"
		printf "url: https://github.com/ryanoasis/nerd-fonts/releases/download/%s/%s\n" "${tag}" "${asset}"
		printf "destination: %s\n" "${family_directory}"
		return 0
	fi

	mantle_log_info "Downloading Nerd Font ${family} ${tag}"
	mantle_install_download_file \
		"https://github.com/ryanoasis/nerd-fonts/releases/download/${tag}/${asset}" \
		"${archive_path}"
	expected_checksum="$(
		mantle_install_github_checksum_from_release \
			"ryanoasis" "nerd-fonts" "${tag}" "SHA-256.txt" "${asset}"
	)" || {
		mantle_log_error "Unable to resolve the published checksum for ${asset}"
		return 1
	}
	mantle_install_checksum_verify "sha256" "${archive_path}" "${expected_checksum}"
	mantle_install_archive_extract "${archive_path}" "${extraction_path}" "" "tar.xz"

	mkdir -p "${family_directory}"
	while IFS= read -r font_file; do
		install -m 0644 "${font_file}" "${family_directory}/$(basename "${font_file}")"
		installed_count=$((installed_count + 1))
	done < <(find "${extraction_path}" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -print)
	if ((installed_count == 0)); then
		mantle_log_error "No font files were found in ${asset}"
		return 1
	fi
	mantle_log_success "Installed ${family} (${installed_count} files)"
}

while (($# > 0)); do
	case "$1" in
		--font)
			if (($# < 2)) || [[ ! "${2:-}" =~ ^[A-Za-z0-9._+-]+$ ]]; then
				mantle_install_nerd_fonts_usage >&2
				exit 64
			fi
			if [[ "${custom_families}" == "0" ]]; then
				nerd_font_families=()
				custom_families="1"
			fi
			nerd_font_families+=("$2")
			shift 2
			;;
		--all)
			install_all_fonts="1"
			shift
			;;
		--version)
			if (($# < 2)) || [[ -z "${2:-}" ]]; then
				mantle_install_nerd_fonts_usage >&2
				exit 64
			fi
			nerd_fonts_version="${2#v}"
			shift 2
			;;
		--destination)
			if (($# < 2)) || [[ -z "${2:-}" ]]; then
				mantle_install_nerd_fonts_usage >&2
				exit 64
			fi
			nerd_fonts_destination="$2"
			shift 2
			;;
		--force)
			force_install="1"
			shift
			;;
		--dry-run)
			dry_run="1"
			shift
			;;
		--help | -h)
			mantle_install_nerd_fonts_usage
			exit 0
			;;
		*)
			mantle_log_error "Unknown argument: $1"
			mantle_install_nerd_fonts_usage >&2
			exit 64
			;;
	esac
done

nerd_fonts_version="$(mantle_install_github_resolve_version "ryanoasis" "nerd-fonts" "${nerd_fonts_version}" "v")"
if [[ "${install_all_fonts}" == "1" ]]; then
	nerd_font_families=()
	while IFS= read -r font_family; do nerd_font_families+=("${font_family}"); done < <(
		mantle_install_nerd_fonts_all_families "v${nerd_fonts_version}"
	)
fi
if ((${#nerd_font_families[@]} == 0)); then
	mantle_log_error "No Nerd Font families were selected"
	exit 64
fi

if [[ "${dry_run}" == "1" ]]; then
	nerd_fonts_temporary_directory="DRY_RUN"
else
	nerd_fonts_temporary_directory="$(mantle_install_filesystem_make_temporary_directory)"
	trap 'mantle_install_filesystem_cleanup "${nerd_fonts_temporary_directory:-}" >/dev/null 2>&1 || true' EXIT
fi
for font_family in "${nerd_font_families[@]}"; do
	mantle_install_nerd_fonts_family "${nerd_fonts_version}" "${font_family}" "${nerd_fonts_temporary_directory}"
done
if [[ "${dry_run}" == "0" ]] && mantle_guard_has_command fc-cache; then
	fc-cache --force "${nerd_fonts_destination}" >/dev/null
fi
