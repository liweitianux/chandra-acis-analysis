#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license
#
# 2017-02-27

"""
Reprocess Chandra ACIS raw "secondary" (level=1) data using the
CIAO contrib tool ``chandra_repro``, and build the ``manifest.yaml``.
"""

import os
import argparse
import subprocess
import logging
from glob import glob

from _context import acispy
from acispy.manifest import get_manifest
from acispy.pfiles import setup_pfiles


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def repro_acis(indir=".", outdir="repro", clobber=False):
    """
    Reprocess Chandra ACIS raw level=1 data using ``chandra_repro``.
    """
    logger.info("Reprocess Chandra ACIS raw level=1 data ...")
    clobber = "yes" if clobber else "no"
    subprocess.check_call(["punlearn", "ardlib"])
    subprocess.check_call(["punlearn", "chandra_repro"])
    subprocess.check_call([
        "chandra_repro", "indir=%s" % indir, "outdir=%s" % outdir,
        "verbose=2", "clobber=%s" % clobber
    ])
    logger.info("Fix asol.lis by striping the absolute directory ...")
    asol_lis = glob("%s/acisf*_asol1.lis" % outdir)[0]
    asol = [os.path.basename(fp) for fp in open(asol_lis).readlines()]
    os.rename(asol_lis, asol_lis+".orig")
    open(asol_lis, "w").writelines(asol)


def build_manifest(reprodir="repro", manifestfile="manifest.yaml"):
    """
    Build the ``manifest.yaml`` with reprocessed products.
    """
    logger.info("Build manifest with reprocessed products ...")
    if os.path.exists(manifestfile):
        logger.info("Use existing manifest file: %s" % manifestfile)
    else:
        logger.info("Create a new manifest file: %s" % manifestfile)
        open(manifestfile, "w").close()

    manifest = get_manifest(manifestfile)
    key = "directory"
    manifest.set(key, os.path.basename(os.getcwd()))
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
    key = "evt2"
    manifest.setpath(key, glob("%s/acisf*_repro_evt2.fits" % reprodir))
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
    key = "bpix"
    manifest.setpath(key, glob("%s/acisf*_repro_bpix1.fits" % reprodir))
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
    key = "asol"
    manifest.setpath(key, glob("%s/pcadf*_asol1.fits" % reprodir))
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
    key = "asol_lis"
    manifest.setpath(key, glob("%s/acisf*_asol1.lis" % reprodir))
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
    key = "fov"
    manifest.setpath(key, glob("%s/acisf*_repro_fov1.fits" % reprodir))
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
    key = "pbk"
    manifest.setpath(key, glob("%s/acisf*_pbk0.fits" % reprodir))
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))
    key = "msk"
    manifest.setpath(key, glob("%s/acisf*_msk1.fits" % reprodir))
    logger.info("Added '%s' to manifest: %s" % (key, manifest.get(key)))


def main():
    parser = argparse.ArgumentParser(
            description="Extract surface brightness profile (SBP)")
    parser.add_argument("-C", "--clobber", dest="clobber", action="store_true",
                        help="overwrite existing file")
    args = parser.parse_args()

    setup_pfiles(["chandra_repro", "ardlib"])

    repro_acis(clobber=args.clobber)
    build_manifest()


if __name__ == "__main__":
    main()
