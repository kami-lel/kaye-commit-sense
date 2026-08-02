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
readonly VERSION="1.1.1"


################################################################################
# kamilog_shim
# shipped with kamilog v2.9.1
#
# lets scripts call `kamilog` safely even when it is not installed
# Q.v. https://github.com/kami-lel/kamilog
################################################################################
_KAMILOG_BIN="$(type -P kamilog 2>/dev/null || true)"

kamilog() {
    if [ -n "$_KAMILOG_BIN" ]; then
        "$_KAMILOG_BIN" "$@"
        return
    fi
    input="$(cat; printf x)";
    input="${input%x}"   # keep trailing \n from being stripped
    case "$1" in
        cb|cb0)
            printf '# %s' "$input"
            ;;
        logger)
            printf '%s:\t%s' "$2" "$input"
            ;;
        *)
            printf '%s' "$input"  # no bin found, pass stdin through as-is
            ;;
    esac
}
# END of kamilog_shim  #########################################################


################################################################################
# throb-widget.sh v1.0.0
#
# single-character pulsing animation, source this file or copy it inline
# q.v. https://github.com/kami-lel/throb-widget
################################################################################

THROB_WIDGET_FRAMES_PULSE=('░' '▒' '▓' '█' '▓' '▒')
THROB_WIDGET_FRAMES_PULSE_ASCII=('.' 'o' 'O' '@' 'O' 'o')
throb_widget_idx=${throb_widget_idx:-0}
# preserve a live pid across re-sourcing; clear it only if it is unset or
# no longer running, so throb_widget_stop never targets a dead process
if [[ -z "${throb_widget_pid:-}" ]] \
        || ! kill -0 "${throb_widget_pid}" 2>/dev/null; then
    throb_widget_pid=""
fi
throb_widget_charset_override=""  # "unicode", "ascii", or empty for auto-detect
# set once per shell so re-sourcing or restarting never chains duplicate traps
throb_widget_traps_set=${throb_widget_traps_set:-0}

throb_widget_chain_trap() {
    local cmd="$1" sig="$2" existing

    existing="$(trap -p "${sig}")"
    if [[ -n "${existing}" ]]; then
        existing="${existing#trap -- \'}"
        existing="${existing%\'*}"
        trap "${cmd}; ${existing}" "${sig}"
    else
        trap "${cmd}" "${sig}"
    fi
}

throb_widget_get_frame() {
    local -a frames
    local loc="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"

    if [[ "${throb_widget_charset_override}" == "unicode" ]] \
        || { [[ -z "${throb_widget_charset_override}" ]] \
            && [[ "${loc}" == *UTF-8* || "${loc}" == *utf8* ]]; }; then
        frames=("${THROB_WIDGET_FRAMES_PULSE[@]}")
    else
        frames=("${THROB_WIDGET_FRAMES_PULSE_ASCII[@]}")
    fi

    printf '%s' "${frames[throb_widget_idx]}"
    throb_widget_idx=$(( (throb_widget_idx + 1) % ${#frames[@]} ))
    return 0
}


# Public API  ==================================================================

# throb_widget_start()
#
# start the throb, drawing one frame per interval on stderr
#
# draws inline at the cursor's current column, backing up one column before
# each frame after the first, and keeps running until throb_widget_stop runs
# or the caller's process exits, whichever comes first. calling this while a
# throb already runs is a no-op
#
# USAGE:
#   throb_widget_start [-u | -U] [INTERVAL]
#
# OPTION:
#   -u  force the Unicode frame set, regardless of locale detection
#   -U  force the ASCII frame set, regardless of locale detection
#
# ARGUMENT:
#   [INTERVAL]  positive seconds between frames, default 0.2
throb_widget_start() {  # ------------------------------------------------------
    local OPTIND=1 opt charset_override=""

    while getopts "uU" opt; do
        case "${opt}" in
            u) charset_override="unicode" ;;
            U) charset_override="ascii" ;;
            *) return 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    local interval="${1:-0.2}"

    if [[ ! -t 2 ]]; then
        return 0  # stderr isn't a terminal, nothing to draw the throb onto
    fi

    if [[ -n "${throb_widget_pid}" ]]; then
        return 0  # throb already running
    fi

    throb_widget_charset_override="${charset_override}"
    if (( ! throb_widget_traps_set )); then
        throb_widget_chain_trap "throb_widget_stop" EXIT
        throb_widget_chain_trap "throb_widget_stop; exit 130" INT
        throb_widget_chain_trap "throb_widget_stop; exit 143" TERM
        throb_widget_traps_set=1
    fi

    local owner="${BASHPID:-$$}"  # caller's process, the loop's lifetime bound
    local was_monitor=0
    [[ "$-" == *m* ]] && was_monitor=1
    set +m

    (
        local first_frame=1
        while kill -0 "${owner}" 2>/dev/null; do
            if (( ! first_frame )); then
                printf '\b'  # back up onto the previous frame's column
            fi
            first_frame=0
            throb_widget_get_frame
            sleep "${interval}"
        done
    ) >&2 &
    throb_widget_pid=$!
    disown

    (( was_monitor )) && set -m
    return 0
}

# throb_widget_stop()
#
# stop the throb and erase its last drawn frame
#
# does nothing when no throb is running. the cursor is left exactly where the
# frame was drawn, now blank, so the caller's next write picks up right there
#
# USAGE:
#   throb_widget_stop
#
# OUTPUT:
#   a backspace, a space, then a backspace, to stderr
throb_widget_stop() {  # -------------------------------------------------------
    if [[ -z "${throb_widget_pid}" ]]; then
        return 0  # no throb running
    fi
    kill "${throb_widget_pid}" 2>/dev/null || true
    wait "${throb_widget_pid}" 2>/dev/null || true
    printf '\b \b' >&2
    throb_widget_pid=""
    return 0
}

# END of throb-widget.sh  ######################################################


export GIT_PAGER=cat PAGER=cat
readonly LOGGER_ROOT="KCSH"  # every section without a name of its own


# verification  ################################################################
# answers one question: can this machine run at all

# every command the run depends on
readonly -a REQUIRED_COMMANDS=(git curl jq mktemp)

# probed when `command -v` fails, eg under a minimal-PATH GUI environment
readonly -a FALLBACK_BIN_DIRS=(/usr/bin /usr/local/bin /opt/homebrew/bin /bin)

# bare names by default; check_dependencies resolves each to an absolute
# path, so sourcing without it first (eg the demos) still finds them on PATH
GIT_BIN="git"
CURL_BIN="curl"
JQ_BIN="jq"
MKTEMP_BIN="mktemp"

# optional backstop beyond --max-time; GNU-only, degrades to curl alone
_TIMEOUT_BIN="$(command -v timeout 2>/dev/null || true)"

# resolve_dependency()
#
# resolve a command name to an absolute path, into the named variable
resolve_dependency() {  # ------------------------------------------------------
    local -r cmd="$1"
    local -r var_name="$2"
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
        printf '%s not found on PATH or in %s\n' \
            "${cmd}" "${FALLBACK_BIN_DIRS[*]}" \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        return 1
    fi

    printf -v "${var_name}" '%s' "${resolved}"
    # printf '%s resolved: %s\n' "${cmd}" "${resolved}" \
    #     | kamilog logger succ "${LOGGER_ROOT}" >&2
    return 0
}

# check_dependencies()
#
# resolve every required command into its own path variable
check_dependencies() {  # ------------------------------------------------------
    local cmd var_name
    local -a missing=()

    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        case "${cmd}" in
        git) var_name="GIT_BIN" ;;
        curl) var_name="CURL_BIN" ;;
        jq) var_name="JQ_BIN" ;;
        mktemp) var_name="MKTEMP_BIN" ;;
        esac
        if ! resolve_dependency "${cmd}" "${var_name}"; then
            missing+=("${cmd}")
        fi
    done

    if ((${#missing[@]} > 0)); then
        printf 'missing command: %s\n' "${missing[*]}" \
            | kamilog logger fail "${LOGGER_ROOT}" >&2
        return 1
    fi

    # printf 'dependencies verified\n' \
    #     | kamilog logger pass "${LOGGER_ROOT}" >&2
    return 0
}


# check_hook_installation()
#
# report the interpreter, dependency, and hook-install paths; advisory only
check_hook_installation() {  # -------------------------------------------------
    local hooks_dir bash_bin file

    bash_bin="$(type -P bash 2>/dev/null || true)"
    printf 'interpreter: %s\n' "${bash_bin:-not found}" \
        | kamilog logger info "${LOGGER_ROOT}" >&2
    printf 'dependency paths: git=%s curl=%s jq=%s mktemp=%s\n' \
        "${GIT_BIN}" "${CURL_BIN}" "${JQ_BIN}" "${MKTEMP_BIN}" \
        | kamilog logger info "${LOGGER_ROOT}" >&2

    hooks_dir="$("${GIT_BIN}" rev-parse --git-path hooks 2>/dev/null || true)"
    if [[ -z "${hooks_dir}" ]]; then
        printf 'could not resolve the active hooks directory\n' \
            | kamilog logger warning "${LOGGER_ROOT}" >&2
        return 0
    fi
    printf 'active hooks directory: %s\n' "${hooks_dir}" \
        | kamilog logger info "${LOGGER_ROOT}" >&2

    for file in prepare-commit-msg kaye-commit-sense-hook.sh; do
        if [[ -x "${hooks_dir}/${file}" ]]; then
            printf '%s installed and executable\n' "${file}" \
                | kamilog logger pass "${LOGGER_ROOT}" >&2
        else
            printf '%s not installed or not executable at %s\n' \
                "${file}" "${hooks_dir}" \
                | kamilog logger warning "${LOGGER_ROOT}" >&2
        fi
    done
    return 0
}


# identifies the caller to the Dify app when nothing better is found
readonly DIFY_USERNAME_FALLBACK="user"

# names where the resolved identifier came from; for --verify to report
dify_username_source=""


# resolve_dify_username()
#
# resolve the caller identifier, and the name of the source it came from
resolve_dify_username() {  # ---------------------------------------------------
    local value

    KCSH_DIFY_USERNAME="${KCSH_DIFY_USERNAME-}"
    if [[ -n "${KCSH_DIFY_USERNAME}" ]]; then
        dify_username_source="KCSH_DIFY_USERNAME"
        return 0
    fi

    # an unset key is ordinary here, and `git config` exits non-zero on it
    value="$("${GIT_BIN}" config --get user.email 2>/dev/null || true)"
    if [[ -n "${value}" ]]; then
        KCSH_DIFY_USERNAME="${value}"
        dify_username_source="git config user.email"
        return 0
    fi

    KCSH_DIFY_USERNAME="${DIFY_USERNAME_FALLBACK}"
    dify_username_source="fallback"
    return 0
}


# resolve_config()
#
# load and validate every KCSH_ setting; the secret key is never printed
resolve_config() {  # ----------------------------------------------------------
    local has_error=false

    KCSH_DIFY_SERVICE_API_ENDPOINT="${KCSH_DIFY_SERVICE_API_ENDPOINT-}"
    if [[ -z "${KCSH_DIFY_SERVICE_API_ENDPOINT}" ]]; then
        printf 'KCSH_DIFY_SERVICE_API_ENDPOINT unset\n' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        has_error=true
    fi

    KCSH_DIFY_SERVICE_API_SECRET_KEY="${KCSH_DIFY_SERVICE_API_SECRET_KEY-}"
    if [[ -z "${KCSH_DIFY_SERVICE_API_SECRET_KEY}" ]]; then
        printf 'KCSH_DIFY_SERVICE_API_SECRET_KEY unset\n' \
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
    resolve_dify_username
    return 0
}


# is_md_syntax_disabled()
#
# normalize KCSH_DISABLE_MD_SYNTAX into a lowercase jq boolean
is_md_syntax_disabled() {  # ---------------------------------------------------
    case "${KCSH_DISABLE_MD_SYNTAX}" in
    [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss]) printf 'true' ;;
    *) printf 'false' ;;
    esac
    return 0
}


# run_verify()
#
# check the dependencies, the configuration, and the backend
#
# preflight for a manual run: it writes no commit message and touches no
# file, and it is the one command in this script allowed to exit non-zero,
# since no commit is ever at risk behind it
#
# OUTPUT:
#   log every check, and the closing verdict, to stderr
#
# RETURN:
#   0  everything verified
#   1  a dependency, configuration, or backend check failed
#
# EXAMPLE:
#   ./kaye-commit-sense-hook.sh --verify
run_verify() {  # --------------------------------------------------------------
    local mode info
    local -i exit_code=0

    printf 'verifying environment\n' \
        | kamilog logger enter "${LOGGER_ROOT}" >&2

    # later checks parse JSON and call curl, so this one gates the rest
    if ! check_dependencies; then
        return 1
    fi

    check_hook_installation

    if ! resolve_config; then
        printf 'config incomplete\n' \
            | kamilog logger fail "${LOGGER_ROOT}" >&2
        exit_code=1
    else
        printf 'api endpoint: %s\n' "${KCSH_DIFY_SERVICE_API_ENDPOINT}" \
            | kamilog logger info "${LOGGER_ROOT}" >&2
        printf 'request timeout: %s second\n' "${KCSH_REQUEST_TIMEOUT_SEC}" \
            | kamilog logger info "${LOGGER_ROOT}" >&2
        if [[ "$(is_md_syntax_disabled)" == true ]]; then
            printf 'markdown syntax: disabled\n' \
                | kamilog logger info "${LOGGER_ROOT}" >&2
        else
            printf 'markdown syntax: enabled\n' \
                | kamilog logger info "${LOGGER_ROOT}" >&2
        fi
        if [[ "${dify_username_source}" == "fallback" ]]; then
            # never fatal; an anonymous caller still gets its message
            printf 'dify username:\t%s\n(no identity found to name you)\n' \
                "${KCSH_DIFY_USERNAME}" \
                | kamilog logger warning "${LOGGER_ROOT}" >&2
        else
            printf 'dify username:\t%s\n(from %s)\n' \
                "${KCSH_DIFY_USERNAME}" "${dify_username_source}" \
                | kamilog logger info "${LOGGER_ROOT}" >&2
        fi
        printf 'config verified\n' \
            | kamilog logger pass "${LOGGER_ROOT}" >&2
    fi

    if ((exit_code != 0)); then
        return "${exit_code}"
    fi

    # -N leaves the line open, so the throb animates in place on it and
    # kamilog is never called again, once per frame
    printf 'reaching Dify App by /info endpoint ' \
        | kamilog logger enter "${LOGGER_ROOT}" -N >&2
    throb_widget_start

    if ! info="$(call_dify_info)"; then
        throb_widget_stop
        printf '\n' >&2
        exit_code=1
    else
        throb_widget_stop
        printf '\n' >&2
        mode="$(extract_json_field "${info}" "mode")"
        if [[ "${mode}" != "advanced-chat" ]]; then
            printf 'app mode is %s, expected advanced-chat\n' "${mode}" \
                | kamilog logger error "${LOGGER_ROOT}" >&2
            exit_code=1
        else
            printf 'app mode is: %s\n' "${mode}" \
                | kamilog logger info "${LOGGER_ROOT}" >&2
            printf 'Dify App reachable\n' \
                | kamilog logger pass "${LOGGER_ROOT}" >&2
        fi
    fi

    if ((exit_code == 0)); then
        printf 'all verified\n' \
            | kamilog logger "done" "${LOGGER_ROOT}" >&2
    fi

    return "${exit_code}"
}


# dify  ########################################################################
# everything crossing the wire, and every way it can fail closed

readonly LOGGER_DIFY="${LOGGER_ROOT}.dify"

# build_chat_request()
#
# build the JSON body of a /chat-messages request; jq handles all escaping
build_chat_request() {  # ------------------------------------------------------
    local -r diff="$1"
    local -r user="$2"
    local -r disable_md_syntax="$3"

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
    return "$?"
}


# extract_answer()
#
# extract the "answer" field from a blocking /chat-messages response
extract_answer() {  # ----------------------------------------------------------
    local -r json="$1"
    "${JQ_BIN}" -r '.answer' <<<"${json}"
    return "$?"
}


# extract_json_field()
#
# extract a top-level string field by name; used for /info's "mode"
extract_json_field() {  # ------------------------------------------------------
    local -r json="$1"
    local -r key="$2"
    "${JQ_BIN}" -r --arg key "${key}" '.[$key]' <<<"${json}"
    return "$?"
}


# call_dify_chat()
#
# post the staged diff to /chat-messages and print the answer
#
# a blocking request that fails closed on a curl error, on a non-2xx
# status, and on a missing or empty answer; `timeout` caps the call
# whenever that binary exists, as a hard backstop for curl ignoring its
# own --max-time
#
# PREREQUISITE:
#   - resolve_config() must have already run, to populate the KCSH_*
#     settings this function reads the endpoint and the key from
#
# USAGE:
#   call_dify_chat DIFF
#
# ARGUMENT:
#   DIFF  staged diff to describe
#
# OUTPUT:
#   print the answer to stdout; log every failure to stderr
#
# RETURN:
#   0  answer received
#   1  the request failed, or the reply carried no answer
call_dify_chat() {  # ----------------------------------------------------------
    local -r diff="$1"
    local body response http_status answer
    local -a runner=()

    body="$(build_chat_request "${diff}" "${KCSH_DIFY_USERNAME}" \
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
        printf 'request to %s failed\n' \
            "${KCSH_DIFY_SERVICE_API_ENDPOINT}/chat-messages" \
            | kamilog logger error "${LOGGER_DIFY}" >&2
        return 1
    fi

    http_status="${response##*$'\n'}"
    response="${response%$'\n'*}"

    if [[ "${http_status}" != 2* ]]; then
        printf 'returned HTTP %s: %s\n' \
            "${http_status}" "${KCSH_DIFY_SERVICE_API_ENDPOINT}/chat-messages" \
            | kamilog logger error "${LOGGER_DIFY}" >&2
        return 1
    fi

    answer="$(extract_answer "${response}")"
    if [[ -z "${answer}" || "${answer}" == "null" ]]; then
        printf 'no answer in Dify reply\n' \
            | kamilog logger error "${LOGGER_DIFY}" >&2
        return 1
    fi

    printf '%s' "${answer}"
    return 0
}


# call_dify_info()
#
# fetch /info and print the reply untouched
#
# fails closed on a curl error and on a non-2xx status; `timeout` caps the
# call whenever that binary exists, exactly as in call_dify_chat
#
# PREREQUISITE:
#   - resolve_config() must have already run, to populate the KCSH_*
#     settings this function reads the endpoint and the key from
#
# USAGE:
#   call_dify_info
#
# OUTPUT:
#   print the raw JSON to stdout; log every failure to stderr
#
# RETURN:
#   0  reply received
#   1  the request failed, or the status was not 2xx
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
        printf 'request to %s failed\n' \
            "${KCSH_DIFY_SERVICE_API_ENDPOINT}/info" \
            | kamilog logger error "${LOGGER_DIFY}" >&2
        return 1
    fi

    http_status="${response##*$'\n'}"
    response="${response%$'\n'*}"

    if [[ "${http_status}" != 2* ]]; then
        printf '%s returned HTTP %s\n' \
            "${KCSH_DIFY_SERVICE_API_ENDPOINT}/info" "${http_status}" \
            | kamilog logger error "${LOGGER_DIFY}" >&2
        return 1
    fi

    printf '%s' "${response}"
    return 0
}


# generate_message()
#
# turn a diff already in hand into a commit message
#
# resolve the configuration, animate a throb while the request is in
# flight, and print whatever the Dify app answers; every log line goes to
# stderr, so stdout carries the message alone
#
# USAGE:
#   generate_message DIFF
#
# ARGUMENT:
#   DIFF  staged diff to describe
#
# OUTPUT:
#   print the commit message to stdout; log progress to stderr
#
# RETURN:
#   0  message generated
#   1  the configuration is incomplete, or the request failed
generate_message() {  # --------------------------------------------------------
    local -r diff="$1"
    local answer

    if ! resolve_config; then
        return 1
    fi

    # logs go to stderr; stdout belongs to the answer alone
    # printf 'requesting Dify (waiting up to %s seconds)\n' \
    #     "${KCSH_REQUEST_TIMEOUT_SEC}" \
    #     | kamilog logger enter "${LOGGER_DIFY}" >&2

    # -N leaves the line open, so the throb animates in place on it and
    # kamilog is never called again, once per frame
    printf 'Kaye Commit Sense generating ' \
        | kamilog logger info "${LOGGER_DIFY}" -N >&2
    throb_widget_start

    if ! answer="$(call_dify_chat "${diff}")"; then
        throb_widget_stop
        printf '\n' >&2
        return 1
    fi
    throb_widget_stop
    printf '\n' >&2

    # printf 'message generated\n' \
    #     | kamilog logger succ "${LOGGER_DIFY}" >&2

    printf '%s' "${answer}"
    return 0
}


# git  #########################################################################
# everything Git hands over, and everything it expects back

readonly LOGGER_GIT="${LOGGER_ROOT}.git"

# is_generation_allowed()
#
# decide whether generation should happen at all, given Git's source argument
is_generation_allowed() {  # ---------------------------------------------------
    local -r source="${1-}"

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


# read_staged_diff()
#
# print the staged diff; empty output means nothing is staged
read_staged_diff() {  # --------------------------------------------------------
    "${GIT_BIN}" diff --cached
    return "$?"
}


# write_message_file()
#
# prepend the generated message above the existing one
#
# write through a temporary file in the message file's own directory, so
# the closing rename is atomic and an interrupted run never leaves a
# half-written commit message behind
#
# PREREQUISITE:
#   - check_dependencies() must have already run, to populate the
#     MKTEMP_BIN path this function invokes
#
# USAGE:
#   write_message_file ANSWER MESSAGE_FILE
#
# ARGUMENT:
#   ANSWER        generated message to place on top
#   MESSAGE_FILE  path Git handed over for the commit message
#
# RETURN:
#   0  message file rewritten
#   1  the temporary file could not be created, written, or renamed
write_message_file() {  # ------------------------------------------------------
    local -r answer="$1"
    local -r msg_file="$2"
    local tmp_file

    tmp_file="$("${MKTEMP_BIN}" "$(dirname "${msg_file}")/.XXXXXX")" || return 1

    if ! { printf '%s\n' "${answer}"; cat "${msg_file}"; } >"${tmp_file}"; then
        rm -f "${tmp_file}"
        return 1
    fi

    mv "${tmp_file}" "${msg_file}"
    return "$?"
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
  KCSH_DIFY_USERNAME                identifies the caller in Dify's logs; optional;
                                    default to use git config user.email
  KCSH_REQUEST_TIMEOUT_SEC          network request timeout, in seconds; optional, default=45
  KCSH_DISABLE_MD_SYNTAX            disables Markdown syntax in the generated message; optional, default=False
  KCSH_ENABLE_SKIPPING              whether skips this hook entirely; optional, default=False

exit codes:
  the hook path (bare MSG_FILE invocation) always exits 0, even on internal
  failure, since a broken generator must never block a commit; --verify is
  the sole command that exits non-zero, since it is a manual preflight check
  with no commit at risk
"


# run_hook()
#
# carry out Git's prepare-commit-msg contract from end to end
#
# fails open by design: every internal error is logged to stderr and
# swallowed into a 0 exit, so a broken generator never blocks a commit,
# and --verify stays the one command allowed to exit non-zero
#
# USAGE:
#   run_hook MESSAGE_FILE [SOURCE [COMMIT]]
#
# ARGUMENT:
#   MESSAGE_FILE  path Git handed over for the commit message
#   [SOURCE]      Git's message source; may suppress generation
#   [COMMIT]      commit object Git passes along; unused here
#
# OUTPUT:
#   log every step, and every swallowed failure, to stderr
#
# RETURN:
#   0  always
run_hook() {  # ----------------------------------------------------------------
    local -r msg_file="$1"
    local -r source="${2-}"
    local diff answer

    if ! is_generation_allowed "${source}"; then
        return 0  # a deliberate skip is a success
    fi

    if ! check_dependencies; then
        printf 'skipping generation, dependency missing\n' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        return 0
    fi

    if ! diff="$(read_staged_diff)"; then
        printf 'skipping generation, could not read staged diff\n' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        return 0
    fi

    if [[ -z "${diff}" ]]; then
        return 0  # nothing staged, nothing to describe
    fi

    if ! answer="$(generate_message "${diff}")"; then
        printf 'skipping generation, message generation failed\n' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        return 0
    fi

    if ! write_message_file "${answer}" "${msg_file}"; then
        printf 'skipping generation, could not write message file\n' \
            | kamilog logger error "${LOGGER_ROOT}" >&2
        return 0
    fi

    printf 'Message Generated\n' | kamilog logger "done" "${LOGGER_ROOT}" >&2
    return 0
}


# main()
#
# dispatch on the first argument
#
# a leading dash selects a mode, and anything else is Git's positional
# contract; an unknown mode, or no argument at all, falls through to the
# usage text
#
# USAGE:
#   main MESSAGE_FILE [SOURCE [COMMIT]]
#
# USAGE:
#   main --verify | --help | --version
#
# ARGUMENT:
#   MESSAGE_FILE  path Git handed over for the commit message
#   [SOURCE]      Git's message source
#   [COMMIT]      commit object Git passes along
#
# OPTION:
#   --verify   check the dependencies, settings, and backend
#   --help     print the usage text
#   --version  print the version string
#
# OUTPUT:
#   print the usage text to stdout for --help, to stderr otherwise
#
# RETURN:
#   0  the selected mode succeeded
#   1  --verify failed one of its checks
#   2  neither a mode nor a message file was given
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
            printf 'unknown mode: %s\n' "$1" \
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
