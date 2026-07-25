#!/usr/bin/env bash
#
################################################################################
# kaye-commit-sense-hook.sh
#
# generate a Git commit message from the staged diff, through a Dify app
################################################################################
set -euo pipefail


################################################################################
# kamilog_shim
# lets scripts call `kamilog` safely even when it is not installed
################################################################################
_KAMILOG_BIN=$(type -P kamilog 2>/dev/null)

kamilog() {
    if [ -n "$_KAMILOG_BIN" ]; then
        "$_KAMILOG_BIN" "$@"
        return
    fi
    # no bin found, pass stdin through as-is
    cat
}
# END of kamilog_shim  #########################################################


# help  ########################################################################
readonly USAGE_TEXT="\
kaye-commit-sense-hook.sh

generate a Git commit message from the staged diff, through a Dify app.

usage:
  ./kaye-commit-sense-hook.sh MSG_FILE [SOURCE [COMMIT]]
                            run as a prepare-commit-msg hook
  ~~ --verify               check dependencies, settings, and backend
  ~~ --help|--version       print help/version

environment:
  KCC_DIFY_API_SECRET_KEY                required; the Dify Service API key
  KCC_DIFY_SERVICE_API_ENDPOINT   required; the Dify Service API address
  COMMIT_SENSE_SKIP               any non-empty value skips generation
"


# constants  ###################################################################
readonly VERSION="0.1.0"
readonly DIFY_USER="user"
readonly LOGGER_NAME="KCSHook"  # Kaye Commit Sense Hook
readonly -a REQUIRED_COMMANDS=(git curl jq)

# below Dify's 100-second blocking cutoff
readonly REQUEST_TIMEOUT_SECONDS=90


# environment  #################################################################
check_dependencies() {  ########################################################
    local cmd
    local -a missing=()

    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing+=("${cmd}")
        fi
    done

    if ((${#missing[@]} > 0)); then
        printf 'missing command: %s\n' \
            "${missing[*]}" | kamilog logger error "${LOGGER_NAME}"
        return 1
    fi
}


# fills KCC_DIFY_API_SECRET_KEY and KCC_DIFY_SERVICE_API_ENDPOINT;
# the key is never printed
resolve_config() {  ############################################################
    KCC_DIFY_API_SECRET_KEY="${KCC_DIFY_API_SECRET_KEY-}"
    if [[ -z "${KCC_DIFY_API_SECRET_KEY}" ]]; then
        printf 'KCC_DIFY_API_SECRET_KEY is not set\n' \
            | kamilog logger error "${LOGGER_NAME}"
        return 1
    fi

    KCC_DIFY_SERVICE_API_ENDPOINT="${KCC_DIFY_SERVICE_API_ENDPOINT-}"
    if [[ -z "${KCC_DIFY_SERVICE_API_ENDPOINT}" ]]; then
        printf 'KCC_DIFY_SERVICE_API_ENDPOINT is not set\n' \
            | kamilog logger error "${LOGGER_NAME}"
        return 1
    fi
    KCC_DIFY_SERVICE_API_ENDPOINT="${KCC_DIFY_SERVICE_API_ENDPOINT%/}"
}


# json  ########################################################################
# builds the /chat-messages request body; jq handles all escaping, including
# quotes, backslashes, newlines, and non-ASCII in the diff
build_chat_request() {  ########################################################
    local diff="$1"
    local user="$2"

    jq -n --arg query "${diff}" --arg user "${user}" '{
        query: $query,
        inputs: {},
        response_mode: "blocking",
        auto_generate_name: false,
        user: $user
    }'
}


# extracts the "answer" field from a blocking /chat-messages response; jq
# resolves \uXXXX escapes and UTF-16 surrogate pairs (emoji) on its own
extract_answer() {  ############################################################
    local json="$1"
    jq -r '.answer' <<<"${json}"
}


# extracts a top-level string field by name; used for /info's "mode"
extract_json_field() {  ########################################################
    local json="$1"
    local key="$2"
    jq -r --arg key "${key}" '.[$key]' <<<"${json}"
}


# transport  ###################################################################
# blocking POST /chat-messages; prints the answer on stdout, fails closed on a
# curl error, a non-2xx status, or a missing/empty answer
call_dify_chat() {  #############################################################
    local diff="$1"
    local body response http_status answer

    body="$(build_chat_request "${diff}" "${DIFY_USER}")"

    if ! response="$(curl -sS --max-time "${REQUEST_TIMEOUT_SECONDS}" \
        -X POST "${KCC_DIFY_SERVICE_API_ENDPOINT}/chat-messages" \
        -H "Authorization: Bearer ${KCC_DIFY_API_SECRET_KEY}" \
        -H 'Content-Type: application/json' \
        -d "${body}" \
        -w $'\n%{http_code}')"; then
        printf 'request to %s failed\n' \
            "${KCC_DIFY_SERVICE_API_ENDPOINT}/chat-messages" \
            | kamilog logger error "${LOGGER_NAME}"
        return 1
    fi

    http_status="${response##*$'\n'}"
    response="${response%$'\n'*}"

    if [[ "${http_status}" != 2* ]]; then
        printf '%s returned HTTP %s\n' \
            "${KCC_DIFY_SERVICE_API_ENDPOINT}/chat-messages" "${http_status}" \
            | kamilog logger error "${LOGGER_NAME}"
        return 1
    fi

    answer="$(extract_answer "${response}")"
    if [[ -z "${answer}" || "${answer}" == "null" ]]; then
        printf 'no answer in Dify reply\n' \
            | kamilog logger error "${LOGGER_NAME}"
        return 1
    fi

    printf '%s' "${answer}"
}


# GET /info; prints the raw JSON on stdout, fails closed on a curl error or a
# non-2xx status
call_dify_info() {  #############################################################
    local response http_status

    if ! response="$(curl -sS --max-time "${REQUEST_TIMEOUT_SECONDS}" \
        -X GET "${KCC_DIFY_SERVICE_API_ENDPOINT}/info" \
        -H "Authorization: Bearer ${KCC_DIFY_API_SECRET_KEY}" \
        -w $'\n%{http_code}')"; then
        printf 'request to %s failed\n' \
            "${KCC_DIFY_SERVICE_API_ENDPOINT}/info" | kamilog logger error "${LOGGER_NAME}"
        return 1
    fi

    http_status="${response##*$'\n'}"
    response="${response%$'\n'*}"

    if [[ "${http_status}" != 2* ]]; then
        printf '%s returned HTTP %s\n' \
            "${KCC_DIFY_SERVICE_API_ENDPOINT}/info" "${http_status}" \
            | kamilog logger error "${LOGGER_NAME}"
        return 1
    fi

    printf '%s' "${response}"
}


# spinner  ####################################################################
# simple spinner drawn on stderr; call with "start", then "stop"
_spinner_pid=""

spinner() {  ###################################################################
    local action="$1"
    local frames=("|" "/" "-" "\\")
    local i=0

    case "${action}" in
        start)
            if [[ -n "${_spinner_pid}" ]]; then
                return  # spinner already running
            fi
            (
                while true; do
                    printf '\rwaiting for Dify... %s' \
                        "${frames[$((i % 4))]}" >&2
                    i=$((i + 1))
                    sleep 0.1
                done
            ) &
            _spinner_pid=$!
            ;;
        stop)
            if [[ -z "${_spinner_pid}" ]]; then
                return  # no spinner running
            fi
            kill "${_spinner_pid}" 2>/dev/null || true
            wait "${_spinner_pid}" 2>/dev/null || true
            printf '\r' >&2
            _spinner_pid=""
            ;;
    esac
}


run_verify() {  ################################################################
    local mode
    local exit_code=0

    printf 'verifying environment...\n' \
        | kamilog logger info "${LOGGER_NAME}"

    # check dependencies  ========================================================
    if ! check_dependencies; then
        exit_code=1
    fi

    # resolve configuration  ====================================================
    if ! resolve_config 2>/dev/null; then
        printf 'configuration incomplete\n' \
            | kamilog logger error "${LOGGER_NAME}"
        exit_code=1
    fi

    if ((exit_code != 0)); then
        return "${exit_code}"
    fi

    # call GET /info and check mode  =============================================
    local info
    if ! info="$(call_dify_info)"; then
        exit_code=1
    else
        mode="$(extract_json_field "${info}" "mode")"
        if [[ "${mode}" != "advanced-chat" ]]; then
            printf 'app mode is %s, expected advanced-chat\n' \
                "${mode}" | kamilog logger error "${LOGGER_NAME}"
            exit_code=1
        fi
    fi

    if ((exit_code == 0)); then
        printf 'all checks passed\n' \
            | kamilog logger info "${LOGGER_NAME}"
    fi

    return "${exit_code}"
}


# hook  ########################################################################
# takes Git's prepare-commit-msg contract: $1 msg-file, $2 source, $3 commit
run_hook() {
    local msg_file="$1"
    local source="${2-}"
    local diff answer tmp_file

    # gate: skip if opt-out is set  ==============================================
    if [[ -n "${COMMIT_SENSE_SKIP-}" ]]; then
        return 0
    fi

    # gate: skip if source indicates reuse or explicit message  ==================
    case "${source}" in
        message|merge|squash|commit)
            return 0
            ;;
    esac

    # gate: skip if staged diff is empty  ========================================
    if ! diff="$(git diff --cached)"; then
        return 1
    fi

    if [[ -z "${diff}" ]]; then
        return 0
    fi

    # resolve configuration  ====================================================
    if ! resolve_config 2>/dev/null; then
        return 1
    fi

    # generate message through Dify  =============================================
    spinner start
    trap 'spinner stop' RETURN INT TERM
    if ! answer="$(call_dify_chat "${diff}")"; then
        spinner stop
        return 1
    fi
    spinner stop

    # write message  =============================================================
    tmp_file="$(mktemp)" || return 1
    trap 'rm -f "${tmp_file}"' RETURN
    {
        printf '%s\n' "${answer}"
        cat "${msg_file}"
    } >"${tmp_file}" || return 1

    if ! mv "${tmp_file}" "${msg_file}"; then
        return 1
    fi

    printf 'done\n' | kamilog logger "done" "${LOGGER_NAME}"
    return 0
}


# Entry Point  #################################################################
main() {
    local is_hook_path=false

    case "${1-}" in  # ---------------------------------------------------------
        --verify)
            run_verify
            return
            ;;
        --help)  # -------------------------------------------------------------
            printf '%s' "${USAGE_TEXT}"
            return 0
            ;;
        --version)  # ----------------------------------------------------------
            printf '%s\n' "${VERSION}"
            return 0
            ;;
        "")  # -----------------------------------------------------------------
            # no message file, so generation is impossible; fall to the usage
            ;;
        --)  # explicit hook path
            shift
            if (($# > 0)); then
                is_hook_path=true
            fi
            ;;
        -*)  # -----------------------------------------------------------------
            printf 'unknown mode: %s\n' "$1" \
                | kamilog logger error "${LOGGER_NAME}"
            ;;
        *)  # ------------------------------------------------------------------
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

# run only when executed, so the tests can source this file
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
