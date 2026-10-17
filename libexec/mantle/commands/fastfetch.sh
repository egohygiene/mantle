#!/usr/bin/env bash
# shellcheck shell=bash
# Small, offline data collectors for the recommended Fastfetch dashboard.

set -o errexit
set -o nounset
set -o pipefail

mantle_fastfetch_usage() {
	printf "%s\n" \
		"Usage: mantle fastfetch {runtime|workspace|toolchains|contexts} [--help]" \
		"" \
		"Print one short, offline dashboard value. Optional tools may be absent." \
		"Workspace queries do not scan files or contact Git remotes." \
		"Tool versions have a 150 ms limit each; slow tools report available." \
		"Contexts are environment hints, not a connection or authentication check."
}

# Remove terminal controls and bound user-controlled labels to one short value.
mantle_fastfetch_label() {
	local label="${1:-}"
	label="${label//[$'\001'-$'\037'$'\177']/}"
	printf "%.96s" "${label}"
}

mantle_fastfetch_runtime() {
	local version="${MANTLE_VERSION:-}"
	if [[ -z "${version}" && -r "${MANTLE_ROOT}/VERSION" ]]; then
		IFS= read -r version <"${MANTLE_ROOT}/VERSION" || true
	fi
	mantle_fastfetch_label "${version:-development} / ${MANTLE_SHELL_NAME:-shell} / ${MANTLE_RUNTIME_ENVIRONMENT:-local}"
	printf "\n"
}

mantle_fastfetch_workspace() {
	local directory="${PWD:-.}" root="" branch="" revision=""
	local name="${directory##*/}"
	if command -v git >/dev/null 2>&1; then
		root="$(mantle_presentation_run_bounded 0.15 git --no-optional-locks rev-parse --show-toplevel 2>/dev/null)" || root=""
	fi
	if [[ -z "${root}" ]]; then
		mantle_fastfetch_label "${name:-/} (no Git)"
	else
		name="${root##*/}"
		branch="$(mantle_presentation_run_bounded 0.15 git --no-optional-locks symbolic-ref --quiet --short HEAD 2>/dev/null)" || branch=""
		if [[ -z "${branch}" ]]; then
			revision="$(mantle_presentation_run_bounded 0.15 git --no-optional-locks rev-parse --short HEAD 2>/dev/null)" || revision=""
			branch="detached${revision:+@${revision}}"
		fi
		mantle_fastfetch_label "${name:-/} / ${branch}"
	fi
	printf "\n"
}

mantle_fastfetch_toolchains() {
	local tool="" version="" separator="" found="0" name="" number=""
	for tool in python3 node go rustc; do
		command -v "${tool}" >/dev/null 2>&1 || continue
		found="1"
		if [[ "${tool}" == "go" ]]; then
			# `go version` can download a project-selected toolchain under auto.
			# Force the already installed compiler and disable module networking.
			version="$(mantle_presentation_run_bounded 0.15 env GOTOOLCHAIN=local GOPROXY=off GOSUMDB=off MISE_AUTO_INSTALL=0 RUSTUP_AUTO_INSTALL=0 RUSTUP_NO_UPDATE_CHECK=1 UV_OFFLINE=1 "${tool}" version 2>/dev/null)" || version=""
		else
			version="$(mantle_presentation_run_bounded 0.15 env MISE_AUTO_INSTALL=0 RUSTUP_AUTO_INSTALL=0 RUSTUP_NO_UPDATE_CHECK=1 UV_OFFLINE=1 "${tool}" --version 2>/dev/null)" || version=""
		fi
		version="${version%%$'\n'*}"
		if [[ -n "${version}" ]]; then
			if [[ "${tool}" == "node" ]]; then
				version="node ${version}"
			elif [[ "${tool}" == "go" ]]; then
				version="${version#go version go}"
				version="Go ${version%% *}"
			else
				read -r name number _ <<<"${version}"
				version="${name}${number:+ ${number}}"
			fi
		fi
		printf "%s" "${separator}"
		mantle_fastfetch_label "${version:-${tool} available}"
		separator=" | "
	done
	if [[ "${found}" == "0" ]]; then
		printf "none detected"
	fi
	printf "\n"
}

mantle_fastfetch_contexts() {
	local hints=""
	if [[ -n "${DOCKER_CONTEXT:-}" ]]; then
		hints="docker: ${DOCKER_CONTEXT}"
	elif [[ -n "${DOCKER_HOST:-}" ]]; then
		hints="docker: endpoint configured"
	fi
	[[ -z "${KUBECONFIG:-}" ]] || hints="${hints}${hints:+ | }kubeconfig set"
	[[ -z "${AWS_PROFILE:-}" ]] || hints="${hints}${hints:+ | }aws: ${AWS_PROFILE}"
	[[ -z "${CLOUDSDK_ACTIVE_CONFIG_NAME:-}" ]] || hints="${hints}${hints:+ | }gcloud: ${CLOUDSDK_ACTIVE_CONFIG_NAME}"
	[[ -z "${VIRTUAL_ENV:-}" ]] || hints="${hints}${hints:+ | }venv: ${VIRTUAL_ENV##*/}"
	[[ -z "${CONDA_DEFAULT_ENV:-}" ]] || hints="${hints}${hints:+ | }conda: ${CONDA_DEFAULT_ENV}"
	mantle_fastfetch_label "${hints:-no explicit contexts}"
	printf "\n"
}

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi

case "${1:-}" in
--summary)
	printf "Collect offline development context for Fastfetch.\n"
	exit 0
	;;
--help | -h)
	mantle_fastfetch_usage
	exit 0
	;;
runtime | workspace | toolchains | contexts)
	if (($# == 2)) && [[ "$2" == "--help" || "$2" == "-h" ]]; then
		mantle_fastfetch_usage
		exit 0
	fi
	if (($# != 1)); then
		mantle_fastfetch_usage >&2
		exit 64
	fi
	;;
*)
	mantle_fastfetch_usage >&2
	exit 64
	;;
esac

# shellcheck source=lib/presentation/bounded.sh
source "${MANTLE_ROOT}/lib/presentation/bounded.sh"
"mantle_fastfetch_$1"
