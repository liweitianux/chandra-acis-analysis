#!/usr/bin/env python3
#
# Copyright (c) 2017-2018 Weitian LI <wt@liwt.net>
# MIT license
#

"""
Extract the object name and observation ID from the directory path.

The base directory of the object data has the format: <name>_oi<obsid>
"""

import os
import argparse

from _context import acispy
from acispy.utils import get_name_from_path, get_obsid_from_path


def main():
    parser = argparse.ArgumentParser(
        description="Extract object name and ObsID from data directory")
    parser.add_argument("-b", "--brief", dest="brief",
                        action="store_true", help="Be brief")
    parser.add_argument("-n", "--name", dest="name",
                        action="store_true", help="Only get object name")
    parser.add_argument("-i", "--obsid", dest="obsid",
                        action="store_true", help="Only get observation ID")
    parser.add_argument("path", nargs="?", default=os.getcwd(),
                        help="Path to the data directory " +
                        "(default: current working directory)")
    args = parser.parse_args()
    path = os.path.abspath(args.path)

    b_get_name = False if args.obsid else True
    b_get_obsid = False if args.name else True

    if b_get_name:
        if not args.brief:
            print("Name:", end=" ")
        print(get_name_from_path(path))
    if b_get_obsid:
        if not args.brief:
            print("ObsID:", end=" ")
        print(get_obsid_from_path(path))


if __name__ == "__main__":
    main()
