#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Calculate the cooling function profile with respect to the input
temperature profile by interpolating the previously calculated
cooling function table.

In this way, the cooling function profile can be calculated very
quickly, allowing much more iterations for the later Monte Carlo
calculations.
"""

import os
import sys
import argparse

import numpy as np
import scipy.interpolate as interpolate


def interpolate_cf(table, logy=True):
    temp, cf = table[:, 0], table[:, 1]
    if logy:
        cf = np.log10(cf)
    print("Interpolating cooling function table ...", file=sys.stderr)
    interp = interpolate.interp1d(temp, cf, kind="linear")
    return interp


def calc_cf_profile(tprofile, interp, logy=True):
    print("Calculating cooling function profile ...", file=sys.stderr)
    radius, temp = tprofile[:, 0], tprofile[:, 1]
    cf = interp(temp)
    if logy:
        cf = 10 ** cf
    cfprofile = np.column_stack([radius, cf])
    return cfprofile


def main():
    parser = argparse.ArgumentParser(
        description="Calculate cooling function profile by interpolations")
    parser.add_argument("-t", "--table", dest="table", required=True,
                        help="previously calculated cooling function table")
    parser.add_argument("-T", "--tprofile", dest="tprofile", required=True,
                        help="temperature profile " +
                        "(2-column: radius temperature)")
    parser.add_argument("-o", "--outfile", dest="outfile", required=True,
                        help="output cooling function profile")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing files")
    args = parser.parse_args()

    if (not args.clobber) and os.path.exists(args.outfile):
        raise OSError("Output file already exists: %s" % args.outfile)

    table = np.loadtxt(args.table)
    tprofile = np.loadtxt(args.tprofile)
    cf_interp = interpolate_cf(table)
    cf_profile = calc_cf_profile(tprofile, cf_interp)
    np.savetxt(args.outfile, cf_profile)


if __name__ == "__main__":
    main()
