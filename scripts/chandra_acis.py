#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license
#
# Weitian LI
# 2017-02-06

"""
Determine the Chandra ACIS type for the given observation.

TODO: move these methods to module `acis.py`
"""

import argparse
import subprocess
import re

from setup_pfiles import setup_pfiles


def get_acis_type(filepath):
    """
    Determine the Chandra ACIS type (``I`` or ``S``) according the
    active ACIS chips.

    Parameters
    ----------
    filepath : str
        Path to the input FITS file

    Returns
    -------
    acis_type : str
        ``I`` if ACIS-I, ``S`` if ACIS-S, otherwise, ``ValueError`` raised.
    """
    subprocess.check_call(["punlearn", "dmkeypar"])
    detnam = subprocess.check_output([
        "dmkeypar", "infile=%s" % filepath, "keyword=DETNAM", "echo=yes"
    ]).decode("utf-8").strip()
    if re.match(r"^ACIS-0123", detnam):
        return "I"
    elif re.match(r"^ACIS-[0-6]*7", detnam):
        return "S"
    else:
        raise ValueError("unknown chip combination: %s" % detnam)


def get_chips(filepath, sep=":"):
    """
    Get the corresponding chips of interest according to the active ACIS type.

    Parameters
    ----------
    filepath : str
        Path to the input FITS file
    sep : str, optional
        Separator to join the chip ranges, e.g., 0:3, 0-3

    Returns
    -------
    chips : str
        ``0:3`` if ACIS-I, ``7`` if ACIS-S, otherwise, ``ValueError`` raised.
    """
    acis_type = get_acis_type(filepath)
    if acis_type == "I":
        return sep.join(["0", "3"])
    elif acis_type == "S":
        return "7"
    else:
        raise ValueError("unknown ACIS type")


def main():
    parser = argparse.ArgumentParser(description="Determine Chandra ACIS type")
    parser.add_argument("-b", "--brief", dest="brief",
                        action="store_true", help="Be brief")
    parser.add_argument("infile", help="Input FITS file")
    args = parser.parse_args()

    setup_pfiles(["dmkeypar"])
    acis_type = get_acis_type(args.infile)
    if not args.brief:
        print("ACIS-type:", end=" ")
    print(acis_type)


if __name__ == "__main__":
    main()
