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
generate a Git commit message from the staged diff, through a Dify app.

usage:
  commit-sense-via-dify.sh <msg-file> [<source> [<commit>]]
                                                run as a prepare-commit-msg hook
  commit-sense-via-dify.sh --verify             check dependencies, settings, and backend
  commit-sense-via-dify.sh [--help|--version]   print help/version

environment:
  DIFY_API_KEY                    required; the Dify Service API key
  DIFY_BASE_URL                   optional; overrides the base address
  DIFY_USER                       optional; identifies the author to Dify
  COMMIT_SENSE_SKIP               any non-empty value skips generation"


# constants  ###################################################################
readonly VERSION="0.1.0"
readonly PROGRAM_NAME="commit-sense-via-dify.sh"


print_usage() {  ###############################################################
  printf '%s\n\n%s\n' "${PROGRAM_NAME}" "${USAGE_TEXT}"
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

  case "${1-}" in  # -----------------------------------------------------------
    --verify)
      run_verify
      return
      ;;
    --help)  # -----------------------------------------------------------------
      print_usage
      return 0
      ;;
    --version)  # --------------------------------------------------------------
      printf '%s\n' "${VERSION}"
      return 0
      ;;
    "")  # ---------------------------------------------------------------------
      # no message file, so generation is impossible; fall to the usage
      ;;
    --)  # explicit hook path
      shift
      if (($# > 0)); then
        is_hook_path=true
      fi
      ;;
    -*)  # ---------------------------------------------------------------------
      printf '%s: unknown mode: %s\n' "${PROGRAM_NAME}" "$1" >&2
      ;;
    *)  # ----------------------------------------------------------------------
      # implicit hook path; Git never passes a leading-dash msg-file
      is_hook_path=true
      ;;
  esac

  if [[ "${is_hook_path}" == true ]]; then
    run_hook "$@"
    return
  fi

  print_usage >&2
  return 2
}

# run only when executed, so the tests can source this file
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
