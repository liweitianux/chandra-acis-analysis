#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Calculate the particle background flux (e.g., 9.5-12.0 keV) of the spectra.

flux = counts / exposure / area
where 'counts' is the total photon counts within the specified energy range;
'area' is the value of the ``BACKSCAL`` stored in the spectrum.
therefore, the output flux has arbitrary unit.
"""

import argparse

from _context import acispy
from acispy.spectrum import Spectrum


def main():
    parser = argparse.ArgumentParser(
        description="Calculate the particle background for spectra")
    parser.add_argument("-L", "--energy-low", dest="elow",
                        type=int, default=9500,
                        help="lower energy limit of the particle " +
                        "background [eV] (default: 9500 eV)")
    parser.add_argument("-H", "--energy-high", dest="ehigh",
                        type=int, default=12000,
                        help="upper energy limit of the particle " +
                        "background [eV] (default: 12000 eV)")
    parser.add_argument("-v", "--verbose", dest="verbose", action="store_true",
                        help="show verbose information")
    parser.add_argument("infile", nargs="+",
                        help="input spectra")
    args = parser.parse_args()

    for f in args.infile:
        print("=== %s ===" % f)
        spec = Spectrum(f)
        flux = spec.calc_pb_flux(elow=args.elow, ehigh=args.ehigh,
                                 verbose=args.verbose)
        print("flux = %.5g" % flux)


if __name__ == "__main__":
    main()
