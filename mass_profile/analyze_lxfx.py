#!/usr/bin/env python3
#
# Calculate the mean and standard deviation of the (Monte Carlo)
# Lx and Fx data
#
# Junhua GU
# Weitian LI
# 2016-06-07
#

import sys
import argparse
import numpy as np


def read_bands(bands):
    """
    Read energy bands list, each band per line.
    """
    bands = map(str.split, open(bands).readlines())
    bands = ["-".join(b) for b in bands]
    return bands


def output(name, bands, means, sigmas, outfile=sys.stdout):
    if outfile is not sys.stdout:
        outfile = open(outfile, "w")
    for b, m, s in zip(bands, means, sigmas):
        print("%s(%s)= %4.2E +/- %4.2E erg/s" % (name, b, m, s),
              file=outfile)
    if outfile is not sys.stdout:
        outfile.close()


def main():
    parser = argparse.ArgumentParser(
            description="Analyze Lx/Fx results")
    parser.add_argument("name", help="Lx or Fx")
    parser.add_argument("infile", help="input data file")
    parser.add_argument("outfile", help="output results file")
    parser.add_argument("bands", help="energy bands of the input data columns")
    args = parser.parse_args()

    data = np.loadtxt(args.infile)
    bands = read_bands(args.bands)
    if len(bands) != data.shape[1]:
        raise ValueError("number of energy bands != number of data columns")

    means = np.mean(data, axis=0)
    sigmas = np.std(data, axis=0)
    output(name=args.name, bands=bands, means=means, sigmas=sigmas)
    output(name=args.name, bands=bands, means=means, sigmas=sigmas,
           outfile=args.outfile)


if __name__ == "__main__":
    main()
