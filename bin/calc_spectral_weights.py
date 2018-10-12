#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Calculate the spectral weights for instrument map creation, from which
the spectral-weighted exposure map will be created.

NOTE/CAVEAT
-----------
To compute an image which gives the integrated flux over the full energy
range, it may be best to first compute flux-corrected images in several
narrow energy bands (where the ARF is nearly flat) and then sum those
fluxed images together.  Weighted exposure maps work well for an energy
band where the ARF variation isn't very large, but for a full-band
0.5-10 keV image, it may not be a good idea to compute the flux by
dividing the counts image by a single number. This is especially true
for cases where the source spectrum varies significantly within the image;
in that case, there is no general way to compute a single set of weights
which will be sensible for every part of the image.

References
----------
* Chandra Memo: An Introduction to Exposure Map
  http://cxc.harvard.edu/ciao/download/doc/expmap_intro.ps
* CIAO: Calculating Spectral Weights for mkinstmap
  http://cxc.harvard.edu/ciao/threads/spectral_weights/
"""

import argparse
import subprocess
import logging

from _context import acispy
from acispy.manifest import get_manifest
from acispy.ciao import setup_pfiles


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def calc_spectral_weights(outfile, nh, redshift, temperature, abundance,
                          elow=700, ehigh=7000, ewidth=100,
                          abund_table="grsa", clobber=False):
    logger.info("Calculate spectral weights for instrument map ...")
    clobber = "yes" if clobber else "no"
    model = "xswabs.wabs1*xsapec.apec1"
    paramvals = ";".join([
        "wabs1.nh=%s" % nh,
        "apec1.redshift=%s" % redshift,
        "apec1.kt=%s" % temperature,
        "apec1.abundanc=%s" % abundance
    ])
    subprocess.check_call(["punlearn", "make_instmap_weights"])
    subprocess.check_call([
        "make_instmap_weights", "outfile=%s" % outfile,
        "model=%s" % model, "paramvals=%s" % paramvals,
        "emin=%s" % (elow/1000), "emax=%s" % (ehigh/1000),
        "ewidth=%s" % (ewidth/1000), "abund=%s" % abund_table,
        "clobber=%s" % clobber
    ])


def main():
    parser = argparse.ArgumentParser(
        description="Calculate the spectral weights for exposure map creation")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing file")
    parser.add_argument("-L", "--elow", dest="elow", type=int, default=700,
                        help="lower energy limit [eV] (default: 700 [eV])")
    parser.add_argument("-H", "--ehigh", dest="ehigh", type=int, default=7000,
                        help="upper energy limit [eV] (default: 7000 [eV])")
    parser.add_argument("-n", "--nh", dest="nh", type=float, required=True,
                        help="HI column density (unit: 1e22) for " +
                        "spectral weights creation")
    parser.add_argument("-z", "--redshift", dest="redshift",
                        type=float, required=True,
                        help="source redshift for spectral weights creation")
    parser.add_argument("-T", "--temperature", dest="temperature",
                        type=float, required=True,
                        help="source average temperature (unit: keV) " +
                        "for spectral weights creation")
    parser.add_argument("-Z", "--abundance", dest="abundance",
                        type=float, required=True,
                        help="source average abundance (unit: solar/grsa) " +
                        "for spectral weights creation")
    parser.add_argument("-o", "--outfile", dest="outfile",
                        default="spectral_weights.txt",
                        help="output spectral weights filename " +
                        "(default: spectral_weights.txt)")
    args = parser.parse_args()

    setup_pfiles(["make_instmap_weights"])

    manifest = get_manifest()
    logger.info("outfile: %s" % args.outfile)
    logger.info("nh: %s (1e22 cm^-2)" % args.nh)
    logger.info("redshift: %s" % args.redshift)
    logger.info("temperature: %s (keV)" % args.temperature)
    logger.info("abundance: %s (solar/grsa)" % args.abundance)

    calc_spectral_weights(outfile=args.outfile, nh=args.nh,
                          redshift=args.redshift,
                          temperature=args.temperature,
                          abundance=args.abundance,
                          elow=args.elow, ehigh=args.ehigh,
                          clobber=args.clobber)

    # Add created weights file to manifest
    key = "spec_weights"
    manifest.setpath(key, args.outfile)
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))


if __name__ == "__main__":
    main()
