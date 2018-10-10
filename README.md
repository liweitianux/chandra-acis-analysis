Chandra ACIS Data Analysis Tools
================================

Weitian LI, Junhu GU, and Zhenghao ZHU


Introduction
------------
This repository currently contains the following tools:
+ Chandra ACIS data reduction
+ Point source and flares removal
+ Blanksky reprojection
+ Background spectrum correction
+ Source spectra extraction and deprojection analysis (temperature profile)
+ Surface brightness profile extraction
+ Gravitational mass profile calculation (NFW profile extrapolation)
+ Luminosity and flux calculation

These tools are developed to help and automate our batch analysis of the
big galaxy groups and clusters sample observed by Chandra ACIS.
Therefore, there are many assumptions and hacks in these tools, and many
cleanups are needed.
In addition, documents are badly needed!


TODO
----
+ Rewrite more shell scripts in Python, use YAML configuration files, and
  store results into `results.yaml` (get rid of `INFO.json`).  e.g.,
  - `bin/fit_mass.sh`
  - `bin/fit_sbp.sh`
  - `bin/calc_lxfx.sh`
  - `bin/calc_lxfx_wrapper.sh`
  - `bin/get_lxfx_data.sh`
  - `bin/fg_2500_500.py`
  - `scripts/chandra_genspcreg.sh`
  - `scripts/ciao_bkg_spectra.sh`
  - `scripts/ciao_deproj_spectra.sh`
  - `scripts/ciao_r500avgt.sh`
  - more scripts in the `scripts` directory (also cleanups)
+ Some Python programs need rewrite, e.g.,
  - `bin/analyze_lxfx.py`
  - `bin/analyze_mass_profile.py`
+ Update the current docs and write more!


Requirements
------------
+ Python (>=3.5)
+ CIAO (tested with v4.6, v4.9)
+ HEASoft (tested with v6.16, v6.19)


Installation
------------
1. Clone this repository with ``opt_utilities``:

   ```sh
   $ git clone --recursive https://github.com/liweitianux/chandra-acis-analysis.git
   ```

   or in this way:

   ```sh
   $ git clone https://github.com/liweitianux/chandra-acis-analysis.git
   $ cd chandra-acis-analysis
   $ git submodule update --init --recursive
   ```

2. Install the following Python packages:

   ```sh
   $ sudo apt install python3-numpy python3-scipy python3-astropy python3-ruamel.yaml
   ```

   or

   ```sh
   $ pip3 install --user -r requirements.txt
   ```

3. Build tools in ``src`` directory:

   ```sh
   $ cd src
   $ make clean
   $ make [OPENMP=yes]
   $ make install
   ```


Settings
--------
Add the following settings to your shell's initialization file
(e.g., ``~/.bashrc`` or ``~/.zshrc``).

```sh
# Environment variables:
export CHANDRA_ACIS_BIN="<path>/chandra-acis-analysis/bin"

# Handy aliases:
alias fitmass="${CHANDRA_ACIS_BIN}/fit_mass.sh"
alias fitnfw="${CHANDRA_ACIS_BIN}/fit_nfw_mass mass_int.dat"
alias fitsbp="${CHANDRA_ACIS_BIN}/fit_sbp.sh"
alias fittp="${CHANDRA_ACIS_BIN}/fit_wang2012_model"
alias calclxfx="${CHANDRA_ACIS_BIN}/calc_lxfx_wrapper.sh"
alias getlxfx="${CHANDRA_ACIS_BIN}/get_lxfx_data.sh"
```

HEASoft Setup
-------------
To avoid the conflicts between HEASoft and system libraries,
a [wrapper script](scripts/heasoft.sh) is provided.

```sh
$ mkdir ~/.heasoft
$ cp scripts/heasoft.sh ~/.heasoft

# Assume that your HEASoft is installed at '~/local/heasoft/heasoft-x.xx/'
$ cd ~/local/heasoft
$ ln -s heasoft-x.xx default
$ cd default
$ ln -s x86_64-unknown-linux-gnu-libc* PORTAL
```

Then add the following `heainit()` shell function:
```sh
heainit() {
    local ld_lib_bak i tool
    local wrapper="${HOME}/.heasoft/heasoft.sh"
    local wrapper_dir=$(dirname ${wrapper})
    local wrapper_name=$(basename ${wrapper})
    if [ -z "${HEADAS}" ]; then
        ld_lib_bak=${LD_LIBRARY_PATH}
        export HEADAS="${HOME}/local/heasoft/default/PORTAL"
        source ${HEADAS}/headas-init.sh
        export LD_LIBRARY_PATH=${ld_lib_bak}
        export PATH="${wrapper_dir}:${PATH}"

        if [ ! -f "${wrapper}" ]; then
            echo "ERROR: wrapper '${wrapper}' not found!"
            return
        fi
        chmod u=rwx ${wrapper}

        echo "Initializing HEASoft from ${HEADAS} ..."
        for i in ${HEADAS}/bin/*; do
            tool=$(basename $i)
            ln -sf ${wrapper_name} ${wrapper_dir}/${tool}
        done

        echo "HEASoft initialized."
    else
        echo "HEASoft already initialized from: ${HEADAS}"
    fi
}
```


Usage
-----
See the documentations located in the ``doc`` directory,
especially the [``HOWTO_chandra_acis_analysis.txt``](doc/HOWTO_chandra_acis_analysis.txt)

NOTE: complete and detailed documentations are badly needed!


Useful Links
------------
* [CIAO](http://cxc.cfa.harvard.edu/ciao/)
* [Chandra CALDB](http://cxc.cfa.harvard.edu/ciao/download/caldb.html)
* [Chandra Data Archive](http://cda.harvard.edu/chaser/)
* [NED search by name](http://ned.ipac.caltech.edu/forms/byname.html)
* [NED search near position](https://ned.ipac.caltech.edu/forms/nearposn.html)
* [SIMBAD](http://simbad.u-strasbg.fr/simbad/)
* [HEASoft](https://heasarc.gsfc.nasa.gov/lheasoft/)
* [XSPEC](https://heasarc.gsfc.nasa.gov/lheasoft/xanadu/xspec/index.html)
* [QDP/PLT User's Guide](https://heasarc.gsfc.nasa.gov/ftools/others/qdp/qdp.html)
* [FTOOLS](https://heasarc.gsfc.nasa.gov/ftools/)
* [HEASARC nH tool](https://heasarc.gsfc.nasa.gov/cgi-bin/Tools/w3nh/w3nh.pl)


License
-------
Unless otherwise declared:

* Codes developed by us are distributed under the
  [MIT License](https://opensource.org/licenses/MIT);
* Documentations and products generated by us are distributed under the
  [Creative Commons Attribution 3.0 License](https://creativecommons.org/licenses/by/3.0/us/deed.en_US).
