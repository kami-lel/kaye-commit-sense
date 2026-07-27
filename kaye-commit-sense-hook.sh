#!/usr/bin/env bash
#
################################################################################
# kaye-commit-sense-hook.sh
#
# generate a Git commit message from the staged diff, through a Dify app
# Part of Kaye Commit Sense
# Q.v. https://github.com/kami-lel/kaye-commit-sense
################################################################################
set -euo pipefail

# no pager or editor may ever wait on input here
export GIT_PAGER=cat PAGER=cat


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

# probed when `command -v` fails, eg under a minimal-PATH GUI environment
readonly -a FALLBACK_BIN_DIRS=(/usr/bin /usr/local/bin /opt/homebrew/bin /bin)

# bare names by default; check_dependencies resolves each to an absolute
# path, so sourcing without it first (eg the demos) still finds them on PATH
GIT_BIN="git"
CURL_BIN="curl"
JQ_BIN="jq"

# optional backstop beyond --max-time; GNU-only, degrades to curl alone
_TIMEOUT_BIN="$(command -v timeout 2>/dev/null || true)"

# resolves ${cmd} to an absolute path into ${var_name}; command -v, then
# FALLBACK_BIN_DIRS; fails with a message naming every place searched
resolve_dependency() {  # -------------------------------------------------------
    local cmd="$1"
    local var_name="$2"
    local resolved="" dir

    resolved="$(command -v "${cmd}" 2>/dev/null || true)"
    if [[ -z "${resolved}" ]]; then
        for dir in "${FALLBACK_BIN_DIRS[@]}"; do
            if [[ -x "${dir}/${cmd}" ]]; then
                resolved="${dir}/${cmd}"
                break
            fi
        done
    fi

    if [[ -z "${resolved}" ]]; then
        printf '%s not found on PATH or in %s' \
            "${cmd}" "${FALLBACK_BIN_DIRS[*]}" \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        return 1
    fi

    printf -v "${var_name}" '%s' "${resolved}"
    printf '%s resolved: %s' "${cmd}" "${resolved}" \
        | kamilog logger succ "${LOGGER_ROOT}" >&2
}

check_dependencies() {  # ------------------------------------------------------
    local cmd var_name
    local -a missing=()

    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        case "${cmd}" in
            git) var_name="GIT_BIN" ;;
            curl) var_name="CURL_BIN" ;;
            jq) var_name="JQ_BIN" ;;
        esac
        if ! resolve_dependency "${cmd}" "${var_name}"; then
            missing+=("${cmd}")
        fi
    done

    if ((${#missing[@]} > 0)); then
        printf 'missing command: %s' "${missing[*]}" \
            | kamilog logger fail "${LOGGER_ROOT}" >&2
        return 1
    fi

    printf 'dependencies verified' \
        | kamilog logger pass "${LOGGER_ROOT}" >&2
}


# reports interpreter, dependency, and hook-install paths; advisory only
check_hook_installation() {  # --------------------------------------------------
    local hooks_dir bash_bin file

    bash_bin="$(type -P bash 2>/dev/null || true)"
    printf 'interpreter: %s' "${bash_bin:-not found}" \
        | kamilog logger info "${LOGGER_ROOT}" >&2
    printf 'dependency paths: git=%s curl=%s jq=%s' \
        "${GIT_BIN}" "${CURL_BIN}" "${JQ_BIN}" \
        | kamilog logger info "${LOGGER_ROOT}" >&2

    hooks_dir="$("${GIT_BIN}" rev-parse --git-path hooks 2>/dev/null || true)"
    if [[ -z "${hooks_dir}" ]]; then
        printf 'could not resolve the active hooks directory' \
            | kamilog logger warning "${LOGGER_ROOT}" >&2
        return 0
    fi
    printf 'active hooks directory: %s' "${hooks_dir}" \
        | kamilog logger info "${LOGGER_ROOT}" >&2

    for file in prepare-commit-msg kaye-commit-sense-hook.sh; do
        if [[ -x "${hooks_dir}/${file}" ]]; then
            printf '%s installed and executable' "${file}" \
                | kamilog logger pass "${LOGGER_ROOT}" >&2
        else
            printf '%s not installed or not executable at %s' \
                "${file}" "${hooks_dir}" \
                | kamilog logger warning "${LOGGER_ROOT}" >&2
        fi
    done
}


# fills KCSH_DIFY_SERVICE_API_ENDPOINT, KCSH_DIFY_SERVICE_API_SECRET_KEY,
# KCSH_REQUEST_TIMEOUT_SEC, and KCSH_DISABLE_MD_SYNTAX; the key is never
# printed
resolve_config() {  # ----------------------------------------------------------
    local has_error=false

    KCSH_DIFY_SERVICE_API_ENDPOINT="${KCSH_DIFY_SERVICE_API_ENDPOINT-}"
    if [[ -z "${KCSH_DIFY_SERVICE_API_ENDPOINT}" ]]; then
        printf 'KCSH_DIFY_SERVICE_API_ENDPOINT unset' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        has_error=true
    fi

    KCSH_DIFY_SERVICE_API_SECRET_KEY="${KCSH_DIFY_SERVICE_API_SECRET_KEY-}"
    if [[ -z "${KCSH_DIFY_SERVICE_API_SECRET_KEY}" ]]; then
        printf 'KCSH_DIFY_SERVICE_API_SECRET_KEY unset' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        has_error=true
    fi

    if [[ "${has_error}" == true ]]; then
        return 1
    fi
    KCSH_DIFY_SERVICE_API_ENDPOINT="${KCSH_DIFY_SERVICE_API_ENDPOINT%/}"

    # default kept below Dify's 100s cutoff; only no-op paths meet 2s
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
        | kamilog logger enter "${LOGGER_ROOT}" >&2

    # later checks parse JSON and call curl, so this one gates the rest
    if ! check_dependencies; then
        return 1
    fi

    check_hook_installation

    if ! resolve_config; then
        printf 'config incomplete' \
            | kamilog logger fail "${LOGGER_ROOT}" >&2
        exit_code=1
    else
        printf 'api endpoint: %s' "${KCSH_DIFY_SERVICE_API_ENDPOINT}" \
            | kamilog logger info "${LOGGER_ROOT}" >&2
        printf 'request timeout: %s second' "${KCSH_REQUEST_TIMEOUT_SEC}" \
            | kamilog logger info "${LOGGER_ROOT}" >&2
        if [[ "$(is_md_syntax_disabled)" == true ]]; then
            printf 'markdown syntax: disabled' \
                | kamilog logger info "${LOGGER_ROOT}" >&2
        else
            printf 'markdown syntax: enabled' \
                | kamilog logger info "${LOGGER_ROOT}" >&2
        fi
        printf 'config verified' \
            | kamilog logger pass "${LOGGER_ROOT}" >&2
    fi

    if ((exit_code != 0)); then
        return "${exit_code}"
    fi

    printf 'reaching Dify App by /info endpoint' \
        | kamilog logger enter "${LOGGER_ROOT}" >&2

    local info
    if ! info="$(call_dify_info)"; then
        exit_code=1
    else
        mode="$(extract_json_field "${info}" "mode")"
        if [[ "${mode}" != "advanced-chat" ]]; then
            printf 'app mode is %s, expected advanced-chat' "${mode}" \
                | kamilog logger error "${LOGGER_ROOT}" >&2
            exit_code=1
        else
            printf 'app mode is: %s' "${mode}" \
                | kamilog logger info "${LOGGER_ROOT}" >&2
            printf 'Dify App reachable' \
                | kamilog logger pass "${LOGGER_ROOT}" >&2
        fi
    fi

    if ((exit_code == 0)); then
        printf 'all verified' \
            | kamilog logger "done" "${LOGGER_ROOT}" >&2
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

    "${JQ_BIN}" -n \
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
    "${JQ_BIN}" -r '.answer' <<<"${json}"
}


# extracts a top-level string field by name; used for /info's "mode"
extract_json_field() {  # ------------------------------------------------------
    local json="$1"
    local key="$2"
    "${JQ_BIN}" -r --arg key "${key}" '.[$key]' <<<"${json}"
}


# blocking POST /chat-messages; prints the answer on stdout, fails closed on a
# curl error, a non-2xx status, or a missing/empty answer
call_dify_chat() {  # ----------------------------------------------------------
    local diff="$1"
    local body response http_status answer
    local -a runner=()

    body="$(build_chat_request "${diff}" "${DIFY_USER}" \
        "$(is_md_syntax_disabled)")"

    # hard kill if curl ever ignores its own --max-time
    if [[ -n "${_TIMEOUT_BIN}" ]]; then
        runner=("${_TIMEOUT_BIN}" "$((KCSH_REQUEST_TIMEOUT_SEC + 5))")
    fi

    if ! response="$("${runner[@]}" "${CURL_BIN}" -sS \
        --max-time "${KCSH_REQUEST_TIMEOUT_SEC}" \
        -X POST "${KCSH_DIFY_SERVICE_API_ENDPOINT}/chat-messages" \
        -H "Authorization: Bearer ${KCSH_DIFY_SERVICE_API_SECRET_KEY}" \
        -H 'Content-Type: application/json' \
        -d "${body}" \
        -w $'\n%{http_code}')"; then
        printf 'request to %s failed' \
            "${KCSH_DIFY_SERVICE_API_ENDPOINT}/chat-messages" \
            | kamilog logger error "${LOGGER_DIFY}" >&2
        return 1
    fi

    http_status="${response##*$'\n'}"
    response="${response%$'\n'*}"

    if [[ "${http_status}" != 2* ]]; then
        printf 'returned HTTP %s: %s' \
            "${http_status}" "${KCSH_DIFY_SERVICE_API_ENDPOINT}/chat-messages" \
            | kamilog logger error "${LOGGER_DIFY}" >&2
        return 1
    fi

    answer="$(extract_answer "${response}")"
    if [[ -z "${answer}" || "${answer}" == "null" ]]; then
        printf 'no answer in Dify reply' \
            | kamilog logger error "${LOGGER_DIFY}" >&2
        return 1
    fi

    printf '%s' "${answer}"
}


# GET /info; prints the raw JSON on stdout, fails closed on a curl error or a
# non-2xx status
call_dify_info() {  # ----------------------------------------------------------
    local response http_status
    local -a runner=()

    if [[ -n "${_TIMEOUT_BIN}" ]]; then
        runner=("${_TIMEOUT_BIN}" "$((KCSH_REQUEST_TIMEOUT_SEC + 5))")
    fi

    if ! response="$("${runner[@]}" "${CURL_BIN}" -sS \
        --max-time "${KCSH_REQUEST_TIMEOUT_SEC}" \
        -X GET "${KCSH_DIFY_SERVICE_API_ENDPOINT}/info" \
        -H "Authorization: Bearer ${KCSH_DIFY_SERVICE_API_SECRET_KEY}" \
        -w $'\n%{http_code}')"; then
        printf 'request to %s failed' \
            "${KCSH_DIFY_SERVICE_API_ENDPOINT}/info" \
            | kamilog logger error "${LOGGER_DIFY}" >&2
        return 1
    fi

    http_status="${response##*$'\n'}"
    response="${response%$'\n'*}"

    if [[ "${http_status}" != 2* ]]; then
        printf '%s returned HTTP %s' \
            "${KCSH_DIFY_SERVICE_API_ENDPOINT}/info" "${http_status}" \
            | kamilog logger error "${LOGGER_DIFY}" >&2
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
    "${GIT_BIN}" diff --cached
}


# prepends the answer above the existing message; the temporary file makes the
# replacement atomic, so an interrupted run never leaves a half-written message
write_message_file() {  # ------------------------------------------------------
    local answer="$1"
    local msg_file="$2"
    local tmp_file

    tmp_file="$(mktemp "$(dirname "${msg_file}")/.XXXXXX")" || return 1
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

exit codes:
  the hook path (bare MSG_FILE invocation) always exits 0, even on internal
  failure, since a broken generator must never block a commit; --verify is
  the sole command that exits non-zero, since it is a manual preflight check
  with no commit at risk
"


# takes Git's prepare-commit-msg contract: $1 msg-file, $2 source, $3 commit;
# fails open by design — every internal error here is logged to stderr and
# swallowed into a 0 exit, so a broken generator never blocks a commit;
# --verify is the one command in this script allowed to exit non-zero
run_hook() {  # ----------------------------------------------------------------
    local msg_file="$1"
    local source="${2-}"
    local diff answer

    if ! is_generation_allowed "${source}"; then
        return 0  # a deliberate skip is a success
    fi

    if ! check_dependencies; then
        printf 'skipping generation, dependency missing' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        return 0
    fi

    if ! diff="$(read_staged_diff)"; then
        printf 'skipping generation, could not read staged diff' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        return 0
    fi

    if [[ -z "${diff}" ]]; then
        return 0  # nothing staged, nothing to describe
    fi

    if ! answer="$(generate_message "${diff}")"; then
        printf 'skipping generation, message generation failed' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        return 0
    fi

    if ! write_message_file "${answer}" "${msg_file}"; then
        printf 'skipping generation, could not write message file' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        return 0
    fi

    printf 'done' | kamilog logger "done" "${LOGGER_ROOT}" >&2
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
        --)
            shift  # explicit hook path
            if (($# > 0)); then
                is_hook_path=true
            fi
            ;;
        ""|-*)
            # empty: no message file, generation is impossible, fall to usage
            # dash-prefixed: unknown mode, log then fall to usage
            if [[ -n "${1-}" ]]; then
                printf 'unknown mode: %s' "$1" \
                    | kamilog logger error "${LOGGER_ROOT}" >&2
            fi
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
