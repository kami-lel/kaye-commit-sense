#!/usr/bin/env bash
#
################################################################################
# script-verify-demo.sh
#
# demonstrate running the hook script's preflight check
################################################################################
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOOK_SCRIPT="${SCRIPT_DIR}/../kaye-commit-sense-hook.sh"

"${HOOK_SCRIPT}" --verify
