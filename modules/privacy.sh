#!/usr/bin/env bash
# shellcheck shell=bash
#
# Apply Mantle's telemetry-disable policy across supported developer tools.
# This module performs no network access and does not disable update checks;
# update-check suppression is isolated in modules/update-checks.sh.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/privacy.sh is internal and must be sourced\n" >&2
	exit 64
elif [[ -n "${ZSH_VERSION:-}" && "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
	printf "[mantle:error] modules/privacy.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_DISABLE_TELEMETRY:-1}" != "1" ]]; then
	return 0
fi

# Cross-ecosystem privacy conventions.
export DO_NOT_TRACK="1"

# Go, JavaScript, and web tooling.
export GOTELEMETRY="off"
export YARN_ENABLE_TELEMETRY="false"
export NEXT_TELEMETRY_DISABLED="1"
export GATSBY_TELEMETRY_DISABLED="1"
export STORYBOOK_DISABLE_TELEMETRY="1"
export NUXT_TELEMETRY_DISABLED="1"
export VUEDX_TELEMETRY="off"
export STRAPI_TELEMETRY_DISABLED="true"
export REACT_APP_WEBINY_TELEMETRY="false"
export NG_CLI_ANALYTICS="false"
export NG_CLI_ANALYTICS_SHARE="false"
export CARBON_TELEMETRY_DISABLED="1"
export HINT_TELEMETRY="off"
export DA_TEST_DISABLE_TELEMETRY="1"

# .NET and Microsoft tooling.
export DOTNET_CLI_TELEMETRY_OPTOUT="1"
export DOTNET_INTERACTIVE_CLI_TELEMETRY_OPTOUT="1"
export MLDOTNET_CLI_TELEMETRY_OPTOUT="True"
export DOTNET_SVCUTIL_TELEMETRY_OPTOUT="1"
export MSSQL_CLI_TELEMETRY_OPTOUT="True"
export POWERSHELL_TELEMETRY_OPTOUT="1"
export PNPPOWERSHELL_DISABLETELEMETRY="true"
export VSTEST_TELEMETRY_OPTEDIN="0"
export ORYX_DISABLE_TELEMETRY="true"
export BF_CLI_TELEMETRY="false"
export MOBILE_CENTER_TELEMETRY="off"
export APPCD_TELEMETRY="0"
export PROSE_TELEMETRY_OPTOUT="1"
export RESTLER_TELEMETRY_OPTOUT="1"

# Cloud, infrastructure, and DevOps tooling.
export CLOUDSDK_CORE_DISABLE_USAGE_REPORTING="true"
export AZURE_CORE_COLLECT_TELEMETRY="0"
export SAM_CLI_TELEMETRY="0"
export WERF_TELEMETRY="0"
export SLS_TRACKING_DISABLED="1"
export SLS_TELEMETRY_DISABLED="1"
export ARM_DISABLE_TERRAFORM_PARTNER_ID="true"
export KICS_COLLECT_TELEMETRY="0"
export INFRACOST_SELF_HOSTED_TELEMETRY="false"
export STRIPE_CLI_TELEMETRY_OPTOUT="1"
export SF_DISABLE_TELEMETRY="true"
export SFDX_DISABLE_TELEMETRY="true"
export EARTHLY_DISABLE_ANALYTICS="1"
export NUKE_TELEMETRY_OPTOUT="1"
export DECK_ANALYTICS="off"
export APOLLO_TELEMETRY_DISABLED="1"
export SALTO_TELEMETRY_DISABLE="1"
export TEEM_DISABLE="true"
export F5_ALLOW_TELEMETRY="false"
export CHEF_TELEMETRY_OPT_OUT="1"
export DASH_DISABLE_TELEMETRY="1"
export PANTS_ANONYMOUS_TELEMETRY_ENABLED="false"
export HOOKDECK_CLI_TELEMETRY_OPTOUT="1"
export BATECT_ENABLE_TELEMETRY="false"
export SKU_TELEMETRY="false"
export TUIST_STATS_OPT_OUT="1"
export AUTOMATEDLAB_TELEMETRY_OPTIN="0"
export AUTOMATEDLAB_TELEMETRY_OPTOUT="1"

# Package managers and build/release tooling.
export HOMEBREW_NO_ANALYTICS="1"
export HOMEBREW_NO_ANALYTICS_THIS_RUN="1"
export COCOAPODS_DISABLE_STATS="true"
export ALIBUILD_NO_ANALYTICS="1"
export CHOOSENIM_NO_ANALYTICS="1"
export FASTLANE_OPT_OUT_USAGE="YES"

# Data, machine-learning, and database tooling.
export INFLUXD_REPORTING_DISABLED="true"
export HASURA_GRAPHQL_ENABLE_TELEMETRY="false"
export MEILI_NO_ANALYTICS="true"
export FEAST_TELEMETRY="False"
export MELTANO_DISABLE_TRACKING="True"
export QUILT_DISABLE_USAGE_METRICS="True"
export DAGSTER_DISABLE_TELEMETRY="1"
export CUBEJS_TELEMETRY="false"
export RASA_TELEMETRY_ENABLED="false"
export ALLOW_UI_ANALYTICS="false"
export NC_DISABLE_TELE="1"
export ONE_CODEX_NO_TELEMETRY="True"
export ROCKSET_CLI_TELEMETRY_OPTOUT="1"
export DISABLE_QUICKWIT_TELEMETRY="1"

# Other supported tools.
export CANVAS_LMS_STATS_COLLECTION="opt_out"
export ET_NO_TELEMETRY="ANY_VALUE"
export MSLAB_TELEMETRY_LEVEL="None"
export ARDUINO_METRICS_ENABLED="false"
export LYNX_ANALYTICS="0"
export SCOUT_DISABLE="1"
export AUTOMAGICA_NO_TELEMETRY="1"
export MM_LOGSETTINGS_ENABLEDIAGNOSTICS="false"
export REPORTPORTAL_CLIENT_JS_NO_ANALYTICS="true"

if [[ "${MANTLE_OS_FAMILY:-unknown}" == "linux" ]]; then
	export IG_PRO_OPT_OUT="YES"
fi

return 0
