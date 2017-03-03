#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Make image by binning the event file, and update the manifest.
"""

import argparse
import subprocess
import logging

from _context import acispy
from acispy.manifest import get_manifest
from acispy.pfiles import setup_pfiles
from acispy.acis import ACIS
from acispy.header import write_keyword


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def make_image(infile, outfile, chips, erange, fov, clobber=False):
    """
    Make image by binning the event file.

    Parameters
    ----------
    infile : str
        Path to the input event file
    outfile : str
        Filename and path of the output image file
    chips : str
        Chips of interest, e.g., ``7`` or ``0-3``
    erange : str
        Energy range of interest, e.g., ``700-7000``
    fov : str
        Path to the FoV file
    """
    chips = chips.replace("-", ":")
    erange = erange.replace("-", ":")
    clobber = "yes" if clobber else "no"
    fregion = "sky=region(%s[ccd_id=%s])" % (fov, chips)
    fenergy = "energy=%s" % erange
    fbin = "bin sky=::1"
    logger.info("Make image: %s[%s][%s][%s]" %
                (infile, fregion, fenergy, fbin))
    subprocess.check_call(["punlearn", "dmcopy"])
    subprocess.check_call([
        "dmcopy", "infile=%s[%s][%s][%s]" % (infile, fregion, fenergy, fbin),
        "outfile=%s" % outfile, "clobber=%s" % clobber
    ])


def main():
    parser = argparse.ArgumentParser(
        description="Make image by binning the event file")
    parser.add_argument("-L", "--elow", dest="elow", type=int, default=700,
                        help="lower energy limit [eV] of the output image " +
                        "(default: 700 [eV])")
    parser.add_argument("-H", "--ehigh", dest="ehigh", type=int, default=7000,
                        help="upper energy limit [eV] of the output image " +
                        "(default: 7000 [eV])")
    parser.add_argument("-i", "--infile", dest="infile",
                        help="event file from which to create the image " +
                        "(default: 'evt2_clean' from manifest)")
    parser.add_argument("-o", "--outfile", dest="outfile",
                        help="output image filename (default: " +
                        "build in format 'img_c<chip>_e<elow>-<ehigh>.fits')")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing file")
    args = parser.parse_args()

    setup_pfiles(["dmkeypar", "dmcopy"])

    manifest = get_manifest()
    fov = manifest.getpath("fov", relative=True)
    if args.infile:
        infile = args.infile
    else:
        infile = manifest.getpath("evt2_clean", relative=True)
    chips = ACIS.get_chips_str(infile, sep="-")
    erange = "{elow}-{ehigh}".format(elow=args.elow, ehigh=args.ehigh)
    if args.elow >= args.ehigh:
        raise ValueError("invalid energy range: %s" % erange)
    if args.outfile:
        outfile = args.outfile
    else:
        outfile = "img_c{chips}_e{erange}.fits".format(
            chips=chips, erange=erange)
    logger.info("infile: %s" % infile)
    logger.info("outfile: %s" % outfile)
    logger.info("fov: %s" % fov)
    logger.info("chips: %s" % chips)
    logger.info("erange: %s" % erange)

    make_image(infile, outfile, chips, erange, fov, args.clobber)
    chips_all = ACIS.get_chips_str(infile)
    write_keyword(outfile, keyword="DETNAM",
                  value="ACIS-{0}".format(chips_all))

    # Add created image to manifest
    key = "img_e{erange}".format(erange=erange)
    manifest.setpath(key, outfile)
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))


if __name__ == "__main__":
    main()
