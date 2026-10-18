#!/usr/bin/env bats
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Contract tests for Mantle's ownership and dependency boundaries.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'

	MANTLE_LAYER_REGISTRY="${MANTLE_ROOT}/config/architecture/layers.tsv"
}

architecture_rows() {
	awk -F '\t' 'NF && $1 !~ /^#/ && $1 != "path" { print }' \
		"${MANTLE_LAYER_REGISTRY}"
}

maintained_architecture_files() {
	printf "%s\n" ".shellrc" "install.sh"
	find "${MANTLE_ROOT}/bin" -maxdepth 1 -type f -print | sed "s#^${MANTLE_ROOT}/##"
	find "${MANTLE_ROOT}/init" \
		"${MANTLE_ROOT}/lib" \
		"${MANTLE_ROOT}/libexec" \
		"${MANTLE_ROOT}/modules" \
		"${MANTLE_ROOT}/platforms" \
		"${MANTLE_ROOT}/scripts" \
		"${MANTLE_ROOT}/runtime" \
		"${MANTLE_ROOT}/tests" \
		-type f \
		\( -name "*.sh" -o -name "*.bash" -o -name "*.bats" -o -name "*.fish" -o -name "*.py" -o -name "*.awk" \) \
		-print | sed "s#^${MANTLE_ROOT}/##" | sort
}

layer_allows_dependency() {
	local consumer_layer="${1:?}"
	local dependency_layer="${2:?}"
	local layer=""
	local allowed=""

	while IFS=$'\t' read -r _ layer _ _ allowed; do
		[[ "${layer}" == "${consumer_layer}" ]] || continue
		case ",${allowed}," in
		*",${dependency_layer},"*) return 0 ;;
		esac
	done < <(architecture_rows)

	return 1
}

@test "layer registry has a valid, unique schema" {
	assert_file_exists "${MANTLE_LAYER_REGISTRY}"

	local failed=0
	local registered_path=""
	local layer=""
	local visibility=""
	local owner=""
	local allowed=""

	[[ "$(grep -v '^#' "${MANTLE_LAYER_REGISTRY}" | head -n 1)" == $'path\tlayer\tvisibility\towner\tallowed_dependencies' ]]

	while IFS=$'\t' read -r registered_path layer visibility owner allowed; do
		[[ -n "${registered_path}" && -n "${layer}" && -n "${owner}" && -n "${allowed}" ]] || {
			printf "Incomplete architecture row: %s\n" "${registered_path:-<empty>}" >&2
			failed=1
			continue
		}

		case "${visibility}" in public | internal | optional | test) ;; *)
			printf "Invalid visibility for %s: %s\n" "${registered_path}" "${visibility}" >&2
			failed=1
			;;
		esac

		if [[ "${registered_path}" == */ ]]; then
			if [[ ! -d "${MANTLE_ROOT}/${registered_path}" ]]; then
				printf "Registered directory does not exist: %s\n" "${registered_path}" >&2
				failed=1
			fi
		elif [[ ! -f "${MANTLE_ROOT}/${registered_path}" ]]; then
			printf "Registered file does not exist: %s\n" "${registered_path}" >&2
			failed=1
		fi
	done < <(architecture_rows)

	[[ "$(architecture_rows | cut -f 1 | sort | uniq -d | wc -l | tr -d ' ')" -eq 0 ]]
	[[ "${failed}" -eq 0 ]]
}

@test "every maintained runtime and validation source belongs to exactly one layer" {
	maintained_architecture_files | awk -F '\t' '
        FNR == NR {
            if (NF && $1 !~ /^#/ && $1 != "path") paths[++count] = $1
            next
        }
        {
            matches = 0
            for (entry = 1; entry <= count; entry++) {
                path = paths[entry]
                if (substr(path, length(path), 1) == "/") {
                    if (index($0, path) == 1) matches++
                } else if ($0 == path) matches++
            }
            if (matches != 1) {
                printf "%s maps to %d architecture layers\n", $0, matches > "/dev/stderr"
                failed = 1
            }
        }
        END { exit failed }
    ' "${MANTLE_LAYER_REGISTRY}" -
}

@test "declared dependency layers exist and do not point back to entrypoints" {
	local failed=0
	local consumer_layer=""
	local dependency_list=""
	local dependency_layer=""

	while IFS=$'\t' read -r _ consumer_layer _ _ dependency_list; do
		[[ "${dependency_list}" != "none" ]] || continue
		while IFS= read -r dependency_layer; do
			if ! architecture_rows | cut -f 2 | grep -qx "${dependency_layer}"; then
				printf "Unknown dependency for %s: %s\n" \
					"${consumer_layer}" "${dependency_layer}" >&2
				failed=1
			fi
			case "${dependency_layer}" in
			cli-entrypoint | install-entrypoint)
				printf "Layer %s depends backward on %s\n" \
					"${consumer_layer}" "${dependency_layer}" >&2
				failed=1
				;;
			esac
		done < <(printf "%s\n" "${dependency_list}" | tr ',' '\n')
	done < <(architecture_rows)

	[[ "${failed}" -eq 0 ]]
	run layer_allows_dependency "cli-entrypoint" "install-library"
	assert_failure
}

@test "source-time edges follow the declared dependency direction" {
	layer_allows_dependency "shell-entrypoint" "initialization"
	layer_allows_dependency "fish-entrypoint" "fish-runtime"
	layer_allows_dependency "initialization" "shared-runtime"
	layer_allows_dependency "initialization" "shell-runtime"
	layer_allows_dependency "initialization" "module-loader"
	layer_allows_dependency "initialization" "config-library"
	layer_allows_dependency "initialization" "platform"
	layer_allows_dependency "shared-runtime" "core-library"
	layer_allows_dependency "shell-runtime" "core-library"
	layer_allows_dependency "shell-runtime" "bash-library"
	layer_allows_dependency "module-loader" "module"
	layer_allows_dependency "platform" "platform"
	layer_allows_dependency "installer" "install-library"
	layer_allows_dependency "install-library" "core-library"
	layer_allows_dependency "install-library" "install-library"
	layer_allows_dependency "command" "config-library"
	layer_allows_dependency "command" "presentation-library"
	layer_allows_dependency "config-library" "core-library"
}

@test "layers without source dependencies contain no active source command" {
	local failed=0
	local registered_path=""
	local allowed=""
	local search_path=""

	while IFS=$'\t' read -r registered_path _ _ _ allowed; do
		[[ "${allowed}" == "none" ]] || continue
		search_path="${MANTLE_ROOT}/${registered_path}"
		if [[ -d "${search_path}" ]]; then
			if grep -R -n -E '^[[:space:]]*(source|\.)[[:space:]]+' \
				--include='*.sh' --include='*.bash' --include='*.fish' \
				"${search_path}"; then
				failed=1
			fi
		else
			case "${registered_path}" in
			*.sh | *.bash | *.fish | .shellrc | bin/*)
				if grep -n -E '^[[:space:]]*(source|\.)[[:space:]]+' "${search_path}"; then
					failed=1
				fi
				;;
			esac
		fi
	done < <(architecture_rows)

	[[ "${failed}" -eq 0 ]]
}
