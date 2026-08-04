#!/usr/bin/env bash
# shellcheck shell=bash
#
# Apply Mantle's default environment profile in deterministic dependency order.
#
# This file performs orchestration only. Environment values, aliases, history
# policy, telemetry preferences, and tool configuration belong in modules.

if [[ -n "${BASH_VERSION:-}" ]]; then
	if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
		printf "[mantle:error] init/bootstrap.sh is internal and must be sourced\n" >&2
		exit 64
	fi
fi

if [[ "${MANTLE_BOOTSTRAP_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] init/bootstrap.sh: MANTLE_ROOT is not set\n" >&2
	return 1
fi

if ! command -v mantle_load_module >/dev/null 2>&1; then
	printf "[mantle:error] init/bootstrap.sh: mantle_load_module is unavailable\n" >&2
	return 1
fi

__mantle_bootstrap_load_required_module() {
	local module_name="${1:-}"
	local module_status=0

	mantle_load_module "${module_name}"
	module_status=$?

	if ((module_status != 0)); then
		printf "[mantle:error] required module failed with status %d: %s\n" \
			"${module_status}" "${module_name}" >&2
	fi

	return "${module_status}"
}

__mantle_bootstrap_status=0

# Establish filesystem locations and policies before tool configuration. The
# environment module loads last in this phase so PATH reflects locations chosen
# by cache and tooling modules.
for __mantle_bootstrap_module in xdg privacy cache tooling environment; do
	__mantle_bootstrap_load_required_module \
		"${__mantle_bootstrap_module}" || __mantle_bootstrap_status=$?

	if ((__mantle_bootstrap_status != 0)); then
		break
	fi
done

# Operating-system adapters may depend on the XDG, cache, tooling, and PATH
# contracts established by the portable environment modules.
if ((__mantle_bootstrap_status == 0)); then
	# shellcheck disable=SC1091
	source "${MANTLE_ROOT}/init/load-platform-runtime.sh"
	__mantle_bootstrap_status=$?
fi

# Aliases and history are shell-local UX and must never load into a
# noninteractive shell merely because Mantle is present in CI or a container.
if ((__mantle_bootstrap_status == 0)) && [[ "${MANTLE_INTERACTIVE:-0}" == "1" ]]; then
	for __mantle_bootstrap_module in aliases history; do
		__mantle_bootstrap_load_required_module \
			"${__mantle_bootstrap_module}" || __mantle_bootstrap_status=$?

		if ((__mantle_bootstrap_status != 0)); then
			break
		fi
	done
fi

# Automatic update-check suppression is explicitly opt-in because update
# notifications can carry security information.
if ((__mantle_bootstrap_status == 0)) &&
	[[ "${MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS:-0}" == "1" ]]; then
	__mantle_bootstrap_load_required_module "update-checks" || __mantle_bootstrap_status=$?
fi

if ((__mantle_bootstrap_status == 0)) && [[ "${MANTLE_ENABLE_EXPERIMENTAL:-0}" == "1" ]]; then
	__mantle_bootstrap_load_required_module "experimental" || __mantle_bootstrap_status=$?
fi

unset -f __mantle_bootstrap_load_required_module
unset __mantle_bootstrap_module

if ((__mantle_bootstrap_status == 0)); then
	MANTLE_BOOTSTRAP_LOADED="1"
	unset __mantle_bootstrap_status
	return 0
fi

MANTLE_LAST_ERROR_STATUS="${__mantle_bootstrap_status}"
unset __mantle_bootstrap_status

return "${MANTLE_LAST_ERROR_STATUS}"
