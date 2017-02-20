# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Cosmology calculator for Chandra ACIS.
"""

import math

from astropy.cosmology import FlatLambdaCDM
import astropy.units as au

from .acis import ACIS


class Calculator:
    """
    Calculate various quantities under a specific cosmology, as well
    as some values with respect to Chandra ACIS detector properties.
    """
    def __init__(self, H0=71.0, Om0=0.27, Ob0=0.046):
        self.H0 = H0  # [km/s/Mpc]
        self.Om0 = Om0
        self.Ode0 = 1.0 - Om0
        self.Ob0 = Ob0
        self._cosmo = FlatLambdaCDM(H0=H0, Om0=Om0, Ob0=Ob0)

    def luminosity_distance(self, z, unit="Mpc"):
        dist = self._cosmo.luminosity_distance(z)
        return dist.to(au.Unit(unit)).value

    def angular_diameter_distance(self, z, unit="Mpc"):
        dist = self._cosmo.angular_diameter_distance(z)
        return dist.to(au.Unit(unit)).value

    def kpc_per_arcsec(self, z):
        """
        Calculate the transversal length (unit: kpc) corresponding to
        1 arcsec at the *angular diameter distance* of z.
        """
        dist_kpc = self.angular_diameter_distance(z, unit="kpc")
        return dist_kpc * au.arcsec.to(au.rad)

    def kpc_per_pix(self, z):
        """
        Calculate the transversal length (unit: kpc) corresponding to
        1 ACIS pixel (i.e., 0.492 arcsec) at the *angular diameter distance*
        of z.
        """
        pix = ACIS.pixel2arcsec * au.arcsec
        dist_kpc = self.angular_diameter_distance(z, unit="kpc")
        return dist_kpc * pix.to(au.rad).value

    def cm_per_pix(self, z):
        """
        Calculate the transversal length (unit: cm) corresponding to
        1 ACIS pixel (i.e., 0.492 arcsec) at the *angular diameter distance*
        of z.
        """
        return self.kpc_per_pix(z) * au.kpc.to(au.cm)

    def norm_apec(self, z):
        """
        The normalization factor of the XSPEC APEC model assuming
        EM = 1 (i.e., n_e = n_H = 1 cm^-3, and V = 1 cm^3)

        norm = 1e-14 / (4*pi* (D_A * (1+z))^2) * int(n_e * n_H) dV
        unit: [cm^-5]

        This value will be used to calculate the cooling function values.

        References
        ----------
        * XSPEC: APEC model
          https://heasarc.gsfc.nasa.gov/docs/xanadu/xspec/manual/XSmodelApec.html
        """
        da = self.angular_diameter_distance(z, unit="cm")
        norm = 1e-14 / (4*math.pi * (da * (1+z))**2)
        return norm
