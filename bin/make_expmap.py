#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Create the spectral-weighted exposure map, which will be used to produce
the exposure-corrected images and to extract the surface brightness profiles.

NOTE
----
We do not use the CIAO tool ``fluximage`` to create the exposure map,
because it requires an event file (other than an image) as input file.
However, we want to create the exposure map directly based on the
(previously created) image file.
(But an event file is required to create the aspect histograms for each
chip.)

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
* CIAO: Single Chip ACIS Exposure Map and Exposure-corrected Image
  http://cxc.harvard.edu/ciao/threads/expmap_acis_single/
* CIAO: Multiple Chip ACIS Exposure Map and Exposure-corrected Image
  http://cxc.harvard.edu/ciao/threads/expmap_acis_multi/
* CIAO: Calculating Spectral Weights for mkinstmap
  http://cxc.harvard.edu/ciao/threads/spectral_weights/
"""

import os
import argparse
import subprocess
import logging

from _context import acispy
from acispy.manifest import get_manifest
from acispy.pfiles import setup_pfiles
from acispy.acis import ACIS
from acispy.header import write_keyword
from acispy.image import get_xygrid


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def make_aspect_histogram(outfile, asol, evtfile, chip, clobber=False):
    """
    Create the aspect histogram for each chip, detailing the aspect
    history of the observation.
    """
    clobber = "yes" if clobber else "no"
    logger.info("Make aspect histogram for chip: %s" % chip)
    subprocess.check_call(["punlearn", "asphist"])
    subprocess.check_call([
        "asphist", "infile=%s" % asol, "outfile=%s" % outfile,
        "evtfile=%s[ccd_id=%s]" % (evtfile, chip),
        "clobber=%s" % clobber
    ])


def make_instrument_map(outfile, spectrumfile, chip, obsfile,
                        maskfile, badpixfile, clobber=False):
    """
    Make the spectral-weighted instrument map (effective area vs.
    detector position).

    NOTE
    ----
    The ``obsfile`` should be a FITS file containing keywords which specify
    the mission, detector, SIM offsets, observation date, etc.  This should
    be an event file; can also be a binned image file (tested OK).
    """
    logger.info("Set bad pixel file: %s" % badpixfile)
    subprocess.check_call(["punlearn", "ardlib"])
    subprocess.check_call(["punlearn", "acis_set_ardlib"])
    subprocess.check_call([
        "acis_set_ardlib", "badpixfile=%s" % badpixfile, "verbose=0"
    ])

    clobber = "yes" if clobber else "no"
    pixelgrid = "1:1024:#1024,1:1024:#1024"
    logger.info("Make spectral-weighted instrument map for chip: %s" % chip)
    subprocess.check_call(["punlearn", "mkinstmap"])
    subprocess.check_call([
        "mkinstmap", "outfile=%s" % outfile,
        "spectrumfile=%s" % spectrumfile,
        "pixelgrid=%s" % pixelgrid,
        "detsubsys=ACIS-%s" % chip,
        "obsfile=%s" % obsfile,
        "maskfile=%s" % maskfile,
        "clobber=%s" % clobber, "mode=h"
    ])


def make_exposure_map(outfile, asphistfile, instmapfile, xygrid,
                      clobber=False):
    """
    Create the spectral-weighted exposure map by projecting the instrument
    map onto the sky with the aspect information.
    """
    clobber = "yes" if clobber else "no"
    logger.info("Make exposure map by projecting instrument map ...")
    subprocess.check_call(["punlearn", "mkexpmap"])
    subprocess.check_call([
        "mkexpmap", "outfile=%s" % outfile,
        "asphistfile=%s" % asphistfile,
        "instmapfile=%s" % instmapfile,
        "xygrid=%s" % xygrid,
        "normalize=no", "useavgaspect=no",
        "clobber=%s" % clobber, "mode=h"
    ])


def combine_expmaps(outfile, expmaps, clobber=False):
    """
    Combine multiple exposure maps of each chip into a single one
    for ACIS-I (i.e., chips 0123).
    """
    if len(expmaps) > 1:
        logger.info("Combine exposure maps: {0}".format(", ".join(expmaps)))
        operation = "imgout=%s" % "+".join([
            "img%d" % (i+1) for i in range(len(expmaps))
        ])
        clobber = "yes" if clobber else "no"
        subprocess.check_call(["punlearn", "dmimgcalc"])
        subprocess.check_call([
            "dmimgcalc", "infile=%s" % ",".join(expmaps),
            "infile2=none", "outfile=%s" % outfile,
            "operation=%s" % operation,
            "clobber=%s" % clobber
        ])
        for f in expmaps:
            os.remove(f)
    else:
        logger.info("No need to combine exposure maps.")
        if os.path.exists(outfile) and (not clobber):
            raise OSError("File already exists: %s" % outfile)
        os.rename(expmaps[0], outfile)


def main():
    parser = argparse.ArgumentParser(
        description="Make spectral-weighted exposure map")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing file")
    parser.add_argument("-w", "--weights", dest="weights",
                        help="spectral weights file (default: " +
                        "'spec_weights' from manifest)")
    parser.add_argument("-e", "--evtfile", dest="evtfile",
                        help="event file for aspect histogram creation " +
                        "(default: 'evt2_clean' from manifest)")
    parser.add_argument("-i", "--infile", dest="infile", required=True,
                        help="input image file")
    parser.add_argument("-o", "--outfile", dest="outfile", required=True,
                        help="filename of output exposure map")
    args = parser.parse_args()

    setup_pfiles(["get_sky_limits", "asphist", "mkinstmap", "ardlib",
                  "acis_set_ardlib", "mkexpmap", "dmimgcalc"])

    manifest = get_manifest()
    if args.weights:
        weights = args.weights
    else:
        weights = manifest.getpath("spec_weights", relative=True)
    if args.evtfile:
        evtfile = args.evtfile
    else:
        evtfile = manifest.getpath("evt2_clean", relative=True)
    asol = manifest.getpath("asol", relative=True, sep=",")
    bpix = manifest.getpath("bpix", relative=True)
    msk = manifest.getpath("msk", relative=True)
    chips = ACIS.get_chips_str(args.infile)
    logger.info("infile: %s" % args.infile)
    logger.info("output expmap: %s" % args.outfile)
    logger.info("weights: %s" % weights)
    logger.info("evtfile: %s" % evtfile)
    logger.info("chips: %s" % chips)
    logger.info("bpix: %s" % bpix)
    logger.info("asol: %s" % asol)
    logger.info("msk: %s" % msk)

    xygrid = get_xygrid(args.infile)
    logger.info("%s:xygrid: %s" % (args.infile, xygrid))
    expmaps = []

    for c in chips:
        logger.info("Processing chip %s ..." % c)
        asphist = "asphist_c{chip}.fits".format(chip=c)
        instmap = "instmap_c{chip}.fits".format(chip=c)
        expmap = "expmap_c{chip}.fits".format(chip=c)
        make_aspect_histogram(outfile=asphist, asol=asol, evtfile=evtfile,
                              chip=c, clobber=args.clobber)
        make_instrument_map(outfile=instmap, spectrumfile=weights,
                            chip=c, obsfile=args.infile, maskfile=msk,
                            badpixfile=bpix, clobber=args.clobber)
        make_exposure_map(outfile=expmap, asphistfile=asphist,
                          instmapfile=instmap, xygrid=xygrid,
                          clobber=args.clobber)
        expmaps.append(expmap)
        # Remove intermediate files
        os.remove(asphist)
        os.remove(instmap)

    combine_expmaps(outfile=args.outfile, expmaps=expmaps,
                    clobber=args.clobber)
    detnam = "ACIS-{0}".format(chips)
    logger.info("Update keyword 'DETNAM' to %s" % detnam)
    write_keyword(args.outfile, keyword="DETNAM", value=detnam)

    logger.info("Add created exposure map to manifest ...")
    key = "expmap"
    manifest.setpath(key, args.outfile)
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))


if __name__ == "__main__":
    main()
