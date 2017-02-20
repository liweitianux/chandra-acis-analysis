Mass/Luminosity/Flux Calculation Tools
==============================

Junhua GU, Weitian LI, Zhenghao ZHU


Introduction
------------
This directory contains the tools/scripts used to fit the temperature
profile and surface brightness file, to calculate the gas density profile
and gravitational mass profile, to calculate luminosity and flux and
other related quantities.


NOTE
----
* Mass calculation references:
  + Walker et al. 2012, MNRAS, 422, 3503-3515,
    [ADS:2012MNRAS.422.3503W](http://adsabs.harvard.edu/abs/2012MNRAS.422.3503W)
  + Ettori et al. 2013, Space Science Reviews, 177, 119-154,
    [ADS:2013SSRv..177..119E](http://adsabs.harvard.edu/abs/2013SSRv..177..119E)
* Errors are calculated at 68% confident level.
* NFW profile is employed to extrapolate the mass profile.
* We use a self-proposed model (see ``wang2012_model.hpp``) to describe/fit
  the gas temperature profile.
* The single-beta and double-beta models (with a constant background) are used
  to describe the gas density profile.


TODO
----
* Merge the scripts/tools for single-beta and double-beta SBP models
  (to reduce code duplications)
* Uncertainties/errors calculation **maybe** inappropriate/problematic
  (e.g., ``analyze_mass_profile.py``);
  why not just use the quantile-based (e.g., Q84.15-Q15.85 ~= 68.3%)
  uncertainties or standard deviation???
