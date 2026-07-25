#!/usr/bin/env bash
#
################################################################################
# tests/test-commit-sense-via-dify.sh
#
# offline tests for the pure functions in commit-sense-via-dify.sh
################################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../commit-sense-via-dify.sh
source "${SCRIPT_DIR}/../commit-sense-via-dify.sh"

pass_count=0
fail_count=0

# reports a single check, tracking the running pass/fail counters
assert_eq() {  #################################################################
    local label="$1"
    local expected="$2"
    local actual="$3"

    if [[ "${expected}" == "${actual}" ]]; then
        pass_count=$((pass_count + 1))
        printf 'ok - %s\n' "${label}"
    else
        fail_count=$((fail_count + 1))
        printf 'not ok - %s\n  expected: %s\n  actual:   %s\n' \
            "${label}" "${expected}" "${actual}" >&2
    fi
}


# build_chat_request  ##########################################################
diff_with_quotes_and_newlines=$'diff --git a/f "b" c\n+line one\n+line "two"'
request="$(build_chat_request "${diff_with_quotes_and_newlines}" "user")"

assert_eq "build_chat_request: query round-trips through jq" \
    "${diff_with_quotes_and_newlines}" \
    "$(jq -r '.query' <<<"${request}")"

assert_eq "build_chat_request: response_mode is blocking" \
    "blocking" \
    "$(jq -r '.response_mode' <<<"${request}")"

assert_eq "build_chat_request: user is passed through" \
    "some-user" \
    "$(jq -r '.user' <<<"$(build_chat_request "diff" "some-user")")"


# extract_answer  ##############################################################
assert_eq "extract_answer: plain text" \
    "hello" \
    "$(extract_answer '{"answer":"hello"}')"

assert_eq "extract_answer: embedded quote and newline" \
    'say "hi"
next line' \
    "$(extract_answer '{"answer":"say \"hi\"\nnext line"}')"

assert_eq "extract_answer: \\uXXXX escape" \
    "cafe" \
    "$(extract_answer '{"answer":"cafe"}')"

assert_eq "extract_answer: surrogate pair (emoji)" \
    "$(printf '\xf0\x9f\x98\x80')" \
    "$(extract_answer '{"answer":"😀"}')"


# extract_json_field  ##########################################################
assert_eq "extract_json_field: top-level string field" \
    "advanced-chat" \
    "$(extract_json_field '{"mode":"advanced-chat","name":"x"}' "mode")"

assert_eq "extract_json_field: missing key yields null" \
    "null" \
    "$(extract_json_field '{"mode":"advanced-chat"}' "missing")"


# should_generate gate  #########################################################
# skip if COMMIT_SENSE_SKIP is non-empty
COMMIT_SENSE_SKIP=1 run_hook /dev/null
assert_eq "should_generate: skip when COMMIT_SENSE_SKIP is set" \
    "0" \
    "$?"

# skip if source is message
run_hook /dev/null "message"
assert_eq "should_generate: skip when source is message" \
    "0" \
    "$?"

# skip if source is merge
run_hook /dev/null "merge"
assert_eq "should_generate: skip when source is merge" \
    "0" \
    "$?"

# skip if source is squash
run_hook /dev/null "squash"
assert_eq "should_generate: skip when source is squash" \
    "0" \
    "$?"

# skip if source is commit
run_hook /dev/null "commit"
assert_eq "should_generate: skip when source is commit" \
    "0" \
    "$?"


printf '\n%d passed, %d failed\n' "${pass_count}" "${fail_count}"
((fail_count == 0))
