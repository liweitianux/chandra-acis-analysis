# Copyright (c) 2017-2018 Weitian LI <wt@liwt.net>
# MIT license

import os
import subprocess
import shutil
import logging


logger = logging.getLogger(__name__)


def run_command(tool, args, capture_stdout=True, check=True):
    """
    Clear and then run the CIAO tool with the arguments.

    Parameters
    ----------
    tool : str
        Name of the CIAO tool.
    args : list[str]
        List of arguments for the tool.
    capture_stdout : bool
        Capture the standard output of the command and return.
    check : bool
        Do not ignore the command failure if ``check=True``.

    Returns
    -------
    stdout : str
        Decoded standard output of the command if ``capture_stdout=True``.
    """
    subprocess.run(['punlearn', tool], check=check)
    cmd = [tool] + args
    logger.info('Run command: %s' % ' '.join(cmd))
    stdout = subprocess.PIPE if capture_stdout else None
    p = subprocess.run(cmd, check=check, stdout=stdout)
    try:
        return p.stdout.decode('utf-8').strip()
    except AttributeError:
        return None


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
