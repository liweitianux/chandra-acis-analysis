#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Correct (counts) image for exposure by dividing the exposure map.

References
----------
* Chandra Memo: An Introduction to Exposure Map
  http://cxc.harvard.edu/ciao/download/doc/expmap_intro.ps
* CIAO: Single Chip ACIS Exposure Map and Exposure-corrected Image
  http://cxc.harvard.edu/ciao/threads/expmap_acis_single/
* CIAO: Multiple Chip ACIS Exposure Map and Exposure-corrected Image
  http://cxc.harvard.edu/ciao/threads/expmap_acis_multi/
"""

import os
import argparse
import subprocess
import logging

from _context import acispy
from acispy.manifest import get_manifest
from acispy.pfiles import setup_pfiles
from acispy.image import get_xygrid


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def threshold_image(infile, outfile, expmap, cut="1.5%", clobber=False):
    """
    The strongly variable exposure near the edge of a dithered field
    may produce "hot" pixels when divided into an image.  Therefore,
    apply a threshold to the image pixels that cuts the pixels with
    value of exposure less than the threshold.
    """
    logger.info("Threshold cut the image: cut=%s" % cut)
    clobber = "yes" if clobber else "no"
    subprocess.check_call(["punlearn", "dmimgthresh"])
    subprocess.check_call([
        "dmimgthresh", "infile=%s" % infile,
        "outfile=%s" % outfile, "expfile=%s" % expmap,
        "cut=%s" % cut,
        "clobber=%s" % clobber
    ])


def correct_exposure(infile, outfile, expmap, clobber=False):
    """
    The strongly variable exposure near the edge of a dithered field
    may produce "hot" pixels when divided into an image.  Therefore,
    apply a threshold to the image pixels that cuts the pixels with
    value of exposure less than the threshold.
    """
    logger.info("Correct the image for exposure ...")
    clobber = "yes" if clobber else "no"
    subprocess.check_call(["punlearn", "dmimgcalc"])
    subprocess.check_call([
        "dmimgcalc", "infile=%s" % infile, "infile2=%s" % expmap,
        "outfile=%s[PFLUX_IMAGE]" % outfile,
        "operation=div",
        "clobber=%s" % clobber
    ])


def main():
    parser = argparse.ArgumentParser(
        description="Make spectral-weighted exposure map")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing file")
    parser.add_argument("-M", "--update-manifest", dest="update_manifest",
                        action="store_true",
                        help="update manifest with newly created images")
    parser.add_argument("-i", "--infile", dest="infile", required=True,
                        help="input image file to apply exposure correction")
    parser.add_argument("-e", "--expmap", dest="expmap",
                        help="exposure map (default: 'expmap' from manifest)")
    parser.add_argument("-o", "--outfile", dest="outfile",
                        help="filename of output exposure-corrected image " +
                        "(default: append '_expcorr' to the base filename)")
    args = parser.parse_args()

    setup_pfiles(["dmimgcalc", "dmimgthresh"])

    manifest = get_manifest()
    if args.expmap:
        expmap = args.expmap
    else:
        expmap = manifest.getpath("expmap", relative=True)
    if args.outfile:
        img_expcorr = args.outfile
    else:
        img_expcorr = os.path.splitext(args.infile)[0] + "_expcorr.fits"
    img_thresh = os.path.splitext(args.infile)[0] + "_thresh.fits"
    logger.info("infile: %s" % args.infile)
    logger.info("expmap: %s" % expmap)
    logger.info("output exposure-corrected image: %s" % img_expcorr)
    logger.info("output threshold-cut counts image: %s" % img_thresh)

    xygrid_infile = get_xygrid(args.infile)
    xygrid_expmap = get_xygrid(expmap)
    logger.info("%s:xygrid: %s" % (args.infile, xygrid_infile))
    logger.info("%s:xygrid: %s" % (expmap, xygrid_expmap))
    if xygrid_infile != xygrid_expmap:
        raise ValueError("xygrid: input image and exposure map do not match")

    threshold_image(infile=args.infile, outfile=img_thresh, expmap=expmap,
                    clobber=args.clobber)
    correct_exposure(infile=img_thresh, outfile=img_expcorr,
                     expmap=expmap, clobber=args.clobber)

    if args.update_manifest:
        logger.info("Add newly created images to manifest ...")
        key = "img_expcorr"
        manifest.setpath(key, img_expcorr)
        logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
        key = "img_thresh"
        manifest.setpath(key, img_thresh)
        logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))


if __name__ == "__main__":
    main()
