#!/usr/bin/env python3
#
# Extract the cooling time corresponding to the cooling radius.
#
# Junhua GU
# 2012-12-20
# Weitian LI
# 2016-06-07
#

import argparse
import numpy as np


def get_tcool(data, rcool):
    """
    Get the cooling time *at* the specified cooling radius.

    XXX: whether to interpolate first?
    """
    radius = data[:, 0]
    ctime = data[:, 1]
    tcool = np.min(ctime[radius > rcool])
    return tcool


def main():
    parser = argparse.ArgumentParser(
            description="Extract cooling time w.r.t the given cooling radius")
    parser.add_argument("infile", help="input cooling time data file")
    parser.add_argument("rcool", type=float, help="cooling radius (kpc)")
    args = parser.parse_args()

    data = np.loadtxt(args.infile)
    tcool = get_tcool(data, rcool=args.rcool)
    print("cooling time at %f kpc=%f Gyr" % (args.rcool, tcool))
    print("cooling_time= %f Gyr" % tcool)
    print("cooling_radius= %f kpc" % args.rcool)


if __name__ == "__main__":
    main()
