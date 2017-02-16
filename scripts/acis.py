# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Chandra ACIS utilities
"""

import math


class ACIS:
    """
    Chandra ACIS detector properties and utilities.

    References
    ----------
    [1] CIAO - dictionary - ACIS (advanced camera for imaging and spectroscopy)
        http://cxc.harvard.edu/ciao/dictionary/acis.html
    [2] CIAO - Dictionary - PI (pulse invariant)
        http://cxc.harvard.edu/ciao/dictionary/pi.html
    """
    # Pixel size
    pixel2arcsec = 0.492  # [arcsec]
    # Number of channels
    nchannel = 1024
    # Channel energy width
    echannel = 14.6  # [eV]

    @classmethod
    def energy2channel(self, energy):
        """
        Convert energy [eV] to channel number.
        """
        return math.floor(energy/self.echannel + 1)
