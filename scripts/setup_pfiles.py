# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license
#
# Weitian LI
# 2017-02-06

"""
Prepare the CIAO parameter files and setup the PFILES environment
variable to keep the pfiles locally, in order to avoid the conflicts
between multiple instance of the same CIAO tools.
"""

import os
import subprocess
import shutil


def setup_pfiles(tools):
    """
    Copy the parameter files of the specified tools to the current
    working directory, and setup the ``PFILES`` environment variable.

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
        shutil.copy(pfile, ".")
    # Setup the ``PFILES`` environment variable
    os.environ["PFILES"] = "./:" + os.environ["PFILES"]
