#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Calculate the coordinate of the emission centroid within the image.

The image are smoothed first, and then an iterative procedure with
two phases is applied to determine the emission centroid.
"""

import os
import sys
import argparse
import subprocess
import tempfile

from _context import acispy
from acispy.manifest import get_manifest
from acispy.pfiles import setup_pfiles
from acispy.ds9 import ds9_view
from acispy.region import Regions


def smooth_image(infile, outfile=None,
                 kernelspec="lib:gaus(2,5,1,10,10)", method="fft",
                 clobber=False):
    """
    Smooth the image by a Gaussian kernel using the ``aconvolve`` tool.

    Parameters
    ----------
    infile : str
        Path to the input image file
    outfile : str, optional
        Filename/path of the output smoothed image
        (default: build in format ``<infile_basename>_aconv.fits``)
    kernelspec : str, optional
        Kernel specification for ``aconvolve``
    method : str, optional
        Smooth method for ``aconvolve``

    Returns
    -------
    outfile : str
        Filename/path of the smoothed image
    """
    clobber = "yes" if clobber else "no"
    if outfile is None:
        outfile = os.path.splitext(infile)[0] + "_aconv.fits"
    subprocess.check_call(["punlearn", "aconvolve"])
    subprocess.check_call([
        "aconvolve", "infile=%s" % infile, "outfile=%s" % outfile,
        "kernelspec=%s" % kernelspec, "method=%s" % method,
        "clobber=%s" % clobber
    ])
    return outfile


def get_peak(image, center=None, radius=300):
    """
    Get the peak coordinate on the image within the circle if specified.

    Parameters
    ----------
    image : str
        Path to the image file.
    center : 2-float tuple
        Central (physical) coordinate of the circle.
    radius : float
        Radius (pixel) of the circle.

    Returns
    -------
    peak : 2-float tuple
        (Physical) coordinate of the peak.
    """
    subprocess.check_call(["punlearn", "dmstat"])
    subprocess.check_call([
        "dmstat", "infile=%s" % image,
        "centroid=no", "media=no", "sigma=no", "clip=no"
    ])
    peak = subprocess.check_output([
        "pget", "dmstat", "out_max_loc"
    ]).decode("utf-8").strip()
    peak = peak.split(",")
    return (float(peak[0]), float(peak[1]))


def get_centroid(image, center, radius=100):
    """
    Calculate the centroid on image within the specified circle.

    Parameters
    ----------
    image : str
        Path to the image file.
    center : 2-float tuple
        Central (physical) coordinate of the circle.
    radius : float
        Radius (pixel) of the circle.

    Returns
    -------
    centroid : 2-float tuple
        (Physical) coordinate of the centroid.
    """
    x, y = center
    with tempfile.NamedTemporaryFile(mode="w+") as fp:
        fp.file.write("circle(%f,%f,%f)\n" % (x, y, radius))
        fp.file.flush()
        subprocess.check_call(["punlearn", "dmstat"])
        subprocess.check_call([
            "dmstat", "infile=%s[sky=region(%s)]" % (image, fp.name),
            "centroid=yes", "media=no", "sigma=no", "clip=no"
        ])
    centroid = subprocess.check_output([
        "pget", "dmstat", "out_cntrd_phys"
    ]).decode("utf-8").strip()
    centroid = centroid.split(",")
    return (float(centroid[0]), float(centroid[1]))


def main():
    parser = argparse.ArgumentParser(
        description="Calculate the emission centroid within the image")
    parser.add_argument("-i", "--infile", dest="infile", required=True,
                        help="input image file (e.g., 0.7-2.0 keV)")
    parser.add_argument("-o", "--outfile", dest="outfile",
                        default="centroid.reg",
                        help="output centroid region file " +
                        "(default: centroid.reg")
    parser.add_argument("-R", "--radius1", dest="radius1",
                        type=float, default=300,
                        help="circle radius [pixel] for first phase " +
                        "centroid calculation (default: 300 pixel)")
    parser.add_argument("-r", "--radius2", dest="radius2",
                        type=float, default=100,
                        help="circle radius [pixel] for second phase " +
                        "calculation to tune centroid (default: 100 pixel)")
    parser.add_argument("-n", "--niter", dest="niter",
                        type=int, default=5,
                        help="iterations for each phase (default: 5)")
    parser.add_argument("-s", "--start", dest="start",
                        help="a region file containing a circle/point " +
                        "that specifies the starting point " +
                        "(default: using the peak of the image)")
    parser.add_argument("-V", "--view", dest="view", action="store_true",
                        help="open DS9 to view output centroid")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing files")
    args = parser.parse_args()

    setup_pfiles(["aconvolve", "dmstat"])

    print("Smooth input image using 'aconvolve' ...", file=sys.stderr)
    img_smoothed = smooth_image(args.infile, clobber=args.clobber)

    if args.start:
        print("Get starting point from region file: %s" % args.start,
              file=sys.stderr)
        region = Regions(args.start).regions[0]
        center = (region.xc, region.yc)
    else:
        print("Use peak as the starting point ...", file=sys.stderr)
        center = get_peak(img_smoothed)
    print("Starting point: (%f, %f)" % center, file=sys.stderr)

    centroid = center
    for phase, radius in enumerate([args.radius1, args.radius2]):
        print("Calculate centroid phase %d (circle radius: %.1f)" %
              (phase+1, radius), file=sys.stderr)
        for i in range(args.niter):
            print("%d..." % (i+1), end="", flush=True, file=sys.stderr)
            centroid = get_centroid(img_smoothed, center=centroid,
                                    radius=radius)
        print("Done!", file=sys.stderr)

    with open(args.outfile, "w") as f:
        f.write("point(%f,%f)\n" % centroid)
    print("Saved centroid to file:", args.outfile, file=sys.stderr)
    if args.view:
        ds9_view(img_smoothed, regfile=args.outfile)

    # Add calculated centroid region to manifest
    manifest = get_manifest()
    key = "reg_centroid"
    manifest.setpath(key, args.outfile)


if __name__ == "__main__":
    main()
