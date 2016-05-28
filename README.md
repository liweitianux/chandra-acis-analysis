Chandra ACIS analysis tools and documents
=========================================

Weitian (Aaron) LI, Junhu GU, and Zhenghao ZHU


Install/Compile
---------------
Dependence:
+ ``libgsl-dev``

1. ``mass_profile``
```
$ cd mass_profile
$ make clean
$ heainit   # initilize heasoft, to link libpgplot.a and libcpgplot.a
$ ./init.sh
$ make
```

2. ``cosmo_calc``
Get from repository [atoolbox](https://github.com/liweitianux/atoolbox)
``astro/cosmo_calc``.


Settings
--------
Add the following settings to your shell's initialization file
(e.g., ``~/.bashrc`` or ``~/.zshrc``).
```
# environment variables:
export MASS_PROFILE_DIR="/path/to/mass_profile"
export CHANDRA_SCRIPT_DIR="/path/to/script"
# aliaes
# ciao scripts
alias chcld="${CIAO_SCRIPT_DIR}/chandra_collect_data_v3.sh"
alias chr500="${CIAO_SCRIPT_DIR}/ciao_r500avgt_v3.sh"
# mass_profile related
alias fitmass="${MASS_PROFILE_DIR}/fit_mass.sh"
alias fitnfw="${MASS_PROFILE_DIR}/fit_nfw_mass mass_int.dat"
alias fitsbp="${MASS_PROFILE_DIR}/fit_sbp.sh"
alias fitwang="${MASS_PROFILE_DIR}/fit_wang2012_model tcl_temp_profile.txt"
alias calclxfx="${MASS_PROFILE_DIR}/calc_lxfx_simple.sh"
alias getlxfx="${MASS_PROFILE_DIR}/get_lxfx_data.sh"
```


Usage
-----
See the doc ``HOWTO_chandra_acis_analysis.txt``


License
-------
The tools are distributed under the **MIT license** unless otherwise declared.
The documents are distributed under the ??? license (comming...).

