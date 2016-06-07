#!/usr/bin/env python3
#
# Calculate the entropy within the specified radius.
#
# Junhua GU
# Weitian LI
# 2016-06-07
#

import argparse
import re
from itertools import groupby
import numpy as np


def isplit(iterable, splitters):
    """
    Credit: https://stackoverflow.com/a/4322780/4856091
    """
    return [list(g) for k, g in groupby(iterable,
                                        lambda x:x in splitters) if not k]


def get_entropy(data, r):
    """
    Get the entropy *at* the specified radius.

    XXX: whether to interpolate first?
    """
    radius = data[:, 0]
    entropy = data[:, 1]
    s = np.min(entropy[radius > r])
    return s


def read_merged_qdp(infile):
    """
    Read merged QDP with multiple group of data separated by "no no no".
    """
    lines = map(lambda line: re.sub(r"^\s*no\s+no\s+no.*$", "X",
                                    line.strip(), flags=re.I),
                open(infile).readlines())
    lines = isplit(lines, ("X",))
    data_groups = []
    for block in lines:
        data = [list(map(float, l.split())) for l in block]
        data.append(np.row_stack(data))
    return data_groups


def calc_error(center_value, mc_values, ci=0.683):
    """
    Calculate the uncertainties/errors.
    """
    data = np.concatenate([[center_value], mc_values])
    median, q_lower, q_upper = np.percentile(data, q=(50, 50-50*ci, 50+50*ci))
    mean = np.mean(data)
    std = np.std(data)
    return {
        "mean":    mean,
        "std":     std,
        "median":  median,
        "q_lower": q_lower,
        "q_upper": q_upper,
    }


def main():
    parser = argparse.ArgumentParser(
            description="Calculate the entropy within the given radius")
    parser.add_argument("-C", "--confidence-level", dest="ci",
                        type=float, default=0.683,
                        help="confidence level to estimate the errors")
    parser.add_argument("center_data",
                        help="calculate central entropy profile " +
                             "(e.g., entropy_center.qdp)")
    parser.add_argument("mc_data",
                        help="Merged QDP file of all the Monte Carlo " +
                             "simulated entropy profiles " +
                             "(e.g., summary_entropy.qdp)")
    parser.add_argument("rout", type=float, help="outer radius (kpc)")
    args = parser.parse_args()

    center_data = np.loadtxt(args.center_data)
    center_s = get_entropy(center_data, r=args.rout)

    data_groups = read_merged_qdp(args.mc_data)
    entropy_list = []
    for dg in data_groups:
        s = get_entropy(dg, r=args.rout)
        entropy_list.append(s)
    results = calc_error(center_s, entropy_list, ci=args.ci)
    s_err_lower = results["q_lower"] - center_s
    s_err_upper = results["q_upper"] - center_s

    print("entropy= %e %+e/%+e keV cm^2 (ci=%.1f%%)" %
          (center_s, s_err_lower, s_err_upper, args.ci * 100))
    print("entropy(mean)= %e" % results["mean"])
    print("entropy(median)= %e" % results["median"])
    print("entropy(std)= %e" % results["std"])


if __name__ == "__main__":
    main()
