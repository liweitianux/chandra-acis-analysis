# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
FITS image utilities
"""

import subprocess


def get_xygrid(image):
    """
    Get the ``xygrid`` of the input image.
    """
    subprocess.check_call(["punlearn", "get_sky_limits"])
    subprocess.check_call([
        "get_sky_limits", "image=%s" % image, "verbose=0"
    ])
    xygrid = subprocess.check_output([
        "pget", "get_sky_limits", "xygrid"
    ]).decode("utf-8").strip()
    return xygrid
