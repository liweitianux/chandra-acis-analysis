#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Cosmology calculator with support of Chandra ACIS-specific quantities.
"""

import sys
import argparse
from collections import OrderedDict

from _context import acispy
from acispy.cosmo import Calculator


# Supported quantities
QUANTITIES = OrderedDict([
    ("luminosity_distance", {
        "unit": "Mpc",
        "label": "Luminosity distance",
        "kwargs": ["z", "unit"],
    }),
    ("angular_diameter_distance", {
        "unit": "Mpc",
        "label": "Angular diameter distance",
        "kwargs": ["z", "unit"],
    }),
    ("kpc_per_arcsec", {
        "unit": None,
        "label": "kpc/arcsec (DA)",
        "kwargs": ["z"],
    }),
    ("kpc_per_pix", {
        "unit": None,
        "label": "kpc/pix (DA)",
        "kwargs": ["z"],
    }),
    ("cm_per_pix", {
        "unit": None,
        "label": "cm/pix (DA)",
        "kwargs": ["z"],
    }),
    ("norm_apec", {
        "unit": "cm^-5",
        "label": "norm (APEC)",
        "kwargs": ["z"],
    }),
])


def get_quantities(args):
    # convert ``argparse.Namespace`` to a dictionary
    args = vars(args)
    q_all = list(QUANTITIES.keys())
    q_active = [q for q in q_all if args[q]]
    if len(q_active) == 0:
        q_active = q_all
    return q_active


def calc_quantity(q, calculator, args):
    args = vars(args)
    kwargs = {arg: args[arg] for arg in QUANTITIES[q]["kwargs"]
              if args[arg] is not None}
    value = getattr(calculator, q)(**kwargs)
    label = QUANTITIES[q]["label"]
    unit = args["unit"] if args["unit"] is not None else QUANTITIES[q]["unit"]
    if args["brief"]:
        print(value)
    else:
        print("%s: %s  # [%s]" % (label, value, unit))


def main():
    parser = argparse.ArgumentParser(
        description="Cosmology calculator with Chandra-specific quantities")
    parser.add_argument("-H", "--hubble", dest="H0",
                        type=float, default=71.0,
                        help="Present-day Hubble parameter " +
                        "(default: 71 km/s/Mpc)")
    parser.add_argument("-M", "--omega-m", dest="Om0",
                        type=float, default=0.27,
                        help="Present-day matter density (default: 0.27")
    parser.add_argument("-b", "--brief", dest="brief", action="store_true",
                        help="be brief")
    parser.add_argument("-U", "--unit", dest="unit",
                        help="unit for output quantity if supported")
    parser.add_argument("-L", "--luminosity-distance",
                        dest="luminosity_distance",
                        action="store_true",
                        help="calculate the luminosity distance (DL)")
    parser.add_argument("-A", "--angular-diameter-distance",
                        dest="angular_diameter_distance",
                        action="store_true",
                        help="calculate the angular diameter distance (DA)")
    parser.add_argument("--kpc-per-arcsec", dest="kpc_per_arcsec",
                        action="store_true",
                        help="calculate the transversal length [kpc] " +
                        "w.r.t. 1 arcsec at DA(z)")
    parser.add_argument("--kpc-per-pix", dest="kpc_per_pix",
                        action="store_true",
                        help="calculate the transversal length [kpc] " +
                        "w.r.t. 1 ACIS pixel (0.492 arcsec) at DA(z)")
    parser.add_argument("--cm-per-pix", dest="cm_per_pix",
                        action="store_true",
                        help="calculate the transversal length [cm] " +
                        "w.r.t. 1 ACIS pixel (0.492 arcsec) at DA(z)")
    parser.add_argument("--norm-apec", dest="norm_apec",
                        action="store_true",
                        help="calculate the normalization factor " +
                        "of the XSPEC APEC model assuming EM=1")
    parser.add_argument("z", type=float, help="redshift")
    args = parser.parse_args()

    cosmocalc = Calculator(H0=args.H0, Om0=args.Om0)

    q_active = get_quantities(args)
    if len(q_active) > 1:
        if args.unit is not None:
            args.unit = None
            print("WARNING: ignored argument --unit", file=sys.stderr)
        if args.brief:
            args.brief = False
            print("WARNING: ignored argument --brief", file=sys.stderr)

    for q in q_active:
        calc_quantity(q=q, calculator=cosmocalc, args=args)


if __name__ == "__main__":
    main()
