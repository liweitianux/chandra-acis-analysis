#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license
#
# Weitian LI
# 2017-02-12

"""
Collect YAML manifest files, and convert collected results to CSV
format for later use.
"""

import sys
import argparse
import csv

from manifest import Manifest


def main():
    parser = argparse.ArgumentParser(description="Collect YAML manifest files")
    parser.add_argument("-k", "--keys", dest="keys", required=True,
                        help="YAML keys to be collected (in order); " +
                        "can be comma-separated string, or a file " +
                        "containing the keys one-per-line")
    parser.add_argument("-b", "--brief", dest="brief",
                        action="store_true",
                        help="be brief and do not print header")
    parser.add_argument("-v", "--verbose", dest="verbose",
                        action="store_true",
                        help="show verbose information")
    parser.add_argument("-o", "--outfile", dest="outfile", default=sys.stdout,
                        help="output CSV file to save collected data")
    parser.add_argument("-i", "--infile", dest="infile",
                        nargs="+", required=True,
                        help="list of input YAML manifest files")
    args = parser.parse_args()

    try:
        keys = [k.strip() for k in open(args.keys).readlines()]
    except FileNotFoundError:
        keys = [k.strip() for k in args.keys.split(",")]

    if args.verbose:
        print("keys:", keys, file=sys.stderr)
        print("infile:", args.infile, file=sys.stderr)
        print("outfile:", args.outfile, file=sys.stderr)

    results = []
    for fp in args.infile:
        manifest = Manifest(fp)
        res = manifest.gets(keys)
        if args.verbose:
            print("FILE:{0}: {1}".format(fp, list(res.values())),
                  file=sys.stderr)
        results.append(res)

    try:
        of = open(args.outfile, "w")
    except TypeError:
        of = args.outfile
    writer = csv.writer(of)
    if not args.brief:
        writer.writerow(results[0].keys())
    for res in results:
        writer.writerow(res.values())
    if of is not sys.stdout:
        of.close()


if __name__ == "__main__":
    main()
