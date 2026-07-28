# pylint: disable=missing-module-docstring


import re

# output keys  #################################################################

OUTPUT_SKIP_PRIMARY = "skip_primary_message"
OUTPUT_ALLOWS_MD_API = "allows_md_query_value"
OUTPUT_PER_FILE_DIFF = "per_file_diff"
OUTPUT_FILENAMES = "filenames"


# constants  ###################################################################
DIFF_GIT = "diff --git"
REGEX_PATTERN = r".+\/(.+)"


# Entry Point  #################################################################
def main(content: str, allows_md: bool):
    """
    perform pre-process directly on inputs:

    - split the full diff content per file
    - extract each file's name, ordered the same as ``per_file_diff``
    - decide if there is only one file change, to skip the primary message
    - pass through ``allows_md`` as ``1/2`` as URL query parameter value


    :param content:
    :type content: str
    :param allows_md:
    :type allows_md: bool
    :return: {
        "skip_primary_message": if the given content contains only single file
        "allows_md_query_value": old query value of ``allows_md_number``
        "per_file_diff": a list of all files' diff content
        "filenames": a list of all files' name
    }
    :rtype: dict{
        "skip_primary_message": bool
        "allows_md_query_value": int
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
        OUTPUT_ALLOWS_MD_API: 1 if allows_md else 0,
        OUTPUT_PER_FILE_DIFF: per_file_diff,
        OUTPUT_FILENAMES: filenames,
    }
