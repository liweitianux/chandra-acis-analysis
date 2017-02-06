#!/usr/bin/env python3
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
# Weitian LI <liweitianux@gmail.com>
# Created: 2012-08-31
#
# ChangeLogs:
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
#

import sys
import csv
import json
from collections import OrderedDict

argc = len(sys.argv)
if (argc != 3):
    print("usage:")
    print("    "+ sys.argv[0]+ " <input_json> <output_csv>")
    sys.exit(255)

infile = open(sys.argv[1], 'r')
data = json.load(infile, object_pairs_hook=OrderedDict)
infile.close()

# column keys
colkeys = list(data[0].keys())

with open(sys.argv[2], 'w') as csvfile:
    outfile_writer = csv.writer(csvfile)
    # CSV header row
    outfile_writer.writerow(colkeys)
    # CSV data rows
    for row in data:
        outfile_writer.writerow([ row.get(key) for key in colkeys ])

#  vim: set ts=4 sw=4 tw=0 fenc=utf-8 ft=python: #
