# pylint: disable=missing-module-docstring
# pylint: disable=invalid-name


# output keys  #################################################################
OUTPUT_OPT_OBJ = "opt_obj"


# constants  ###################################################################

SIGIL_ADD_SHORT = "+"
SIGIL_DEL_SHORT = "-"
SIGIL_BALANCED_SHORT = "*"
SIGIL_ADD_LONG = "/"
SIGIL_DEL_LONG = "\\"
SIGIL_BALANCED_LONG = "|"

VALID_SIGILS = frozenset("?^!:=.@#~*")


# auxiliaries  ##################################################################
def _resolve_ordinary_sigil(
    LONG_SHORT_THRESHOLD, ADD_DEL_BALANCE_TOLERANCE, per_file_diff
):
    """
    resolve the ordinary-edit sigil for a diff, from its add/delete
    balance and its long/short form


    :return: the resolved ordinary-edit sigil
    :rtype: str
    """
    added = 0
    deleted = 0

    for line in per_file_diff.split("\n"):
        if line.startswith("+++") or line.startswith("---"):
            continue
        if line.startswith("+"):
            added += 1
        elif line.startswith("-"):
            deleted += 1

    is_long = per_file_diff.count("\n") > LONG_SHORT_THRESHOLD
    largest = max(added, deleted, 1)
    is_balanced = abs(added - deleted) <= ADD_DEL_BALANCE_TOLERANCE * largest

    if is_balanced:
        return SIGIL_BALANCED_LONG if is_long else SIGIL_BALANCED_SHORT
    if added > deleted:
        return SIGIL_ADD_LONG if is_long else SIGIL_ADD_SHORT
    return SIGIL_DEL_LONG if is_long else SIGIL_DEL_SHORT


# Entry Point  #################################################################
def main(
    LONG_SHORT_THRESHOLD, ADD_DEL_BALANCE_TOLERANCE, per_file_diff, llm_message
):
    """
    perform post-process directly on the LLM's per-file output:

    - split ``llm_message`` into its sigil line and summary line
    - when the sigil is not a valid single-character sigil, resolve
      the real sigil from ``per_file_diff``'s add/delete balance and
      length against ``LONG_SHORT_THRESHOLD``


    :param LONG_SHORT_THRESHOLD: newline-count cutoff above which a
            diff is classified as long rather than short
    :type LONG_SHORT_THRESHOLD: float
    :param per_file_diff:
    :type per_file_diff: str
    :param llm_message:
    :type llm_message: str
    :return: {
        "opt_obj": the resolved sigil and message for this file
    }
    :rtype: dict{
        "opt_obj": dict{"sigil": str, "message": str}
    }
    """
    sigil, _, message = llm_message.strip("\n").partition("\n")
    sigil = sigil.strip()
    message = message.strip()

    if not (len(sigil) == 1 and sigil in VALID_SIGILS):
        sigil = _resolve_ordinary_sigil(
            LONG_SHORT_THRESHOLD, ADD_DEL_BALANCE_TOLERANCE, per_file_diff
        )

    opt_obj = {"sigil": sigil, "message": message}

    return {OUTPUT_OPT_OBJ: opt_obj}
