# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Chandra ACIS utilities
"""

import math
import subprocess
import re


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
    def energy2channel(cls, energy):
        """
        Convert energy [eV] to channel number.
        """
        return math.floor(energy/cls.echannel + 1)

    @staticmethod
    def get_type(filepath):
        """
        Determine the Chandra ACIS type (``I`` or ``S``) according the
        active ACIS chips.

        Parameters
        ----------
        filepath : str
            Path to the input FITS file

        Returns
        -------
        acis_type : str
            ``I`` if ACIS-I, ``S`` if ACIS-S;
            otherwise, ``ValueError`` raised.
        """
        subprocess.check_call(["punlearn", "dmkeypar"])
        detnam = subprocess.check_output([
            "dmkeypar", "infile=%s" % filepath, "keyword=DETNAM", "echo=yes"
        ]).decode("utf-8").strip()
        if re.match(r"^ACIS-0123", detnam):
            return "I"
        elif re.match(r"^ACIS-[0-6]*7", detnam):
            return "S"
        else:
            raise ValueError("unknown chip combination: %s" % detnam)

    @classmethod
    def get_chips_str(cls, filepath, sep=None):
        """
        Return a string of the chips of interest according to the
        active ACIS type.

        Parameters
        ----------
        filepath : str
            Path to the input FITS file
        sep : str, optional
            Use a separator to join the chip ranges (e.g., ``0:3``, ``0-3``)
            instead of including all chips (e.g., ``0123``).

        Returns
        -------
        chips : str
            ``0123`` or ``0<sep>3`` if ACIS-I, ``7`` if ACIS-S;
            otherwise, ``ValueError`` raised.
        """
        acis_type = cls.get_type(filepath)
        if acis_type == "I":
            if sep is None:
                return "0123"
            else:
                return sep.join(["0", "3"])
        elif acis_type == "S":
            return "7"
        else:
            raise ValueError("unknown ACIS type: %s" % acis_type)
