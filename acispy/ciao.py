# Copyright (c) 2017-2018 Weitian LI <wt@liwt.net>
# MIT license

import os
import subprocess
import shutil


def setup_pfiles(tools):
    """
    Copy the parameter files of the specified tools to the current
    working directory, and setup the ``PFILES`` environment variable.
    By perferring the local copy of parameter files, the conflicts
    when running multiple instance of the same CIAO tools can be avoided.

    Parameters
    ----------
    tools : list[str]
        Name list of the tools to be set up
    """
    for tool in tools:
        pfile = subprocess.check_output([
            "paccess", tool
        ]).decode("utf-8").strip()
        subprocess.check_call(["punlearn", tool])
        try:
            shutil.copy(pfile, ".")
        except shutil.SameFileError:
            pass

    # Update the ``PFILES`` environment variable to prefer the local copy
    os.environ["PFILES"] = "./:" + os.environ["PFILES"]
