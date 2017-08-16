#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <weitian@aaronly.me>
# MIT license

"""
Update the manifest.yaml with generated products.
"""

import os
import argparse
import logging
from glob import glob
from collections import OrderedDict

from _context import acispy
from acispy.manifest import get_manifest


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_path(pglob, pdir=None):
    if pdir is not None:
        pglob = os.path.join(pdir, pglob)
    p = glob(pglob)
    if len(p) == 0:
        return None
    elif len(p) == 1:
        return p[0]
    else:
        return p


def add_directory(manifest):
    """
    Add the directory where this manifest file locates as the item
    ``directory`` into the manifest.
    """
    directory = os.path.dirname(manifest.filepath)
    manifest.set("directory", directory)


def add_repro(reprodir, manifest):
    """
    Add the generated products by ``chandra_repro`` to the manifest.
    """
    logger.info("Adding repro products from: {0}".format(reprodir))
    keyglobs = OrderedDict([
        ("evt2", "acisf*_repro_evt2.fits"),
        ("bpix", "acisf*_repro_bpix1.fits"),
        ("fov",  "acisf*_repro_fov1.fits"),
        ("asol", "pcadf*_asol?.fits"),  # maybe multiple
        ("pbk",  "acisf*_pbk0.fits"),
        ("msk",  "acisf*_msk1.fits"),
    ])
    for k, g in keyglobs.items():
        p = get_path(g, pdir=reprodir)
        manifest.setpath(k, p)


def main():
    manifestfile = "manifest.yaml"

    parser = argparse.ArgumentParser(
        description="Update %s with generated products" % manifestfile)
    parser.add_argument("-c", "--create", dest="create",
                        action="store_true",
                        help="create '%s' under current " % manifestfile +
                        "working directory if not exists")
    parser.add_argument("-D", "--add-directory", dest="add_directory",
                        action="store_true",
                        help="add an 'directory' item to the manifest " +
                        "storing the directory where the manifest locates")
    parser.add_argument("-r", "--repro", dest="reprodir", default=None,
                        help="path to the repro directory; add the " +
                        "reprocessed products to manifest if specified")
    args = parser.parse_args()

    if (not os.path.exists(manifestfile)) and args.create:
        logger.info("Create %s" % manifestfile)
        open(manifestfile, "a").close()
    manifest = get_manifest()

    if args.reprodir:
        add_repro(reprodir=args.reprodir, manifest=manifest)


if __name__ == "__main__":
    main()
