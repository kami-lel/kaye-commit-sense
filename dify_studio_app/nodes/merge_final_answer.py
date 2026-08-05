# pylint: disable=missing-module-docstring


# output keys  #################################################################
OUTPUT_ANSWER = "answer"


# input keys  ##################################################################
KEY_SIGIL = "sigil"
KEY_MESSAGE = "message"


# constants  ###################################################################
ANSWER_TEMPLATE = "{}\n\n{}"


# auxiliaries  #################################################################


def _format_line(sigil, filename, message):
    """
    :return: formatted sigil/filename/message line
    :rtype: str
    """
    if message:
        line = "{}`{}` {}".format(sigil, filename, message)
    else:
        line = "{}`{}`".format(sigil, filename)

    return line


def _merge_single(filenames, per_file_extracts):
    """
    merge the answer for the single-file, no-primary-message scenario
    """
    filename = filenames[0]
    file_extract = per_file_extracts[0]
    sigil = file_extract[KEY_SIGIL]
    message = file_extract[KEY_MESSAGE]

    filename_line = _format_line(sigil, filename, "")

    return ANSWER_TEMPLATE.format(message, filename_line)


def _merge_multiple(filenames, per_file_extracts, primary_message):
    """
    merge the answer for the multiple-file, with-primary-message scenario
    """
    lines = []
    for filename, file_extract in zip(filenames, per_file_extracts):
        sigil = file_extract[KEY_SIGIL]
        message = file_extract[KEY_MESSAGE]
        line = _format_line(sigil, filename, message)
        lines.append(line)

    return ANSWER_TEMPLATE.format(primary_message, "\n".join(lines))


# Entry Point  #################################################################
def main(
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
        answer = _merge_single(filenames, per_file_extracts)
    else:
        answer = _merge_multiple(filenames, per_file_extracts, primary_message)

    return {OUTPUT_ANSWER: answer}
