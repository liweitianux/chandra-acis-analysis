#!/bin/sh
##
## Calculate the 'cooling function' profile for each of the energy band
## specified in a bands file, with respect to the given 'temperature profile'
## and the average abundance, redshift, and column density nH, using the
## XSPEC model 'wabs*apec'.
##
## Weitian LI
## Updated: 2016-06-08
##

## cmdline arguments {{{
if [ $# -ne 6 ]; then
    printf "usage:\n"
    printf "    `basename $0` <tprofile> <avg_abund> <nH> <redshift> <coolfunc_prefix> <band_list>\n"
    exit 1
fi
TPROFILE=$1
ABUNDANCE=$2
N_H=$3
REDSHIFT=$4
COOLFUNC_PREFIX=$5
BLIST=$6
NORM=`cosmo_calc ${REDSHIFT} | grep 'norm.*cooling_function' | awk -F':' '{ print $2 }'`

if [ ! -r "${TPROFILE}" ]; then
    printf "ERROR: given tprofile '${TPROFILE}' NOT accessiable\n"
    exit 2
fi
## arguments }}}

## specify variable name outside while loop
## otherwise the inside vars invisible
XSPEC_CF_XCM="_coolfunc_calc.xcm"
[ -e "${XSPEC_CF_XCM}" ] && rm -f ${XSPEC_CF_XCM}

## generate xspec script {{{
cat >> ${XSPEC_CF_XCM} << _EOF_
## XSPEC Tcl script
## Calculate the cooling function profile w.r.t the temperature profile,
## for each specified energy band.
##
## Generated by: `basename $0`
## Date: `date`

set xs_return_results 1
set xs_echo_script 0
# set tcl_precision 12
## set basic data {{{
set nh ${N_H}
set redshift ${REDSHIFT}
set abundance ${ABUNDANCE}
set norm ${NORM}
## basic }}}

## xspec related {{{
# debug settings {{{
chatter 0
# debug }}}
query yes
abund grsa
dummyrsp 0.01 100.0 4096 linear
# load model 'wabs*apec' to calc cooling function
# (nh=0.0: do not consider aborption ???)
model wabs*apec & 0.0 & 1.0 & \${abundance} & \${redshift} & \${norm} &
## xspec }}}

## set input and output filename
set tpro_fn "${TPROFILE}"
set blist_fn "${BLIST}"
set cf_prefix "${COOLFUNC_PREFIX}"
set blist_fd [ open \${blist_fn} r ]

## loop over each energy band
while { [ gets \${blist_fd} blist_line ] != -1 } {
    if { "\${blist_line}" == "bolo" } {
        set e1 0.01
        set e2 100.0
        set name_suffix bolo
    } else {
        set e1 [ lindex \${blist_line} 0 ]
        set e2 [ lindex \${blist_line} 1 ]
        set name_suffix "\${e1}-\${e2}"
    }
    set cf_fn "\${cf_prefix}\${name_suffix}.dat"
    if { [ file exists \${cf_fn} ] } {
        exec rm -fv \${cf_fn}
    }
    set cf_fd [ open \${cf_fn} w ]
    set tpro_fd [ open \${tpro_fn} r ]

    ## read data from tprofile line by line
    while { [ gets \${tpro_fd} tpro_line ] != -1 } {
        scan \${tpro_line} "%f %f" radius temperature
        #puts "radius: \${radius}, temperature: \${temperature}"
        # set temperature value
        newpar 2 \${temperature}
        # calc flux & tclout
        flux \${e1} \${e2}
        tclout flux 1
        scan \${xspec_tclout} "%f" cf_erg
        #puts "cf: \${cf_erg}"
        puts \${cf_fd} "\${radius}    \${cf_erg}"
    }
    close \${tpro_fd}
    close \${cf_fd}
}

## exit
tclexit
_EOF_
## xcm generation }}}

## invoke xspec to calc
printf "invoking XSPEC to calculate cooling function profile ...\n"
xspec - ${XSPEC_CF_XCM} > /dev/null
