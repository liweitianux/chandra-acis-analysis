# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Wrapper function to view FITS files using DS9.
"""

import subprocess


def ds9_view(filename, regfile=None, regformat="ciao", regsystem="physical",
             cmap="he", binfactor=2, scale="linear", smooth=None):
    """
    Wrapper function to view FITS files using DS9.
    """
    cmd = [
        "ds9", filename,
        "-regions", "format", regformat,
        "-regions", "system", regsystem,
        "-regions", regfile,
        "-cmap", cmap,
        "-bin", "factor", binfactor,
        "-scale", scale,
    ]
    if smooth:
        cmd += ["-smooth", "yes", "-smooth", "radius", smooth]
    subprocess.check_call(cmd)
