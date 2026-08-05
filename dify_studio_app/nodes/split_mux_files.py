# pylint: disable=missing-module-docstring


import re

# output keys  #################################################################

OUTPUT_SKIP_PRIMARY = "skip_primary_message"
OUTPUT_PER_FILE_DIFF = "per_file_diff"
OUTPUT_FILENAMES = "filenames"


# constants  ###################################################################
DIFF_GIT = "diff --git"
REGEX_PATTERN = r".+\/(.+)"


# Entry Point  #################################################################
def main(content: str):
    """
    perform pre-process directly on inputs:

    - split the full diff content per file
    - extract each file's name, ordered the same as ``per_file_diff``
    - decide if there is only one file change, to skip the primary message


    :param content:
    :type content: str
    :return: {
        "skip_primary_message": if the given content contains only single file
        "per_file_diff": a list of all files' diff content
        "filenames": a list of all files' name
    }
    :rtype: dict{
        "skip_primary_message": bool
        "per_file_diff": list[str]
        "filenames": list[str]
    }
    """
    per_file_diff = []
    filenames = []

    for segment in content.split(DIFF_GIT)[1:]:
        per_file_diff.append(DIFF_GIT + segment)
        filenames.append(re.match(REGEX_PATTERN, segment).group(1))

    skip_primary_message = len(per_file_diff) == 1

    return {
        OUTPUT_SKIP_PRIMARY: skip_primary_message,
        OUTPUT_PER_FILE_DIFF: per_file_diff,
        OUTPUT_FILENAMES: filenames,
    }
