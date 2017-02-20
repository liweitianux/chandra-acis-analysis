#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Cosmology calculator with support of Chandra ACIS-specific quantities.
"""

import argparse

from context import acispy
from acispy.cosmo import Calculator


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
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-L", "--luminosity-distance",
                       dest="luminosity_distance",
                       action="store_true",
                       help="calculate the luminosity distance (DL)")
    group.add_argument("-A", "--angular-diameter-distance",
                       dest="angular_diameter_distance",
                       action="store_true",
                       help="calculate the angular diameter distance (DA)")
    group.add_argument("--kpc-per-arcsec", dest="kpc_per_arcsec",
                       action="store_true",
                       help="calculate the transversal length [kpc] " +
                       "w.r.t. 1 arcsec at DA(z)")
    group.add_argument("--kpc-per-pix", dest="kpc_per_pix",
                       action="store_true",
                       help="calculate the transversal length [kpc] " +
                       "w.r.t. 1 ACIS pixel (0.492 arcsec) at DA(z)")
    group.add_argument("--cm-per-pix", dest="cm_per_pix",
                       action="store_true",
                       help="calculate the transversal length [cm] " +
                       "w.r.t. 1 ACIS pixel (0.492 arcsec) at DA(z)")
    group.add_argument("--norm-apec", dest="norm_apec",
                       action="store_true",
                       help="calculate the normalization factor " +
                       "of the XSPEC APEC model assuming EM=1")
    parser.add_argument("z", type=float, help="redshift")
    args = parser.parse_args()

    cosmocalc = Calculator(H0=args.H0, Om0=args.Om0)

    if args.luminosity_distance:
        kwargs = {"z": args.z}
        kwargs["unit"] = args.unit if args.unit else "Mpc"
        label = "Luminosity distance [%s]" % kwargs["unit"]
        value = cosmocalc.luminosity_distance(**kwargs)
    elif args.angular_diameter_distance:
        kwargs = {"z": args.z}
        kwargs["unit"] = args.unit if args.unit else "Mpc"
        label = "Angular diameter distance [%s]" % kwargs["unit"]
        value = cosmocalc.angular_diameter_distance(**kwargs)
    elif args.kpc_per_arcsec:
        label = "kpc/arcsec (DA)"
        value = cosmocalc.kpc_per_arcsec(args.z)
    elif args.kpc_per_pix:
        label = "kpc/pix (DA)"
        value = cosmocalc.kpc_per_pix(args.z)
    elif args.cm_per_pix:
        label = "cm/pix (DA)"
        value = cosmocalc.cm_per_pix(args.z)
    elif args.norm_apec:
        label = "norm (APEC) [cm^-5]"
        value = cosmocalc.norm_apec(args.z)
    else:
        raise ValueError("no quantity to calculate")

    if not args.brief:
        print(label + ": ", end="", flush=True)
    print(value)


if __name__ == "__main__":
    main()
