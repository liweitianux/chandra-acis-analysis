# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Chandra ACIS spectrum.
"""


from astropy.io import fits

from .acis import ACIS


class Spectrum:
    """
    Chandra ACIS spectrum
    """
    def __init__(self, filepath):
        self.filepath = filepath
        self.fitsobj = fits.open(filepath)
        ext_spec = self.fitsobj["SPECTRUM"]
        self.header = ext_spec.header
        # spectral data
        self.channel = ext_spec.data.columns["CHANNEL"].array
        self.counts = ext_spec.data.columns["COUNTS"].array
        # spectral keywords
        self.EXPOSURE = self.header.get("EXPOSURE")
        self.BACKSCAL = self.header.get("BACKSCAL")

    def calc_flux(self, elow, ehigh):
        """
        Calculate the flux:
            flux = counts / exposure / area

        Parameters
        ----------
        elow, ehigh : float, optional
            Lower and upper energy limit to calculate the flux.
        """
        chlow = ACIS.energy2channel(elow)
        chhigh = ACIS.energy2channel(ehigh)
        counts = self.counts[(chlow-1):chhigh].sum()
        flux = counts / self.EXPOSURE / self.BACKSCAL
        return flux

    def calc_pb_flux(self, elow=9500, ehigh=12000):
        """
        Calculate the particle background (default: 9.5-12 keV) flux.
        """
        return self.calc_flux(elow=elow, ehigh=ehigh)
