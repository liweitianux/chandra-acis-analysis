#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Renormalize the (background) spectrum by equaling its particle background
flux (e.g., 9.5-12.0 keV) with respect to its corresponding source spectrum.

The ``BACKSCAL`` keyword of the background spectrum is modified to realize
the above renormalization.
"""

import sys
import argparse
import subprocess

from _context import acispy
from acispy.spectrum import Spectrum


def renorm_spectrum(specfile, specfile_ref, elow=9500, ehigh=12000):
    """
    Modify the ``BACKSCAL`` of ``specfile`` in order to equal its
    particle background flux to that of ``specfile_ref``.

    Parameters
    ----------
    specfile : str
        (background) spectrum to be renormalized/modified.
    specfile_ref : str
        (source/reference) spectrum
    elow, ehigh : float, optional
        Lower and upper energy limit of the particle background.
    """
    spec = Spectrum(specfile)
    spec_ref = Spectrum(specfile_ref)
    flux = spec.calc_pb_flux(elow=elow, ehigh=ehigh)
    flux_ref = spec_ref.calc_pb_flux(elow=elow, ehigh=ehigh)
    bs_old = spec.BACKSCAL
    bs_new = bs_old * flux / flux_ref
    subprocess.check_call(["punlearn", "dmhedit"])
    subprocess.check_call([
        "dmhedit", "infile=%s" % specfile,
        "filelist=none", "operation=add",
        "key=BACKSCAL", "value=%s" % bs_new,
        "comment='Old BACKSCAL: %s'" % bs_old
    ])
    print("%s:BACKSCAL: %f -> %f" % (specfile, bs_old, bs_new),
          file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Renormalize background spectrum w.r.t. source spectrum")
    parser.add_argument("-L", "--energy-low", dest="elow",
                        type=int, default=9500,
                        help="Lower energy limit of the particle " +
                        "background [eV] (default: 9500 eV)")
    parser.add_argument("-H", "--energy-high", dest="ehigh",
                        type=int, default=12000,
                        help="Upper energy limit of the particle " +
                        "background [eV] (default: 12000 eV)")
    parser.add_argument("-r", "--spec-ref", dest="spec_ref", required=True,
                        help="Reference (source) spectrum")
    parser.add_argument("spec",
                        help="(background) spectrum to be renormalized")
    args = parser.parse_args()

    renorm_spectrum(specfile=args.spec, specfile_ref=args.spec_ref,
                    elow=args.elow, ehigh=args.ehigh)


if __name__ == "__main__":
    main()
