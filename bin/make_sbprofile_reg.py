#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Make the radial surface brightness profile (SBP) regions, consisting a series
of annulus/pie regions, which later been used to extract the SBP.

Algorithm
---------
1. innermost 10 regions, meet the following two conditions:
   * width >=5 pixels
   * >=50 counts within 0.7-7.0 keV
2. outer regions:
   * R_out = R_in * ratio (e.g., 1.2)
   * signal-to-noise ratio (SNR) >= threshold (e.g., 1.5)
"""

import os
import argparse
import subprocess
import logging
import tempfile
import shutil
import math

from _context import acispy
from acispy.header import read_keyword
from acispy.manifest import get_manifest
from acispy.ciao import setup_pfiles
from acispy.region import Regions
from acispy.spectrum import Spectrum
from acispy.ds9 import ds9_view


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def extract_spec(outfile, evtfile, region, clobber=False):
    """
    Extract the spectrum within region from the event file.
    """
    clobber = "yes" if clobber else "no"
    subprocess.check_call(["punlearn", "dmextract"])
    subprocess.check_call([
        "dmextract", "infile=%s[sky=%s][bin pi]" % (evtfile, region),
        "outfile=%s" % outfile, "clobber=%s" % clobber
    ])


def calc_snr(region, evt, bkg=None, elow=700, ehigh=7000,
             elow_pb=9500, ehigh_pb=12000):
    """
    Calculate the signal-to-noise ratio (SNR) for the source spectrum
    with respect to the background spectrum, with particle background
    renormalization considered.

    The source and background spectra are extracted from the corresponding
    event files within the given region.

    NOTE
    ----
    * If the given background is already a spectrum (e.g., the corrected
      background spectrum), then just use it;
    * If ``bkg=None``, then just return ``math.inf``.

    Definition
    ----------
    SNR = (flux_src / flux_bkg) * (pbflux_bkg / pbflux_src)

    Parameters
    ----------
    region : str
        Region string within which to calculate the SNR
    evt : str
        Input (source) event file
    bkg : str, optional
        Filename of the background event file or corrected background
        spectrum.
    elow, ehigh : float, optional
        Lower and upper energy limit to calculate the photon counts.
    elow_pb, ehigh_pb : float, optional
        Lower and upper energy limit of the particle background.
    """
    if bkg is None:
        return math.inf

    tf1 = tempfile.NamedTemporaryFile()
    tf2 = tempfile.NamedTemporaryFile()
    # Source spectrum
    extract_spec(tf1.name, evtfile=evt, region=region, clobber=True)
    # Background spectrum
    if read_keyword(bkg, keyword="HDUCLAS1")["value"] == "SPECTRUM":
        shutil.copy(bkg, tf2.name)
    else:
        extract_spec(tf2.name, evtfile=bkg, region=region, clobber=True)
    # Calculate SNR
    spec = Spectrum(tf1.name)
    spec_bkg = Spectrum(tf2.name)
    flux = spec.calc_flux(elow=elow, ehigh=ehigh)
    flux_bkg = spec_bkg.calc_flux(elow=elow, ehigh=ehigh)
    pbflux = spec.calc_pb_flux(elow=elow_pb, ehigh=ehigh_pb)
    pbflux_bkg = spec_bkg.calc_pb_flux(elow=elow_pb, ehigh=ehigh_pb)
    snr = (flux / flux_bkg) * (pbflux_bkg / pbflux)
    tf1.close()
    tf2.close()
    return snr


def get_counts(evtfile, region, elow=700, ehigh=7000):
    fenergy = "energy=%s:%s" % (elow, ehigh)
    subprocess.check_call(["punlearn", "dmlist"])
    output = subprocess.check_output([
        "dmlist", "infile=%s[%s][sky=%s]" % (evtfile, fenergy, region),
        "opt=counts"
    ]).decode("utf-8").strip()
    counts = int(output)
    return counts


def gen_regions_inner(evtfile, center, rin,
                      min_width=5, min_counts=50,
                      elow=700, ehigh=7000):
    """
    Generate the innermost regions, which meets the following conditions:
    * width >=5 pixels
    * >=50 counts within 0.7-7.0 keV
    """
    x, y = center
    rout = rin + min_width
    region = "pie(%s,%s,%.2f,%.2f,0,360)" % (x, y, rin, rout)
    counts = get_counts(evtfile, region=region, elow=elow, ehigh=ehigh)
    while counts < min_counts:
        rout += 1
        region = "pie(%s,%s,%.2f,%.2f,0,360)" % (x, y, rin, rout)
        counts = get_counts(evtfile, region=region, elow=elow, ehigh=ehigh)
    return (rout, region)


def gen_regions(center, evt, bkg=None, n_inner=10, min_counts=50,
                min_width=5, ratio_radius=1.2, snr_thresh=1.5,
                elow=700, ehigh=7000, elow_pb=9500, ehigh_pb=12000):
    """
    Generate the SBP regions, consisting the inner- and outer-type two parts.
    """
    regions = []
    logger.info("Generating %d inner-type regions ..." % n_inner)
    rin = 0.0
    for i in range(n_inner):
        rout, region = gen_regions_inner(
            evtfile=evt, center=center, rin=rin, min_width=min_width,
            min_counts=min_counts, elow=elow, ehigh=ehigh)
        rin = rout
        snr = calc_snr(region, evt=evt, bkg=bkg, elow=elow, ehigh=ehigh,
                       elow_pb=elow_pb, ehigh_pb=ehigh_pb)
        regions.append(region)
        logger.info("Region #%d: %s; SNR=%.3f" %
                    (len(regions), regions[-1], snr))
    logger.info("Generating outer-type regions (SNR >= %s) ..." % snr_thresh)
    x, y = center
    rout = rin * ratio_radius
    region = "pie(%s,%s,%.2f,%.2f,0,360)" % (x, y, rin, rout)
    counts = get_counts(evt, region=region, elow=elow, ehigh=ehigh)
    while counts >= min_counts:
        snr = calc_snr(region, evt=evt, bkg=bkg, elow=elow, ehigh=ehigh,
                       elow_pb=elow_pb, ehigh_pb=ehigh_pb)
        if snr < snr_thresh:
            break
        regions.append(region)
        logger.info("Region #%d: %s; SNR=%.3f" %
                    (len(regions), regions[-1], snr))
        rin = rout
        rout = rin * ratio_radius
        region = "pie(%s,%s,%.2f,%.2f,0,360)" % (x, y, rin, rout)
        counts = get_counts(evt, region=region, elow=elow, ehigh=ehigh)
    logger.info("Finished with %d SBP regions." % len(regions))
    return regions


def main():
    parser = argparse.ArgumentParser(
        description="Make the SBP regions")
    parser.add_argument("-L", "--elow", dest="elow",
                        type=int, default=700,
                        help="lower energy limit to calculate the photon " +
                        "counts [eV] (default: 700 eV)")
    parser.add_argument("-H", "--ehigh", dest="ehigh",
                        type=int, default=7000,
                        help="upper energy limit to calculate the photon " +
                        "counts [eV] (default: 7000 eV)")
    parser.add_argument("-p", "--elow-pb", dest="elow_pb",
                        type=int, default=9500,
                        help="lower energy limit of the particle " +
                        "background [eV] (default: 9500 eV)")
    parser.add_argument("-P", "--ehigh-pb", dest="ehigh_pb",
                        type=int, default=12000,
                        help="upper energy limit of the particle " +
                        "background [eV] (default: 12000 eV)")
    parser.add_argument("-m", "--min-counts", dest="min_counts",
                        type=int, default=50,
                        help="minimum photon counts of echo SBP " +
                        "region (default: 50)")
    parser.add_argument("-M", "--min-width", dest="min_width",
                        type=int, default=5,
                        help="minimum annulus/pie width of the inner-type " +
                        "regions (default: 5 [pix])")
    parser.add_argument("-N", "--n-inner", dest="n_inner",
                        type=int, default=10,
                        help="number of the inner-type regions (default: 10)")
    parser.add_argument("-R", "--ratio-radius", dest="ratio_radius",
                        type=float, default=1.2,
                        help="ratio of outer radius w.r.t. inner radius " +
                        "(default: 1.2)")
    parser.add_argument("-S", "--snr-thresh", dest="snr_thresh",
                        type=float, default=1.5,
                        help="lower threshold of the SNR (default: 1.5)")
    parser.add_argument("-V", "--view", dest="view", action="store_true",
                        help="open DS9 to view output centroid")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing files")
    parser.add_argument("-b", "--bkg", dest="bkg",
                        help="background file for SNR calculation; " +
                        "may be blanksky or corrected background spectrum")
    parser.add_argument("-c", "--center", dest="center",
                        help="Region file specifying the center " +
                        "(default: 'reg_centroid' from manifest)")
    parser.add_argument("-i", "--infile", dest="infile",
                        help="input event file " +
                        "(default: 'evt2_clean' from manifest)")
    parser.add_argument("-o", "--outfile", dest="outfile",
                        default="sbprofile.reg",
                        help="output SBP region filename " +
                        "(default: sbprofile.reg)")
    args = parser.parse_args()

    if os.path.exists(args.outfile):
        if args.clobber:
            os.remove(args.outfile)
        else:
            raise OSError("File already exists: %s" % args.outfile)

    setup_pfiles(["dmlist", "dmstat", "dmextract"])

    manifest = get_manifest()
    if args.infile:
        infile = args.infile
    else:
        infile = manifest.getpath("evt2_clean", relative=True)
    if args.center:
        center_reg = args.center
    else:
        center_reg = manifest.getpath("reg_centroid", relative=True)
    region = Regions(center_reg).regions[0]
    center = (region.xc, region.yc)

    regions = gen_regions(center=center, evt=infile, bkg=args.bkg,
                          n_inner=args.n_inner,
                          min_counts=args.min_counts,
                          min_width=args.min_width,
                          ratio_radius=args.ratio_radius,
                          snr_thresh=args.snr_thresh,
                          elow=args.elow, ehigh=args.ehigh,
                          elow_pb=args.elow_pb, ehigh_pb=args.ehigh_pb)
    open(args.outfile, "w").write("\n".join(regions) + "\n")
    if args.view:
        ds9_view(infile, regfile=args.outfile)

    # Add generated SBP region file to manifest
    key = "sbp_reg"
    manifest.setpath(key, args.outfile)
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))


if __name__ == "__main__":
    main()
