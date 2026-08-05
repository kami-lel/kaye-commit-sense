# pylint: disable=missing-module-docstring
# pylint: disable=invalid-name


# output keys  #################################################################
OUTPUT_OPT_OBJ = "opt_obj"


# constants  ###################################################################

# ordinary-edit sigils, indexed by add/delete lean: addition, balanced, deletion
SIGILS_SHORT = ("🟢", "🟡", "🔴")
SIGILS_LONG = ("🟩", "🟨", "🟥")

# special-case sigils the LLM may emit directly
VALID_SIGILS = frozenset((
    "🔢",
    "📄",
    "🗑️",
    "📂",
    "📛",
    "🔒",
    "📏",
    "🔖",
    "📝",
    "♻️",
    "🤖",
    "🧪",
    "🧸",
    "⚙️",
    "🔰",
    "🪧",
    "🪵",
    "📖",
))

# add/delete lean knobs  =======================================================

# imaginary lines credited to both sides, swamping low-volume counts
LEAN_PSEUDOCOUNT = 2

# integer form of the log-odds cut: 12/5 = 2.4 approximates exp(0.85)
LEAN_CUT_HIGH = 12
LEAN_CUT_LOW = 5


# auxiliaries  #################################################################
def _decide_add_del_balance(added, deleted):
    """
    see ``docs/diff-shape-classification.md``

    :return: which way the diff leans, judging the add/delete gap
            by smoothed log-odds, with the pure cases short-circuited:
            0 addition, 1 balanced, 2 deletion
    :rtype: int
    """
    assert added or deleted, "an empty diff has no lean"

    if deleted == 0:
        return 0
    if added == 0:
        return 2

    smoothed_added = added + LEAN_PSEUDOCOUNT
    smoothed_deleted = deleted + LEAN_PSEUDOCOUNT

    # mutually exclusive, so their order is immaterial
    if LEAN_CUT_LOW * smoothed_added > LEAN_CUT_HIGH * smoothed_deleted:
        return 0
    if LEAN_CUT_LOW * smoothed_deleted > LEAN_CUT_HIGH * smoothed_added:
        return 2
    return 1


def _resolve_ordinary_sigil(LONG_SHORT_THRESHOLD, per_file_diff):
    """
    :return: ordinary-edit sigil for the diff,
            resolved from its add/delete balance and its long/short form
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
    lean = _decide_add_del_balance(added, deleted)

    symbol = SIGILS_LONG[lean] if is_long else SIGILS_SHORT[lean]

    return symbol


# Entry Point  #################################################################
def main(
    LONG_SHORT_THRESHOLD, ADD_DEL_BALANCE_TOLERANCE, per_file_diff, llm_message
):
    """
    perform post-process directly on the LLM's per-file output:

    - split ``llm_message`` into its sigil line and summary line
    - when the sigil is not one of the recognized special-case sigils, resolve
      the real sigil from ``per_file_diff``'s add/delete balance and
      length against ``LONG_SHORT_THRESHOLD``


    :param LONG_SHORT_THRESHOLD: newline-count cutoff above which a
            diff is classified as long rather than short
    :type LONG_SHORT_THRESHOLD: float
    :param ADD_DEL_BALANCE_TOLERANCE: unused, retained so the node's
            declared inputs keep matching this signature
    :type ADD_DEL_BALANCE_TOLERANCE: float
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

    if sigil not in VALID_SIGILS:
        sigil = _resolve_ordinary_sigil(LONG_SHORT_THRESHOLD, per_file_diff)

    opt_obj = {"sigil": sigil, "message": message}

    return {OUTPUT_OPT_OBJ: opt_obj}
