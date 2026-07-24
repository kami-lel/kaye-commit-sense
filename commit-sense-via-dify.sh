#!/usr/bin/env bash
#
################################################################################
# commit-sense-via-dify.sh
#
# generate a Git commit message from the staged diff, through a Dify app
################################################################################
set -euo pipefail


# help  ########################################################################
readonly USAGE_TEXT="\
commit-sense-via-dify.sh

generate a Git commit message from the staged diff, through a Dify app.

usage:
  ./commit-sense-via-dify.sh <msg-file> [<source> [<commit>]]
                            run as a prepare-commit-msg hook
  ~~ --verify               check dependencies, settings, and backend
  ~~ --help|--version       print help/version

environment:
  DIFY_API_KEY                    required; the Dify Service API key
  DIFY_BASE_URL                   required; the Dify Service API address
  DIFY_USER                       optional; the author reported to Dify
  COMMIT_SENSE_SKIP               any non-empty value skips generation
"


# constants  ###################################################################
readonly VERSION="0.1.0"
readonly DEFAULT_USER="user"
readonly -a REQUIRED_COMMANDS=(git curl)


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
        printf 'commit-sense-via-dify.sh: error: missing command: %s\n' \
            "${missing[*]}" >&2
        return 1
    fi
}


# fills DIFY_API_KEY, DIFY_BASE_URL, DIFY_USER; the key is never printed
resolve_config() {  ############################################################
    DIFY_API_KEY="${DIFY_API_KEY-}"
    if [[ -z "${DIFY_API_KEY}" ]]; then
        printf 'commit-sense-via-dify.sh: error: DIFY_API_KEY is not set\n' >&2
        return 1
    fi

    DIFY_BASE_URL="${DIFY_BASE_URL-}"
    if [[ -z "${DIFY_BASE_URL}" ]]; then
        printf 'commit-sense-via-dify.sh: error: DIFY_BASE_URL is not set\n' >&2
        return 1
    fi
    DIFY_BASE_URL="${DIFY_BASE_URL%/}"  # drop a trailing slash

    DIFY_USER="${DIFY_USER:-${DEFAULT_USER}}"
}


run_verify() {  ################################################################
    # TODO implement the preflight check
    return 0
}


# hook  ########################################################################
# takes Git's prepare-commit-msg contract: $1 msg-file, $2 source, $3 commit
run_hook() {
    # TODO implement the generation path
    return 0
}


# Entry Point  #################################################################
main() {
    local is_hook_path=false
    # BUG mpv branch structure

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
            printf 'commit-sense-via-dify.sh: unknown mode: %s\n' "$1" >&2
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
