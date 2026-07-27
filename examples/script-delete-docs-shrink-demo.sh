#!/usr/bin/env bash
#
################################################################################
# script-delete-docs-shrink-demo.sh
#
# demonstrate generating a commit message from the delete-docs-shrink fixture
################################################################################
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOOK_SCRIPT="${SCRIPT_DIR}/../kaye-commit-sense-hook.sh"
readonly DIFF_FILE="${SCRIPT_DIR}/diffs/delete-docs-shrink.diff"

# shellcheck source=../kaye-commit-sense-hook.sh
source "${HOOK_SCRIPT}"

diff="$(cat "${DIFF_FILE}")"
answer="$(generate_message "${diff}")"

printf 'FETCHED' | kamilog cb c 1
printf '%s\n' "${answer}"
