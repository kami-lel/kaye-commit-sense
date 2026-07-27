#!/usr/bin/env bash
#
################################################################################
# kaye-commit-sense-hook.sh
#
# generate a Git commit message from the staged diff, through a Dify app
################################################################################
set -euo pipefail


readonly VERSION="0.1.0"


################################################################################
# kamilog_shim
# lets scripts call `kamilog` safely even when it is not installed
# shipped with kamilog v2.9.0, q.v. https://github.com/kami-lel/kamilog
################################################################################
_KAMILOG_BIN="$(type -P kamilog 2>/dev/null || true)"

kamilog() {
    if [ -n "$_KAMILOG_BIN" ]; then
        "$_KAMILOG_BIN" "$@"
        return
    fi
    case "$1" in
        cb|cb0)
            printf '# %s\n' "$(cat)"
            ;;
        logger)
            printf '%s:\t%s\n' "$2" "$(cat)"
            ;;
        *)
            cat  # no bin found, pass stdin through as-is
            ;;
    esac
}
# END of kamilog_shim  #########################################################


# constant  ####################################################################
readonly LOGGER_ROOT="KCSH"  # every section without a name of its own


# verification  ################################################################
# answers one question: can this machine run at all

# every command the run depends on
readonly -a REQUIRED_COMMANDS=(git curl jq)

check_dependencies() {  # ------------------------------------------------------
    local cmd
    local -a missing=()

    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing+=("${cmd}")
        fi
    done

    if ((${#missing[@]} > 0)); then
        printf 'missing command: %s' "${missing[*]}" \
            | kamilog logger error "${LOGGER_ROOT}"
        return 1
    fi
}


# fills KCSH_DIFY_SERVICE_API_ENDPOINT, KCSH_DIFY_SERVICE_API_SECRET_KEY,
# KCSH_REQUEST_TIMEOUT_SEC, and KCSH_DISABLE_MD_SYNTAX; the key is never
# printed
resolve_config() {  # ----------------------------------------------------------
    local has_error=false

    KCSH_DIFY_SERVICE_API_ENDPOINT="${KCSH_DIFY_SERVICE_API_ENDPOINT-}"
    if [[ -z "${KCSH_DIFY_SERVICE_API_ENDPOINT}" ]]; then
        printf 'KCSH_DIFY_SERVICE_API_ENDPOINT unset' \
            | kamilog logger error "${LOGGER_ROOT}"
        has_error=true
    fi

    KCSH_DIFY_SERVICE_API_SECRET_KEY="${KCSH_DIFY_SERVICE_API_SECRET_KEY-}"
    if [[ -z "${KCSH_DIFY_SERVICE_API_SECRET_KEY}" ]]; then
        printf 'KCSH_DIFY_SERVICE_API_SECRET_KEY unset' \
            | kamilog logger error "${LOGGER_ROOT}"
        has_error=true
    fi

    if [[ "${has_error}" == true ]]; then
        return 1
    fi
    KCSH_DIFY_SERVICE_API_ENDPOINT="${KCSH_DIFY_SERVICE_API_ENDPOINT%/}"

    # default kept below Dify's 100-second blocking cutoff
    KCSH_REQUEST_TIMEOUT_SEC="${KCSH_REQUEST_TIMEOUT_SEC:-45}"
    KCSH_DISABLE_MD_SYNTAX="${KCSH_DISABLE_MD_SYNTAX:-False}"
}


# normalizes KCSH_DISABLE_MD_SYNTAX to a lowercase "true"/"false" jq boolean
is_md_syntax_disabled() {  # ---------------------------------------------------
    case "${KCSH_DISABLE_MD_SYNTAX,,}" in
        true|1|yes)
            printf 'true'
            ;;
        *)
            printf 'false'
            ;;
    esac
}


# checks dependencies, configuration, and the backend; writes nothing
run_verify() {  # --------------------------------------------------------------
    local mode
    local exit_code=0

    printf 'verifying environment' \
        | kamilog logger enter "${LOGGER_ROOT}"

    # every later check parses JSON, so this one gates the rest
    if ! command -v jq >/dev/null 2>&1; then
        printf 'jq not installed' \
            | kamilog logger fail "${LOGGER_ROOT}"
        return 1
    fi
    printf 'jq installed' \
        | kamilog logger pass "${LOGGER_ROOT}"

    if ! check_dependencies; then
        exit_code=1
    fi

    if ! resolve_config; then
        printf 'config incomplete' \
            | kamilog logger fail "${LOGGER_ROOT}"
        exit_code=1
    else
        printf 'api endpoint: %s' "${KCSH_DIFY_SERVICE_API_ENDPOINT}" \
            | kamilog logger info "${LOGGER_ROOT}"
        printf 'request timeout: %s second' "${KCSH_REQUEST_TIMEOUT_SEC}" \
            | kamilog logger info "${LOGGER_ROOT}"
        if [[ "$(is_md_syntax_disabled)" == true ]]; then
            printf 'markdown syntax: disabled' \
                | kamilog logger info "${LOGGER_ROOT}"
        else
            printf 'markdown syntax: enabled' \
                | kamilog logger info "${LOGGER_ROOT}"
        fi
        printf 'config verified' \
            | kamilog logger pass "${LOGGER_ROOT}"
    fi

    if ((exit_code != 0)); then
        return "${exit_code}"
    fi

    printf 'reaching Dify App by /info endpoint' \
        | kamilog logger enter "${LOGGER_ROOT}"

    local info
    if ! info="$(call_dify_info)"; then
        exit_code=1
    else
        mode="$(extract_json_field "${info}" "mode")"
        if [[ "${mode}" != "advanced-chat" ]]; then
            printf 'app mode is %s, expected advanced-chat' "${mode}" \
                | kamilog logger error "${LOGGER_ROOT}"
            exit_code=1
        else
            printf 'app mode is: %s' "${mode}" \
                | kamilog logger info "${LOGGER_ROOT}"
            printf 'Dify App reachable' \
                | kamilog logger pass "${LOGGER_ROOT}"
        fi
    fi

    if ((exit_code == 0)); then
        printf 'all verified' \
            | kamilog logger "done" "${LOGGER_ROOT}"
    fi

    return "${exit_code}"
}


# dify  ########################################################################
# everything crossing the wire, and every way it can fail closed

readonly LOGGER_DIFY="${LOGGER_ROOT}.dify"

# identifies the caller to the Dify app
readonly DIFY_USER="user"


# builds the /chat-messages request body; jq handles all escaping, including
# quotes, backslashes, newlines, and non-ASCII in the diff
build_chat_request() {  # ------------------------------------------------------
    local diff="$1"
    local user="$2"
    local disable_md_syntax="$3"  # normalized "true" or "false"

    jq -n \
        --arg query "${diff}" \
        --arg user "${user}" \
        --argjson disable_md_syntax "${disable_md_syntax}" '{
        query: $query,
        inputs: { disable_md_syntax: $disable_md_syntax },
        response_mode: "blocking",
        auto_generate_name: false,
        user: $user
    }'
}


# extracts the "answer" field from a blocking /chat-messages response; jq
# resolves \uXXXX escapes and UTF-16 surrogate pairs (emoji) on its own
extract_answer() {  # ----------------------------------------------------------
    local json="$1"
    jq -r '.answer' <<<"${json}"
}


# extracts a top-level string field by name; used for /info's "mode"
extract_json_field() {  # ------------------------------------------------------
    local json="$1"
    local key="$2"
    jq -r --arg key "${key}" '.[$key]' <<<"${json}"
}


# blocking POST /chat-messages; prints the answer on stdout, fails closed on a
# curl error, a non-2xx status, or a missing/empty answer
call_dify_chat() {  # ----------------------------------------------------------
    local diff="$1"
    local body response http_status answer

    body="$(build_chat_request "${diff}" "${DIFY_USER}" \
        "$(is_md_syntax_disabled)")"

    if ! response="$(curl -sS --max-time "${KCSH_REQUEST_TIMEOUT_SEC}" \
        -X POST "${KCSH_DIFY_SERVICE_API_ENDPOINT}/chat-messages" \
        -H "Authorization: Bearer ${KCSH_DIFY_SERVICE_API_SECRET_KEY}" \
        -H 'Content-Type: application/json' \
        -d "${body}" \
        -w $'\n%{http_code}')"; then
        printf 'request to %s failed' \
            "${KCSH_DIFY_SERVICE_API_ENDPOINT}/chat-messages" \
            | kamilog logger error "${LOGGER_DIFY}"
        return 1
    fi

    http_status="${response##*$'\n'}"
    response="${response%$'\n'*}"

    if [[ "${http_status}" != 2* ]]; then
        printf 'returned HTTP %s: %s' \
            "${http_status}" "${KCSH_DIFY_SERVICE_API_ENDPOINT}/chat-messages" \
            | kamilog logger error "${LOGGER_DIFY}"
        return 1
    fi

    answer="$(extract_answer "${response}")"
    if [[ -z "${answer}" || "${answer}" == "null" ]]; then
        printf 'no answer in Dify reply' \
            | kamilog logger error "${LOGGER_DIFY}"
        return 1
    fi

    printf '%s' "${answer}"
}


# GET /info; prints the raw JSON on stdout, fails closed on a curl error or a
# non-2xx status
call_dify_info() {  # ----------------------------------------------------------
    local response http_status

    if ! response="$(curl -sS --max-time "${KCSH_REQUEST_TIMEOUT_SEC}" \
        -X GET "${KCSH_DIFY_SERVICE_API_ENDPOINT}/info" \
        -H "Authorization: Bearer ${KCSH_DIFY_SERVICE_API_SECRET_KEY}" \
        -w $'\n%{http_code}')"; then
        printf 'request to %s failed' \
            "${KCSH_DIFY_SERVICE_API_ENDPOINT}/info" \
            | kamilog logger error "${LOGGER_DIFY}"
        return 1
    fi

    http_status="${response##*$'\n'}"
    response="${response%$'\n'*}"

    if [[ "${http_status}" != 2* ]]; then
        printf '%s returned HTTP %s' \
            "${KCSH_DIFY_SERVICE_API_ENDPOINT}/info" "${http_status}" \
            | kamilog logger error "${LOGGER_DIFY}"
        return 1
    fi

    printf '%s' "${response}"
}


# turns a diff already in hand into a commit message on stdout
generate_message() {  # --------------------------------------------------------
    local diff="$1"
    local answer

    if ! resolve_config; then
        return 1
    fi

    # logs go to stderr; stdout belongs to the answer alone
    printf 'contacting Dify, up to %ss' "${KCSH_REQUEST_TIMEOUT_SEC}" \
        | kamilog logger enter "${LOGGER_DIFY}" >&2

    if ! answer="$(call_dify_chat "${diff}")"; then
        return 1
    fi

    printf 'message generated' \
        | kamilog logger succ "${LOGGER_DIFY}" >&2

    printf '%s' "${answer}"
}


# git  #########################################################################
# everything Git hands over, and everything it expects back

readonly LOGGER_GIT="${LOGGER_ROOT}.git"

# decides whether generation should happen at all, given Git's $2 source
# argument; 0 means proceed, 1 means skip
is_generation_allowed() {  # ---------------------------------------------------
    local source="${1-}"

    if [[ -n "${KCSH_ENABLE_SKIPPING-}" ]]; then
        return 1  # explicit opt-out
    fi

    case "${source}" in
        message|merge|squash|commit)
            return 1  # Git supplied a message already
            ;;
    esac

    return 0
}


# prints the staged diff on stdout; empty output means nothing is staged
read_staged_diff() {  # --------------------------------------------------------
    git diff --cached
}


# prepends the answer above the existing message; the temporary file makes the
# replacement atomic, so an interrupted run never leaves a half-written message
write_message_file() {  # ------------------------------------------------------
    local answer="$1"
    local msg_file="$2"
    local tmp_file

    tmp_file="$(mktemp)" || return 1
    trap 'rm -f "${tmp_file}"' RETURN

    {
        printf '%s\n' "${answer}"
        cat "${msg_file}"
    } >"${tmp_file}" || return 1

    mv "${tmp_file}" "${msg_file}"
}


# Main Entry Point  ############################################################
# argument dispatch and orchestration; no logic of its own

readonly USAGE_TEXT="\
kaye-commit-sense-hook.sh

generate a Git commit message from the staged diff, through a Dify app.

usage:
  ./kaye-commit-sense-hook.sh MSG_FILE [SOURCE [COMMIT]]
                            run as a prepare-commit-msg hook
  ~~ --verify               check dependencies, settings, and backend
  ~~ --help|--version       print help/version

environment:
  KCSH_DIFY_SERVICE_API_SECRET_KEY  Dify Service API key of Kaye Commit Sense App
  KCSH_DIFY_SERVICE_API_ENDPOINT    Dify Service API endpoint address of Kaye Commit Sense App
  KCSH_REQUEST_TIMEOUT_SEC          network request timeout, in seconds; optional, default=45
  KCSH_DISABLE_MD_SYNTAX            disables Markdown syntax in the generated message; optional, default=False
  KCSH_ENABLE_SKIPPING              whether skips this hook entirely; optional, default=False
"


# Hack manually update logic & logs
# takes Git's prepare-commit-msg contract: $1 msg-file, $2 source, $3 commit
run_hook() {  # ----------------------------------------------------------------
    local msg_file="$1"
    local source="${2-}"
    local diff answer

    if ! is_generation_allowed "${source}"; then
        return 0  # a deliberate skip is a success
    fi

    if ! diff="$(read_staged_diff)"; then
        return 1
    fi

    if [[ -z "${diff}" ]]; then
        return 0  # nothing staged, nothing to describe
    fi

    if ! answer="$(generate_message "${diff}")"; then
        return 1
    fi

    if ! write_message_file "${answer}" "${msg_file}"; then
        return 1
    fi

    printf 'done' | kamilog logger "done" "${LOGGER_ROOT}"
    return 0
}


# a leading dash selects a mode; anything else is Git's positional contract
main() {  # --------------------------------------------------------------------
    local is_hook_path=false

    case "${1-}" in
        --verify)
            run_verify
            return
            ;;
        --help)
            printf '%s' "${USAGE_TEXT}"
            return 0
            ;;
        --version)
            printf '%s\n' "${VERSION}"
            return 0
            ;;
        "")
            # Bug fix & simplify these logics
            # no message file, so generation is impossible; fall to the usage
            ;;
        --)
            shift  # explicit hook path
            if (($# > 0)); then
                is_hook_path=true
            fi
            ;;
        -*)
            printf 'unknown mode: %s' "$1" \
                | kamilog logger error "${LOGGER_ROOT}"
            ;;
        *)
            # implicit hook path; Git never passes a leading-dash msg-file
            is_hook_path=true
            ;;
    esac

    if [[ "${is_hook_path}" == true ]]; then
        run_hook "$@"
        return
    fi

    printf '%s' "${USAGE_TEXT}" >&2
    return 2
}

# run only when executed, so a demo can source this file
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
