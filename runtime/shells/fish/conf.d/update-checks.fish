# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Explicitly selected update-notification suppression; separate from telemetry.
set -gx CHECKPOINT_DISABLE 1
set -gx STRAPI_DISABLE_UPDATE_NOTIFICATION true
set -gx POWERSHELL_UPDATECHECK Off
set -gx PNPPOWERSHELL_UPDATECHECK false
set -gx PULUMI_SKIP_UPDATE_CHECK true
set -gx VAGRANT_BOX_UPDATE_CHECK_DISABLE 1
set -gx VAGRANT_CHECKPOINT_DISABLE 1
set -gx INFRACOST_SKIP_UPDATE_CHECK true
set -gx HOMEBREW_NO_AUTO_UPDATE 1
