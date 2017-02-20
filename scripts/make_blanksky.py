#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Make the "blank-sky" background for spectral analysis.

This tool first finds the corresponding blank-sky files for this observation,
then apply further filtering and gain corrections, and finally reproject
the coordinates to matching the observational data.


Reference
---------
* Analyzing the ACIS Background with "Blank-sky" Files
  http://cxc.harvard.edu/ciao/threads/acisbackground/
"""

import os
import argparse
import subprocess
import shutil
import stat
import logging

from _context import acispy
from acispy.manifest import get_manifest
from acispy.pfiles import setup_pfiles
from acispy.acis import ACIS
from acispy.header import write_keyword, copy_keyword


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def find_blanksky(infile, copy=True, clobber=False):
    """
    Find the blanksky files for the input file using ``acis_bkgrnd_lookup``
    tool, and copy the files to current directory if ``copy=True``.
    """
    subprocess.check_call(["punlearn", "acis_bkgrnd_lookup"])
    subprocess.check_call(["acis_bkgrnd_lookup", "infile=%s" % infile])
    bkgfiles = subprocess.check_output([
        "pget", "acis_bkgrnd_lookup", "outfile"
    ]).decode("utf-8").strip()
    bkgfiles = bkgfiles.split(",")
    logger.info("Found blanksky files: {0}".format(bkgfiles))
    if copy:
        logger.info("Copy blanksky files into CWD ...")
        for f in bkgfiles:
            if os.path.exists(os.path.basename(f)) and (not clobber):
                raise OSError("File already exists: %s" % os.path.basename(f))
            shutil.copy(f, ".")
        bkgfiles = [os.path.basename(f) for f in bkgfiles]
    return bkgfiles


def merge_blanksky(infiles, outfile, clobber=False):
    """
    Merge multiple blanksky files (e.g., 4 blanksky files for ACIS-I)
    into a single file.
    """
    if len(infiles) == 1:
        logger.info("Only one blanksky file, no need to merge.")
        if os.path.exists(outfile) and (not clobber):
            raise OSError("File already exists: %s" % outfile)
        shutil.move(infiles[0], outfile)
    else:
        logger.info("Merge multiple blanksky files ...")
        clobber = "yes" if clobber else "no"
        subprocess.check_call(["punlearn", "dmmerge"])
        subprocess.check_call([
            "dmmerge", "infile=%s" % ",".join(infiles),
            "outfile=%s" % outfile, "clobber=%s" % clobber
        ])
        write_keyword(outfile, keyword="DETNAM", value="ACIS-0123")
        for f in infiles:
            os.remove(f)
    # Add write permission to the background file
    st = os.stat(outfile)
    os.chmod(outfile, st.st_mode | stat.S_IWUSR)


def clean_vfaint(infile, outfile, clobber=False):
    """
    Clean the background file by only keeping events with ``status=0``
    for ``VFAINT`` mode observations.
    """
    subprocess.check_call(["punlearn", "dmkeypar"])
    datamode = subprocess.check_output([
        "dmkeypar", "infile=%s" % infile,
        "keyword=DATAMODE", "echo=yes"
    ]).decode("utf-8").strip()
    logger.info("DATAMODE: %s" % datamode)
    if datamode.upper() == "VFAINT":
        logger.info("Clean background file using 'status=0' ...")
        clobber = "yes" if clobber else "no"
        subprocess.check_call(["punlearn", "dmcopy"])
        subprocess.check_call([
            "dmcopy", "infile=%s[status=0]" % infile,
            "outfile=%s" % outfile, "clobber=%s" % clobber
        ])
        os.remove(infile)
    else:
        logger.info("No need to clean the background file.")
        if os.path.exists(outfile) and (not clobber):
            raise OSError("File already exists: %s" % outfile)
        shutil.move(infile, outfile)


def apply_gainfile(infile, outfile, evt2, clobber=False):
    """
    Check whether the ``GAINFILE`` of the background file matches that
    of the observational evt2 file.

    If they are different, then reprocess the background file with the
    same ``GAINFILE`` of the evt2 file.
    """
    subprocess.check_call(["punlearn", "dmkeypar"])
    gainfile_bkg = subprocess.check_output([
        "dmkeypar", "infile=%s" % infile,
        "keyword=GAINFILE", "echo=yes"
    ]).decode("utf-8").strip()
    gainfile_evt2 = subprocess.check_output([
        "dmkeypar", "infile=%s" % evt2,
        "keyword=GAINFILE", "echo=yes"
    ]).decode("utf-8").strip()
    if gainfile_bkg == gainfile_evt2:
        logger.info("GAINFILE's are the same for background and evt2.")
        if os.path.exists(outfile) and (not clobber):
            raise OSError("File already exists: %s" % outfile)
        shutil.move(infile, outfile)
    else:
        # Reprocess the background
        gainfile = os.path.join(os.environ["CALDB"],
                                "data/chandra/acis/det_gain",
                                gainfile_evt2)
        logger.info("Reprocess background using gainfile: %s ..." % gainfile)
        clobber = "yes" if clobber else "no"
        eventdef = [
            "s:ccd_id", "s:node_id", "i:expno", "s:chip",
            "s:tdet", "f:det", "f:sky", "s:phas",
            "l:pha", "l:pha_ro", "f:energy", "l:pi",
            "s:fltgrade", "s:grade", "x:status"
        ]
        subprocess.check_call(["punlearn", "acis_process_events"])
        subprocess.check_call([
            "acis_process_events", "infile=%s" % infile,
            "outfile=%s" % outfile, "acaofffile=NONE", "stop=none",
            "doevtgrade=no", "apply_cti=yes", "apply_tgain=no",
            "calculate_pi=yes", "pix_adj=NONE", "gainfile=%s" % gainfile,
            "eventdef={%s}" % ",".join(eventdef),
            "clobber=%s" % clobber
        ])
        os.remove(infile)


def reproject_blanksky(infile, outfile, evt2, asol, clobber=False):
    """
    Reproject the background to match the coordinates of the observational
    evt2 data.
    """
    clobber = "yes" if clobber else "no"
    logger.info("Reprojecting the background to match the evt2 file ...")
    subprocess.check_call(["punlearn", "reproject_events"])
    subprocess.check_call([
        "reproject_events", "infile=%s" % infile, "outfile=%s" % outfile,
        "aspect=%s" % asol, "match=%s" % evt2, "random=0",
        "clobber=%s" % clobber
    ])
    os.remove(infile)


def main():
    parser = argparse.ArgumentParser(
        description="Make blanksky background")
    parser.add_argument("-i", "--infile", dest="infile",
                        help="input evt2 file " +
                        "(default: 'evt2_clean' from manifest)")
    parser.add_argument("-o", "--outfile", dest="outfile",
                        help="output blanksky background file " +
                        "(default: 'blanksky_c{chips}.fits')")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing file")
    args = parser.parse_args()

    setup_pfiles(["acis_bkgrnd_lookup", "dmcopy", "dmmerge", "dmkeypar",
                  "dmhedit", "reproject_events", "acis_process_events"])

    manifest = get_manifest()
    if args.infile:
        infile = args.infile
    else:
        infile = manifest.getpath("evt2_clean", relative=True)
    chips = ACIS.get_chips_str(infile, sep="-")
    if args.outfile:
        outfile = args.outfile
    else:
        outfile = "blanksky_c{chips}.fits".format(chips=chips)
    asol = manifest.getpath("asol", relative=True, sep=",")
    logger.info("infile: %s" % infile)
    logger.info("outfile: %s" % outfile)
    logger.info("chips: %s" % chips)
    logger.info("asol: %s" % asol)

    bkgfiles = find_blanksky(infile, copy=True, clobber=args.clobber)
    bkg_orig = os.path.splitext(outfile)[0] + "_orig.fits"
    merge_blanksky(bkgfiles, bkg_orig, clobber=args.clobber)
    bkg_clean = os.path.splitext(outfile)[0] + "_clean.fits"
    clean_vfaint(bkg_orig, bkg_clean, clobber=args.clobber)
    bkg_gained = os.path.splitext(outfile)[0] + "_gained.fits"
    apply_gainfile(bkg_clean, bkg_gained, evt2=infile, clobber=args.clobber)
    # Add the PNT header keywords
    copy_keyword(infile, bkg_gained,
                 keyword=["RA_PNT", "DEC_PNT", "ROLL_PNT"])
    reproject_blanksky(bkg_gained, outfile, evt2=infile,
                       asol=asol, clobber=args.clobber)

    # Add blanksky background to manifest
    key = "bkg_blank"
    manifest.setpath(key, outfile)
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))


if __name__ == "__main__":
    main()
