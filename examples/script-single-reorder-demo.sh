#!/usr/bin/env bash
#
################################################################################
# script-single-reorder-demo.sh
#
# demonstrate generating a commit message from the single-reorder fixture
################################################################################
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOOK_SCRIPT="${SCRIPT_DIR}/../src/kaye-commit-sense-hook.sh"
readonly DIFF_FILE="${SCRIPT_DIR}/diffs/single-reorder.diff"

# shellcheck source=../src/kaye-commit-sense-hook.sh
source "${HOOK_SCRIPT}"

diff="$(cat "${DIFF_FILE}")"
answer="$(generate_message "${diff}")"

printf 'FETCHED' | kamilog cb c 1
printf '%s\n' "${answer}"
