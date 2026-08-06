#!/usr/bin/env bash
# shellcheck shell=bash
# Install curated or explicitly selected families from the Google Fonts repository.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

google_fonts_ref="${GOOGLE_FONTS_REF:-main}"
google_fonts_sha256="${GOOGLE_FONTS_SHA256:-}"
install_all_fonts="0"
dry_run="0"
custom_families="0"
declare -a google_font_families=("inter" "notosans" "notosansmono" "robotomono")

case "${MANTLE_OS_FAMILY:-unknown}" in
darwin) google_fonts_destination="${GOOGLE_FONTS_DIRECTORY:-${HOME}/Library/Fonts/Google}" ;;
linux) google_fonts_destination="${GOOGLE_FONTS_DIRECTORY:-${XDG_DATA_HOME:-${HOME}/.local/share}/fonts/google}" ;;
*)
	mantle_log_error "Google Fonts installation supports macOS and Linux"
	exit 69
	;;
esac

# @description Print mantle install google-fonts usage.
mantle_install_google_fonts_usage() {
	printf "%s\n" \
		"Usage: mantle install google-fonts [--family FAMILY ... | --all] [--ref REF]" \
		"                            [--sha256 HEX] [--destination DIRECTORY] [--dry-run] [--help]" \
		"" \
		"The default curated families are Inter, Noto Sans, Noto Sans Mono, and Roboto Mono." \
		"--all is explicit because the complete Google Fonts repository is very large."
}

# @description Install one font file while preserving its source-relative path.
# @arg $1 string Font file path.
# @arg $2 string Source root path.
# @arg $3 string Destination root path.
mantle_install_google_fonts_copy_file() {
	local font_file="${1:-}"
	local source_root="${2:-}"
	local destination_root="${3:-}"
	local relative_path=""
	local destination_path=""

	if (($# != 3)) || [[ "${font_file}" != "${source_root}"/* ]]; then return 64; fi
	relative_path="${font_file#"${source_root}/"}"
	destination_path="${destination_root%/}/${relative_path}"
	mkdir -p "$(dirname "${destination_path}")"
	install -m 0644 "${font_file}" "${destination_path}"
}

while (($# > 0)); do
	case "$1" in
	--family)
		if (($# < 2)) || [[ ! "${2:-}" =~ ^[A-Za-z0-9._+-]+$ ]]; then
			mantle_install_google_fonts_usage >&2
			exit 64
		fi
		if [[ "${custom_families}" == "0" ]]; then
			google_font_families=()
			custom_families="1"
		fi
		google_font_families+=("$2")
		shift 2
		;;
	--all)
		install_all_fonts="1"
		shift
		;;
	--ref)
		if (($# < 2)) || [[ -z "${2:-}" ]]; then
			mantle_install_google_fonts_usage >&2
			exit 64
		fi
		google_fonts_ref="$2"
		shift 2
		;;
	--sha256)
		if (($# < 2)) || [[ ! "${2:-}" =~ ^[[:xdigit:]]{64}$ ]]; then
			mantle_install_google_fonts_usage >&2
			exit 64
		fi
		google_fonts_sha256="$2"
		shift 2
		;;
	--destination)
		if (($# < 2)) || [[ -z "${2:-}" ]]; then
			mantle_install_google_fonts_usage >&2
			exit 64
		fi
		google_fonts_destination="$2"
		shift 2
		;;
	--dry-run)
		dry_run="1"
		shift
		;;
	--help | -h)
		mantle_install_google_fonts_usage
		exit 0
		;;
	*)
		mantle_log_error "Unknown argument: $1"
		mantle_install_google_fonts_usage >&2
		exit 64
		;;
	esac
done

google_fonts_url="https://github.com/google/fonts/archive/${google_fonts_ref}.zip"
if [[ "${dry_run}" == "1" ]]; then
	printf "source: %s\n" "${google_fonts_url}"
	printf "ref: %s\n" "${google_fonts_ref}"
	printf "destination: %s\n" "${google_fonts_destination}"
	printf "selection: %s\n" "$([[ "${install_all_fonts}" == "1" ]] && printf "all" || printf "%s" "${google_font_families[*]}")"
	printf "checksum: %s\n" "${google_fonts_sha256:-not configured}"
	exit 0
fi

google_fonts_temporary_directory="$(mantle_install_filesystem_make_temporary_directory)"
trap 'mantle_install_filesystem_cleanup "${google_fonts_temporary_directory:-}" >/dev/null 2>&1 || true' EXIT
google_fonts_archive="${google_fonts_temporary_directory}/google-fonts.zip"
google_fonts_extract="${google_fonts_temporary_directory}/extract"

mantle_log_info "Downloading Google Fonts at ${google_fonts_ref}"
mantle_install_download_file "${google_fonts_url}" "${google_fonts_archive}"
if [[ -n "${google_fonts_sha256}" ]]; then
	mantle_install_checksum_verify "sha256" "${google_fonts_archive}" "${google_fonts_sha256}"
else
	mantle_log_warn "No SHA-256 digest is configured for the Google Fonts archive"
fi
mantle_install_archive_extract "${google_fonts_archive}" "${google_fonts_extract}" "" "zip"

google_fonts_root=""
for extracted_path in "${google_fonts_extract}"/*; do
	if [[ -d "${extracted_path}" ]]; then
		if [[ -n "${google_fonts_root}" ]]; then
			mantle_log_error "Expected one extracted Google Fonts repository directory"
			exit 1
		fi
		google_fonts_root="${extracted_path}"
	fi
done
if [[ -z "${google_fonts_root}" ]]; then
	mantle_log_error "Unable to locate the extracted Google Fonts repository"
	exit 1
fi

installed_font_count=0
if [[ "${install_all_fonts}" == "1" ]]; then
	while IFS= read -r font_file; do
		mantle_install_google_fonts_copy_file "${font_file}" "${google_fonts_root}" "${google_fonts_destination}"
		installed_font_count=$((installed_font_count + 1))
	done < <(find "${google_fonts_root}" -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.ttc" -o -iname "*.otc" \) -print)
else
	for font_family in "${google_font_families[@]}"; do
		declare -a matching_directories=()
		while IFS= read -r matching_directory; do matching_directories+=("${matching_directory}"); done < <(
			find "${google_fonts_root}" -type d -iname "${font_family}" -print
		)
		if ((${#matching_directories[@]} != 1)); then
			mantle_log_error "Expected exactly one Google Fonts family named ${font_family}; found ${#matching_directories[@]}"
			exit 1
		fi
		while IFS= read -r font_file; do
			mantle_install_google_fonts_copy_file "${font_file}" "${matching_directories[0]}" "${google_fonts_destination%/}/${font_family}"
			installed_font_count=$((installed_font_count + 1))
		done < <(find "${matching_directories[0]}" -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.ttc" -o -iname "*.otc" \) -print)
	done
fi

if ((installed_font_count == 0)); then
	mantle_log_error "No font files were installed"
	exit 1
fi
if mantle_guard_has_command fc-cache; then fc-cache --force "${google_fonts_destination}" >/dev/null; fi
mantle_log_success "Installed ${installed_font_count} Google Fonts files to ${google_fonts_destination}"
