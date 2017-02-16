#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Make image by binning the event file, and update the manifest.

TODO: use logging module instead of print()
"""

import sys
import argparse
import subprocess

from manifest import get_manifest
from setup_pfiles import setup_pfiles
from chandra_acis import get_chips


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
    subprocess.check_call(["punlearn", "dmcopy"])
    subprocess.check_call([
        "dmcopy", "infile=%s[%s][%s][%s]" % (infile, fregion, fenergy, fbin),
        "outfile=%s" % outfile, "clobber=%s" % clobber
    ])


def main():
    parser = argparse.ArgumentParser(
        description="Make image by binning the event file")
    parser.add_argument("--elow", dest="elow", type=int, default=700,
                        help="lower energy limit [eV] of the output image " +
                        "(default: 700 [eV])")
    parser.add_argument("--ehigh", dest="ehigh", type=int,
                        help="upper energy limit [eV] of the output image " +
                        "(default: 7000 [eV])")
    parser.add_argument("-i", "--infile", dest="infile",
                        help="event file from which to create the image " +
                        "(default: evt2_clean from manifest)")
    parser.add_argument("-o", "--outfile", dest="outfile",
                        help="output image filename (default: " +
                        "build in format 'img_c<chip>_e<elow>-<ehigh>.fits')")
    parser.add_argument("-v", "--verbose", dest="verbose", action="store_true",
                        help="show verbose information")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing file")
    args = parser.parse_args()

    setup_pfiles(["dmkeypar", "dmcopy"])

    manifest = get_manifest()
    fov = manifest.getpath("fov")
    infile = args.infile if args.infile else manifest.getpath("evt2_clean")
    chips = get_chips(infile, sep="-")
    erange = "{elow}-{ehigh}".format(elow=args.elow, ehigh=args.ehigh)
    if args.outfile:
        outfile = args.outfile
    else:
        outfile = "img_c{chips}_e{erange}.fits".format(
            chips=chips, elow=erange)
    if args.verbose:
        print("infile:", infile, file=sys.stderr)
        print("outfile:", outfile, file=sys.stderr)
        print("fov:", fov, file=sys.stderr)
        print("chips:", chips, file=sys.stderr)
        print("erange:", erange, file=sys.stderr)

    make_image(infile, outfile, chips, erange, fov, args.clobber)

    # Add created image to manifest
    key = "img_e{erange}".format(erange=erange)
    manifest.setpath(key, outfile)


if __name__ == "__main__":
    main()
