#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Further process the reprocessed evt2 file to make a cleaned one
for later scientific analysis.

The following steps are carried out:
1. Filter out the chips of interest;
2. Detect (point) sources, visually check and manually update;
3. Remove the updated sources;
4. Extract light curve of the background regions (away from the object);
5. Check and clip the light curve to create a GTI;
6. Remove flares by filtering the GTI to create the finally cleaned evt2.
"""

import os
import argparse
import subprocess
import shutil
import logging

from manifest import get_manifest
from setup_pfiles import setup_pfiles
from acis import ACIS
from ds9 import ds9_view


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def filter_chips(infile, outfile, chips, clobber=False):
    """
    Filter out the chips of interest, e.g., ``ccd_id=7`` for ACIS-S
    observation, and ``ccd_id=0:3`` for ACIS-I observation.
    """
    chips = chips.replace("-", ":")
    clobber = "yes" if clobber else "no"
    logger.info("Filter out chips of interest: %s" % chips)
    logger.info("Outfile: %s" % outfile)
    subprocess.check_call(["punlearn", "dmcopy"])
    subprocess.check_call([
        "dmcopy", "infile=%s[ccd_id=%s]" % (infile, chips),
        "outfile=%s" % outfile, "clobber=%s" % clobber
    ])
    logger.info("Done!\n")


def detect_sources(infile, outfile, clobber=False):
    """
    Detect (point) sources using ``celldetect``; examine the detected
    sources in DS9, and update the source regions and save.
    """
    src_fits = os.path.splitext(outfile)[0] + ".fits"
    clobber = "yes" if clobber else "no"
    logger.info("Detect sources using 'celldetect' ...")
    logger.info("Outfile: %s" % outfile)
    subprocess.check_call(["punlearn", "celldetect"])
    subprocess.check_call([
        "celldetect", "infile=%s" % infile,
        "outfile=%s" % src_fits, "regfile=%s" % outfile,
        "clobber=%s" % clobber
    ])
    os.remove(src_fits)
    shutil.copy(outfile, outfile+".orig")
    logger.warning("Check and update detected source regions; " +
                   "and save/overwrite file: %s" % outfile)
    ds9_view(infile, regfile=outfile)
    logger.info("Done!\n")


def remove_sources(infile, outfile, srcfile, clobber=False):
    """
    Remove detected sources
    """
    clobber = "yes" if clobber else "no"
    logger.info("Remove detected sources ...")
    logger.info("Outfile: %s" % outfile)
    subprocess.check_call(["punlearn", "dmcopy"])
    subprocess.check_call([
        "dmcopy", "infile=%s[exclude sky=region(%s)]" % (infile, srcfile),
        "outfile=%s" % outfile, "clobber=%s" % clobber
    ])
    logger.info("Done!\n")


def extract_lightcurve(infile, outfile, bintime=200, clobber=False):
    """
    Extract the light curve from regions away from the object.
    """
    clobber = "yes" if clobber else "no"
    logger.info("Extract light curve for GTI generation ...")
    logger.info("Outfile: %s" % outfile)
    regfile = os.path.splitext(outfile)[0] + ".reg"
    # Credit: https://stackoverflow.com/a/12654798/4856091
    open(regfile, "a").close()
    logger.warning("Select a large region containing most of the object, " +
                   "but also leaving enough area outside as background; " +
                   "and save as file: %s" % regfile)
    ds9_view(infile)
    fsky = "exclude sky=region(%s)" % regfile
    fbintime = "bin time=::%s" % bintime
    subprocess.check_call(["punlearn", "dmextract"])
    subprocess.check_call([
        "dmextract", "infile=%s[%s][%s]" % (infile, fsky, fbintime),
        "outfile=%s" % outfile, "opt=ltc1", "clobber=%s" % clobber
    ])
    logger.info("Done!\n")


def make_gti(infile, outfile, scale=1.2, clobber=False):
    """
    Examine the light curve for flares, and clip it to make the GTI.
    """
    logger.info("Examine the light curve and create GTI ...")
    logger.info("Outfile: %s" % outfile)

    chipsfile = os.path.splitext(outfile)[0] + ".chips"
    if (not clobber) and (os.path.exists(outfile) or
                          os.path.exists(chipsfile)):
        raise OSError("'%s' or '%s' already exists" % (outfile, chipsfile))

    outimg = os.path.splitext(outfile)[0] + "_lc.jpg"
    lines = [
        "from lightcurves import lc_clean",
        "lc_clean('%s')" % infile,
        "lc_clean('%s', scale=%s, outfile='%s')" % (infile, scale, outfile),
        "print_window('%s', ['format', 'jpg', 'clobber', 'True'])" % outimg
    ]
    open(chipsfile, "w").write("\n".join(lines) + "\n")
    subprocess.check_call(["chips", "-x", chipsfile])

    if not os.path.exists(outfile):
        # workaround the problem that ``chips`` sometimes just failed
        logger.warning("*** Failed to create GTI: %s ***" % outfile)
        logger.warning("You need to create the GTI manually.")
        input("When finished GTI creation, press Enter to continue ...")
    logger.info("Done!\n")


def filter_gti(infile, outfile, gti, clobber=False):
    """
    Removing flares by filtering on GTI to create the finally cleaned
    evt2 file.
    """
    clobber = "yes" if clobber else "no"
    logger.info("Filter on GTI to create cleaned evt2 file ...")
    logger.info("Outfile: %s" % outfile)
    subprocess.check_call(["punlearn", "dmcopy"])
    subprocess.check_call([
        "dmcopy", "infile=%s[@%s]" % (infile, gti),
        "outfile=%s" % outfile, "clobber=%s" % clobber
    ])
    logger.info("Done!\n")


def main():
    parser = argparse.ArgumentParser(
        description="Make a cleaned evt2 for scientific analysis")
    parser.add_argument("-i", "--infile", dest="infile",
                        help="input evt2 produced by 'chandra_repro' " +
                        "(default: request from manifest)")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing file")
    args = parser.parse_args()

    setup_pfiles(["dmkeypar", "dmcopy", "celldetect", "dmextract"])

    manifest = get_manifest()
    if args.infile:
        infile = args.infile
    else:
        infile = manifest.getpath("evt2", relative=True)
    chips = ACIS.get_chips_str(infile, sep="-")
    logger.info("infile: %s" % infile)
    logger.info("chips: %s" % chips)

    evt2_chips = "evt2_c{chips}_orig.fits".format(chips=chips)
    evt2_rmsrc = "evt2_c{chips}_rmsrc.fits".format(chips=chips)
    evt2_clean = "evt2_c{chips}_clean.fits".format(chips=chips)
    srcfile = "sources_celld.reg"
    lcfile = "ex_bkg.lc"
    gtifile = os.path.splitext(lcfile)[0] + ".gti"

    filter_chips(infile, evt2_chips, chips, clobber=args.clobber)
    detect_sources(evt2_chips, srcfile, clobber=args.clobber)
    remove_sources(evt2_chips, evt2_rmsrc, srcfile, clobber=args.clobber)
    extract_lightcurve(evt2_rmsrc, lcfile, clobber=args.clobber)
    make_gti(lcfile, gtifile, clobber=args.clobber)
    filter_gti(evt2_rmsrc, evt2_clean, gtifile, clobber=args.clobber)

    # Add cleaned evt2 to manifest
    key = "evt2_clean"
    manifest.setpath(key, evt2_clean)
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))

    # Remove useless intermediate files
    os.remove(evt2_chips)
    os.remove(evt2_rmsrc)


if __name__ == "__main__":
    main()
