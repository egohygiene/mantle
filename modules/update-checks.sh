#!/usr/bin/env bash
# shellcheck shell=bash
#
# Suppress supported tools' automatic update checks and notifications.
#
# This policy is not enabled by default because update notifications may contain
# security information. init/bootstrap.sh loads it only when
# MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS=1.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/update-checks.sh is internal and must be sourced\n" >&2
	exit 64
elif [[ -n "${ZSH_VERSION:-}" && "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
	printf "[mantle:error] modules/update-checks.sh is internal and must be sourced\n" >&2
	exit 64
fi

export CHECKPOINT_DISABLE="1"
export STRAPI_DISABLE_UPDATE_NOTIFICATION="true"
export POWERSHELL_UPDATECHECK="Off"
export PNPPOWERSHELL_UPDATECHECK="false"
export PULUMI_SKIP_UPDATE_CHECK="true"
export VAGRANT_BOX_UPDATE_CHECK_DISABLE="1"
export VAGRANT_CHECKPOINT_DISABLE="1"
export INFRACOST_SKIP_UPDATE_CHECK="true"
export HOMEBREW_NO_AUTO_UPDATE="1"

# Security-fix alerts and core updater capabilities are deliberately not
# suppressed, even under this policy.

return 0
