#!/usr/bin/env python3
#
# Copyright (c) 2016-2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Extract surface brightness profile specified by the region file
from a binned image file.

NOTE
----
The CIAO official science thread "Obtain and Fit a Radial Profile" uses
the (energy-filtered) event file to extract the SBP.  However, we found
that it is more convenient and accurate to extract the SBP from a binned
image instead of an event file (both are energy filtered of course),
due to the region area calculation.

To bin a image from the event file, the skyfov is usually provided to
specify the chip boundaries, therefore, the created image has a size just
enclosing the chips of interest (e.g., ACIS-7, or ACIS-0123).
And internally, the tool ``dmcopy`` records the skyfov regions in the
header keywords ``DSVAL?``, which are also used by ``dmcopy`` when
excluding the detected point sources.

when we provide the binned image to ``dmextract`` to extract SBP,
the removed point source areas and chip boundaries will be considered,
and the output SBP will have correct *effective* areas for each SBP region.
(Also note that the given *exposure map* is also an image, which is
similar to the input image.)

Therefore, we can just draw a series of annuli (instead of complex pie
regions), and ignore the chip boundaries as well.

In addition, using an image as the input is also much faster, especially
with large regions, or needing to consider excluding the outside-FoV
region for using event file.


References
----------
* CIAO: Ahelp: dmextract
  http://cxc.harvard.edu/ciao/ahelp/dmextract.html
* CIAO: Obtain and Fit a Radial Profile
  http://cxc.harvard.edu/ciao/threads/radial_profile/
"""

import os
import argparse
import subprocess
import logging

import numpy as np
from astropy.io import fits

from _context import acispy
from acispy.manifest import get_manifest
from acispy.ciao import setup_pfiles


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def extract_sbp(outfile, infile, expmap, region, clobber=False):
    """
    Extract the surface brightness profile

    If `bkg` is provided, then background subtraction is considered.
    """
    clobber = "yes" if clobber else "no"
    logger.info("Extract SBP: %s[bin sky=@%s] ..." % (infile, region))
    subprocess.check_call(["punlearn", "dmextract"])
    subprocess.check_call([
        "dmextract",
        "infile=%s[bin sky=@%s]" % (infile, region),
        "outfile=%s" % outfile, "exp=%s" % expmap,
        "opt=generic", "clobber=%s" % clobber
    ])
    # add ``RMID`` and ``R_ERR`` columns
    logger.info("Add 'RMID' and 'R_ERR' columns to SBP ...")
    sbp_rmid = os.path.splitext(outfile)[0] + "_rmid.fits"
    subprocess.check_call(["punlearn", "dmtcalc"])
    subprocess.check_call([
        "dmtcalc",
        "infile=%s" % outfile, "outfile=%s" % sbp_rmid,
        "expression=RMID=(R[0]+R[1])/2,R_ERR=(R[1]-R[0])/2",
        "clobber=%s" % clobber
    ])
    os.rename(sbp_rmid, outfile)


def make_sbp_txt(outfile, sbp, clobber=False):
    """
    Dump SBP data from FITS file to make a TXT data file,
    which can be used to further create the QDP file, and be used
    by the SBP fitting tools.
    """
    logger.info("Dump SBP data to text file: %s" % outfile)
    with fits.open(sbp) as sbpfits:
        rmid = sbpfits["HISTOGRAM"].data["RMID"]
        r_err = sbpfits["HISTOGRAM"].data["R_ERR"]
        sur_flux = sbpfits["HISTOGRAM"].data["SUR_FLUX"]
        sur_flux_err = sbpfits["HISTOGRAM"].data["SUR_FLUX_ERR"]
    sbpdata = np.column_stack([rmid, r_err, sur_flux, sur_flux_err])
    np.savetxt(outfile, sbpdata,
               header="RMID  R_ERR  SUR_FLUX  SUR_FLUX_ERR")


def make_sbp_qdp(outfile, sbp_data, clobber=False):
    """
    Create a QDP file for the extracted SBP, for easier visualization.
    """
    logger.info("Create a QDP for SBP: %s" % outfile)
    lines = [line.replace("#", "!") for line in open(sbp_data).readlines()]
    lines = [
        "READ SERR 1 2\n",
        'LABEL T "Surface Brightness Profile"\n',
        'LABEL X "Radius (pixel)"\n',
        'LABEL Y "Surface Flux (photons/cm\\u2\\d/pixel\\u2\\d/s)"\n',
        "LOG X Y ON\n"
    ] + lines
    with open(outfile, "w") as f:
        f.writelines(lines)


def main():
    parser = argparse.ArgumentParser(
            description="Extract surface brightness profile (SBP)")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing file")
    parser.add_argument("-r", "--region", dest="region",
                        help="region file specifying the SBP " +
                             "(default: 'sbp_reg' from manifest)")
    parser.add_argument("-i", "--infile", dest="infile", required=True,
                        help="input binned image ")
    parser.add_argument("-e", "--expmap", dest="expmap",
                        help="exposure map (default: 'expmap' from manifest)")
    parser.add_argument("-o", "--outfile", dest="outfile",
                        help="output SBP filename (default: same " +
                        "basename as the input region file)")
    args = parser.parse_args()

    setup_pfiles(["dmextract", "dmtcalc"])

    manifest = get_manifest()
    if args.region:
        region = args.region
    else:
        region = manifest.getpath("sbp_reg", relative=True)
    if args.expmap:
        expmap = args.expmap
    else:
        expmap = manifest.getpath("expmap", relative=True)
    if args.outfile:
        outfile = args.outfile
    else:
        outfile = os.path.splitext(region)[0] + ".fits"
    sbp_data = os.path.splitext(outfile)[0] + ".txt"
    sbp_qdp = os.path.splitext(outfile)[0] + ".qdp"

    extract_sbp(outfile=outfile, infile=args.infile, expmap=expmap,
                region=region, clobber=args.clobber)
    make_sbp_txt(outfile=sbp_data, sbp=outfile, clobber=args.clobber)
    make_sbp_qdp(outfile=sbp_qdp, sbp_data=sbp_data, clobber=args.clobber)

    logger.info("Add SBP files to manifest ...")
    key = "sbp"
    manifest.setpath(key, outfile)
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
    key = "sbp_reg"
    manifest.setpath(key, region)
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
    key = "sbp_data"
    manifest.setpath(key, sbp_data)
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
    key = "sbp_qdp"
    manifest.setpath(key, sbp_qdp)
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))


if __name__ == "__main__":
    main()
