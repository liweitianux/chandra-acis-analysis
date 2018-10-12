# Copyright (c) 2017-2018 Weitian LI <wt@liwt.net>
# MIT license

import re


# The base directory has the format: <name>_oi<obsid>
RE_BASEDIR = re.compile(r"^.*/(?P<name>[^/_]+)_oi(?P<obsid>\d+).*$")


def get_name_from_path(path):
    """
    Extract the object name from the directory path.

    Parameters
    ----------
    path : str
        Path to the base directory

    Returns
    -------
    objname : str
        The name part of the base directory
    """
    return RE_BASEDIR.match(path).group("name")


def get_obsid_from_path(path):
    """
    Extract the observation ID from the directory path.

    Parameters
    ----------
    path : str
        Path to the base directory

    Returns
    -------
    obsid : int
        The observation ID of the data
    """
    return int(RE_BASEDIR.match(path).group("obsid"))
