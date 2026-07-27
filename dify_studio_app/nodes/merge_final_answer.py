# pylint: disable=missing-module-docstring


# output keys  #################################################################
OUTPUT_ANSWER = "answer"


# constants  ###################################################################
KEY_SIGIL = "sigil"
KEY_MESSAGE = "message"

ANSWER_TEMPLATE = "{}\n\n{}"


# auxiliaries  #################################################################


def _merge_single(allows_md, filenames, per_file_extracts):
    """
    merge the answer for the single-file, no-primary-message scenario
    """
    filename = filenames[0]
    file_extract = per_file_extracts[0]
    sigil = file_extract[KEY_SIGIL]
    message = file_extract[KEY_MESSAGE]

    filename_line = ("{}`{}`" if allows_md else "{}[{}]").format(
        sigil, filename
    )

    return ANSWER_TEMPLATE.format(message, filename_line)


def _merge_multiple(allows_md, filenames, per_file_extracts, primary_message):
    """
    merge the answer for the multiple-file, with-primary-message scenario
    """
    line_pattern = "{}`{}` {}" if allows_md else "{}[{}] {}"

    lines = []
    for filename, file_extract in zip(filenames, per_file_extracts):
        sigil = file_extract[KEY_SIGIL]
        message = file_extract[KEY_MESSAGE]
        line = line_pattern.format(sigil, filename, message)
        lines.append(line)

    return ANSWER_TEMPLATE.format(primary_message, "\n".join(lines))


# Entry Point  #################################################################
def main(
    allows_md: bool,
    skip_primary_message: bool,
    filenames: list[str],
    per_file_extracts: list[dict],
    primary_message: str,
):
    """
    merge to produce the final answer, from all per-file extracts

    - when ``skip_primary_message`` is set, only a single file is
      involved, so the answer is the file's message followed by its
      sigil/filename line
    - otherwise, the answer is the primary message followed by one
      line per file, each with its sigil, filename, and message


    :param allows_md: whether utilize md format in final result
    :type allows_md: bool
    :param skip_primary_message: whether only a single file is involved
    :type skip_primary_message: bool
    :param filenames:
    :type filenames: list[str]
    :param per_file_extracts: opt_obj entries, as returned by post_per_file
    :type per_file_extracts: list[dict]
    :param primary_message:
    :type primary_message: str
    :return: {"answer": merged final answer}
    :rtype: dict{"answer": str}
    """
    if skip_primary_message:
        answer = _merge_single(allows_md, filenames, per_file_extracts)
    else:
        answer = _merge_multiple(
            allows_md, filenames, per_file_extracts, primary_message
        )

    return {OUTPUT_ANSWER: answer}
