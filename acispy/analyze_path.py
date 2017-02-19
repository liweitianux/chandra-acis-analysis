# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license
#
# Weitian LI
# 2017-02-06

"""
Extract the object name and observation ID from the directory path.

The root directory of the object data has the format:
    <name>_oi<obsid>
"""

import re


RE_DATA_DIR = re.compile(r"^.*/(?P<name>[^/_]+)_oi(?P<obsid>\d+).*$")


def get_name(path):
    """
    Extract the object name from the directory path.

    Parameters
    ----------
    path : str
        Path to the data directory

    Returns
    -------
    objname : str
        The name part of the data directory
    """
    return RE_DATA_DIR.match(path).group("name")


def get_obsid(path):
    """
    Extract the observation ID from the directory path.

    Parameters
    ----------
    path : str
        Path to the data directory

    Returns
    -------
    obsid : int
        The observation ID of the data
    """
    return int(RE_DATA_DIR.match(path).group("obsid"))
