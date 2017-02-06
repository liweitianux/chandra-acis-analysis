#!/usr/bin/env python3
#
# Copyright (c) 2012-2017 Weitian LI <liweitianux@live.com>
# MIT license
#
# Convert JSON to CSV format
#
# References:
# [1] https://docs.python.org/3/library/json.html
# [2] https://docs.python.org/3/library/csv.html
# [3] http://stackoverflow.com/questions/1871524/convert-from-json-to-csv-using-python
# [4] http://json.parser.online.fr/
#
#
# Weitian LI <liweitianux@live.com>
# Created: 2012-08-31
#
# Change logs:
# 2017-02-06, Weitian LI
#   * Use `argparse`
#   * Cleanups
# v3.5, 2015-11-09
#   * Get column keys from the first input json block
#   * Use python3
# v3.4, 2015-11-09
#   * Add keys 'XPEAK_RA', 'XPEAK_DEC', and 'XPEAK_XCNTRD_dist (pix)'
#   * Add 'colkeys' to record CSV column keys
#   * Update file header description
# v3.3, 2013-10-14
#   * add key `Unified Name'
# v3.2, 2013-05-29
#   * add key `XCNTRD_RA, XCNTRD_DEC'
# v3.1, 2013-05-18
#   * add key `Feature', corresponding to `collectdata_v3.1'

import os
import argparse
import csv
import json
from collections import OrderedDict


def main():
    parser = argparse.ArgumentParser(description="Convert JSON to CSV")
    parser.add_argument("infile", help="Input JSON file")
    parser.add_argument("outfile", nargs="?",
                        help="Output CSV file (default to use the same " +
                        "basename as the input file)")
    args = parser.parse_args()

    with open(args.infile) as f:
        # Use `OrderedDict` to keep the orders of keys of all json files
        data = json.load(f, object_pairs_hook=OrderedDict)

    # Column keys
    colkeys = list(data[0].keys())

    if args.outfile:
        outfile = args.outfile
    else:
        outfile = os.path.splitext(args.infile)[0] + ".csv"
    with open(outfile, "w") as csvfile:
        outfile_writer = csv.writer(csvfile)
        # CSV header row
        outfile_writer.writerow(colkeys)
        # CSV data rows
        for row in data:
            outfile_writer.writerow([row.get(key) for key in colkeys])


if __name__ == "__main__":
    main()

#  vim: set ts=4 sw=4 tw=0 fenc=utf-8 ft=python: #
