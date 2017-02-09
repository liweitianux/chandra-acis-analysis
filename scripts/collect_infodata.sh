#!/bin/sh
##
## Collect the calculated mass data and update them to the INFO json file.
##
## JSON parser: http://json.parser.online.fr/
##
## Weitian LI <liweitianux@gmail.com>
## August 31, 2012
##
## Change logs:
## 2017-02-09, Weitian LI
##   * Update to use the new style config files
##   * Some cleanups
## v3.4, 2015/06/03, Weitian LI
##   * Copy needed pfiles to current working directory, and
##     set environment variable $PFILES to use these first.
##   * Replaced 'grep' with '\grep', 'ls' with '\ls'
## v3.3, 2013/10/14, Weitian LI
##   add key `Unified Name'
## v3.2, 2013/05/29, Weitian LI
##   add key `XCNTRD_RA, XCNTRD_DEC'
## v3.1, 2013/05/18, Weitian LI
##   add key `Feature'
## v3.0, 2013/02/09, Weitian LI
##   modified for `new sample info format'
## v2.2, 2012/12/18, Weitian LI
##   add `beta' and `cooling time' parameters
## v2.1, 2012/11/07, Weitian LI
##   account for `fitting_dbeta'
## v2.0, 2012/10/14, Weitian LI
##   add parameters
## v1.1, 2012/09/05, Weitian LI
##   add `T_avg(0.2-0.5 R500)' and `T_err'
##

## error code {{{
ERR_USG=1
ERR_DIR=11
ERR_CFG=12
ERR_RES=13
ERR_COSC=14
ERR_BETA=101
ERR_BETA2=102
ERR_JSON=201
ERR_MLOG=202
ERR_BLOG=203
ERR_CLOG=204
## error code }}}

## usage, help {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` json=<info_json> cfg=<main_cfg> res=<final_result> basedir=<repro_dir> massdir=<mass_dir>\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
# default basedir
DFT_BASEDIR=".."
# default mass dir
DFT_MASSDIR="mass"
# default pattern for json info file
DFT_JSON_PAT="*_INFO.json"
# main config file
DFT_CFG_PAT="mass.conf"
# default result file
DFT_RES_FINAL_PAT="final_result.txt"
# default sbprofile region file
DFT_SBPROFILE_REG="sbprofile.reg"
# default radial spectra region file
DFT_RSPEC_REG="rspec.reg"
## default parameters }}}

## functions {{{
# process commandline arguments
# cmdline arg format: `KEY=VALUE'
getopt_keyval() {
    until [ -z "$1" ]
    do
        key=${1%%=*}                    # extract key
        val=${1#*=}                     # extract value
        keyval="${key}=\"${val}\""
        echo "## getopt: eval '${keyval}'"
        eval ${keyval}
        shift                           # shift, process next one
    done
}
## functions }}}

## parameters {{{
# process cmdline args using `getopt_keyval'
getopt_keyval "$@"

# init directory
INIT_DIR=`pwd -P`

# check given parameters
# check given dir
if [ -d "${basedir}" ] && \ls ${basedir}/*repro_evt2.fits > /dev/null 2>&1; then
    BASEDIR=${basedir}
elif [ -d "${DFT_BASEDIR}" ] && \ls ${DFT_BASEDIR}/*repro_evt2.fits > /dev/null 2>&1; then
    BASEDIR=${DFT_BASEDIR}
else
    read -p "> basedir (contains info json): " BASEDIR
    if [ ! -d "${BASEDIR}" ]; then
        printf "ERROR: given \`${BASEDIR}' NOT a directory\n"
        exit ${ERR_DIR}
    elif ! \ls ${BASEDIR}/*repro_evt2.fits > /dev/null 2>&1; then
        printf "ERROR: given \`${BASEDIR}' NOT contains needed evt files\n"
        exit ${ERR_DIR}
    fi
fi
# remove the trailing '/'
BASEDIR=`( cd ${INIT_DIR}/${BASEDIR} && pwd -P )`
printf "## use basedir: \`${BASEDIR}'\n"
# mass dir
if [ ! -z "${massdir}" ] && [ -d "${BASEDIR}/${massdir}" ]; then
    MASS_DIR=`( cd ${BASEDIR}/${massdir} && pwd -P )`
elif [ -d "${BASEDIR}/${DFT_MASSDIR}" ]; then
    MASS_DIR=`( cd ${BASEDIR}/${DFT_MASSDIR} && pwd -P )`
else
    read -p "> mass dir (relative to basedir): " MASS_DIR
    if [ ! -d "${BASEDIR}/${MASS_DIR}" ]; then
        printf "ERROR: given \`${BASEDIR}/${MASS_DIR}' NOT a directory\n"
        exit ${ERR_DIR}
    fi
fi
# remove the trailing '/'
MASS_DIR=`echo ${MASS_DIR} | sed 's/\/*$//'`
printf "## use massdir: \`${MASS_DIR}'\n"
# check json file
if [ ! -z "${json}" ] && [ -r "${BASEDIR}/${json}" ]; then
    JSON_FILE="${json}"
elif [ "`\ls ${BASEDIR}/${DFT_JSON_PAT} | wc -l`" -eq 1 ]; then
    JSON_FILE=`( cd ${BASEDIR} && \ls ${DFT_JSON_PAT} )`
else
    read -p "> info json file: " JSON_FILE
    if ! [ -r "${BASEDIR}/${JSON_FILE}" ]; then
        printf "ERROR: cannot access given \`${BASEDIR}/${INFO_JSON}' file\n"
        exit ${ERR_JSON}
    fi
fi
printf "## use info json file: \`${JSON_FILE}'\n"
# check main config file
if [ ! -z "${cfg}" ] && [ -r "${cfg}" ]; then
    CFG_FILE="${cfg}"
elif [ -r "${DFT_CFG_PAT}" ]; then
    CFG_FILE="${DFT_CFG_PAT}"
else
    read -p "> main config file: " CFG_FILE
    if [ ! -r "${CFG_FILE}" ]; then
        printf "ERROR: cannot access given \`${CFG_JSON}' file\n"
        exit ${ERR_CFG}
    fi
fi
printf "## use main config file: \`${CFG_FILE}'\n"
SBP_CFG=`\grep '^sbp_cfg' ${CFG_FILE} | awk '{ print $2 }'`
printf "## sbp config file: \`${SBP_CFG}'\n"
# check final result file
if [ ! -z "${res}" ] && [ -r "${res}" ]; then
    RES_FINAL="${res}"
elif [ -r "${DFT_RES_FINAL_PAT}" ]; then
    RES_FINAL="${DFT_RES_FINAL_PAT}"
else
    read -p "> final result file: " RES_FINAL
    if [ ! -r "${RES_FINAL}" ]; then
        printf "ERROR: cannot access given \`${RES_FINAL}' file\n"
        exit ${ERR_RES}
    fi
fi
printf "## use final result file: \`${RES_FINAL}'\n"
## parameters }}}

## directory & file {{{
BASE_PATH=`dirname $0`
printf "## BASE_PATH: ${BASE_PATH}\n"
EVT_DIR="${BASEDIR}/evt"
SPEC_DIR="${BASEDIR}/spc/profile"
## dir & file }}}

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="dmkeypar"

# Copy necessary pfiles for localized usage
for tool in ${CIAO_TOOLS}; do
    pfile=`paccess ${tool}`
    [ -n "${pfile}" ] && punlearn ${tool} && cp -Lvf ${pfile} .
done

# Modify environment variable 'PFILES' to use local pfiles first
export PFILES="./:${PFILES}"
## pfiles }}}

cd ${BASEDIR}
printf "## enter directory: `pwd -P`\n"

## in dir `repro' {{{
punlearn dmkeypar
EVT_RAW=`\ls *repro_evt2.fits`
OBS_ID=`dmkeypar ${EVT_RAW} OBS_ID echo=yes`
DATE_OBS=`dmkeypar ${EVT_RAW} DATE-OBS echo=yes`
EXPOSURE_RAW=`dmkeypar ${EVT_RAW} EXPOSURE echo=yes | awk '{ print $1/1000 }'`
## ACIS_TYPE
DETNAM=`dmkeypar ${EVT_RAW} DETNAM echo=yes`
if echo ${DETNAM} | \grep -q 'ACIS-0123'; then
    ACIS_TYPE="ACIS-I"
elif echo ${DETNAM} | \grep -q 'ACIS-[0-6]*7'; then
    ACIS_TYPE="ACIS-S"
else
    printf "*** ERROR: unknown detector type: ${DETNAM}\n"
    ACIS_TYPE="UNKNOWN"
    exit 1
fi
## dir `repro' }}}

## in dir `repro/evt' {{{
cd ${EVT_DIR}
EVT_CLEAN=`\ls evt2_c*_clean.fits`
EXPOSURE_CLEAN=`dmkeypar ${EVT_CLEAN} EXPOSURE echo=yes | awk '{ print $1/1000 }'`
## dir `repro/evt' }}}

## in dir `repro/mass' {{{
cd ${MASS_DIR}

# misc {{{
N_H=`\grep '^nh' ${CFG_FILE} | awk '{ print $2 }'`
ABUND=`\grep '^abund' ${CFG_FILE} | awk '{ print $2 }'`
TPROFILE_DATA=`\grep '^tprofile_data' ${CFG_FILE} | awk '{ print $2 }'`
NFW_RMIN_KPC=`\grep '^nfw_rmin_kpc' ${CFG_FILE} | awk '{ print $2 }'`
Z=`\grep '^z' ${SBP_CFG} | awk '{ print $2 }'`
E_Z=`cosmo_calc ${Z} | \grep -i 'Hubble_parameter' | awk '{ print $3 }'`
KPC_PER_PIXEL=`cosmo_calc ${Z} | \grep 'kpc/pixel' | awk '{ print $3 }'`
SBP_DATA=`\grep '^sbp_data' ${SBP_CFG} | awk '{ print $2 }'`
RMAX_SBP_PIX=`tail -n 1 ${SBP_DATA} | awk '{ print $1+$2 }'`
RMAX_SBP_KPC=`echo "${RMAX_SBP_PIX} ${KPC_PER_PIXEL}" | awk '{ printf("%.2f", $1*$2) }'`
SPC_DIR="$(dirname $(readlink ${TPROFILE_DATA}))"
if [ -f "${SPC_DIR}/${DFT_RSPEC_REG}" ]; then
    RMAX_TPRO_PIX=`\grep -iE '(pie|annulus)' ${SPC_DIR}/${DFT_RSPEC_REG} | tail -n 1 | awk -F',' '{ print $4 }'`
    RMAX_TPRO_KPC=`echo "${RMAX_TPRO_PIX} ${KPC_PER_PIXEL}" | awk '{ printf("%.2f", $1*$2) }'`
fi
[ -z "${NFW_RMIN_KPC}" ] && NFW_RMIN_KPC="null"
[ -z "${RMAX_SBP_PIX}" ] && RMAX_SBP_PIX="null"
[ -z "${RMAX_SBP_KPC}" ] && RMAX_SBP_KPC="null"
# misc }}}

## determine single/double beta {{{
if \grep -q '^beta2' ${SBP_CFG}; then
    MODEL_SBP="double-beta"
    n01=`\grep '^n01' ${RES_FINAL} | awk '{ print $2 }'`
    beta1=`\grep '^beta1' ${RES_FINAL} | awk '{ print $2 }'`
    rc1=`\grep -E '^rc1\s' ${RES_FINAL} | awk '{ print $2 }'`
    rc1_kpc=`\grep '^rc1_kpc' ${RES_FINAL} | awk '{ print $2 }'`
    n02=`\grep '^n02' ${RES_FINAL} | awk '{ print $2 }'`
    beta2=`\grep '^beta2' ${RES_FINAL} | awk '{ print $2 }'`
    rc2=`\grep -E '^rc2\s' ${RES_FINAL} | awk '{ print $2 }'`
    rc2_kpc=`\grep '^rc2_kpc' ${RES_FINAL} | awk '{ print $2 }'`
    BKG=`\grep '^bkg' ${RES_FINAL} | awk '{ print $2 }'`
    # beta1 -> smaller rc; beta2 -> bigger rc
    if [ `echo "${rc1} < ${rc2}" | bc -l` -eq 1 ]; then
        N01=${n01}
        BETA1=${beta1}
        RC1=${rc1}
        RC1_KPC=${rc1_kpc}
        N02=${n02}
        BETA2=${beta2}
        RC2=${rc2}
        RC2_KPC=${rc2_kpc}
    else
        # beta1 <-> beta2 (swap)
        N01=${n02}
        BETA1=${beta2}
        RC1=${rc2}
        RC1_KPC=${rc2_kpc}
        N02=${n01}
        BETA2=${beta1}
        RC2=${rc1}
        RC2_KPC=${rc1_kpc}
    fi
else
    MODEL_SBP="single-beta"
    N01="null"
    BETA1="null"
    RC1="null"
    RC1_KPC="null"
    N02=`\grep '^n0' ${RES_FINAL} | awk '{ print $2 }'`
    BETA2=`\grep '^beta' ${RES_FINAL} | awk '{ print $2 }'`
    RC2=`\grep -E '^rc\s' ${RES_FINAL} | awk '{ print $2 }'`
    RC2_KPC=`\grep '^rc_kpc' ${RES_FINAL} | awk '{ print $2 }'`
    BKG=`\grep '^bkg' ${RES_FINAL} | awk '{ print $2 }'`
fi
## single/double beta }}}

## get `mass/virial_radius/luminosity' {{{
# 200 data {{{
R200_VAL=`\grep '^r200' ${RES_FINAL} | awk '{ print $2 }'`
R200_ERR_L=`\grep '^r200' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
R200_ERR_U=`\grep '^r200' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
M200_VAL=`\grep '^m200' ${RES_FINAL} | awk '{ print $2 }'`
M200_ERR_L=`\grep '^m200' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
M200_ERR_U=`\grep '^m200' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
L200_VAL=`\grep '^L200' ${RES_FINAL} | awk '{ print $2 }'`
L200_ERR=`\grep '^L200' ${RES_FINAL} | awk '{ print $4 }'`
MGAS200_VAL=`\grep '^gas_m200' ${RES_FINAL} | awk '{ print $2 }'`
MGAS200_ERR_L=`\grep '^gas_m200' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
MGAS200_ERR_U=`\grep '^gas_m200' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
FGAS200_VAL=`\grep '^gas_fraction200' ${RES_FINAL} | awk '{ print $2 }'`
FGAS200_ERR_L=`\grep '^gas_fraction200' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
FGAS200_ERR_U=`\grep '^gas_fraction200' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
[ -z "${R200_VAL}" ]       && R200_VAL="null"
[ -z "${R200_ERR_L}" ]     && R200_ERR_L="null"
[ -z "${R200_ERR_U}" ]     && R200_ERR_U="null"
[ -z "${M200_VAL}" ]       && M200_VAL="null"
[ -z "${M200_ERR_L}" ]     && M200_ERR_L="null"
[ -z "${M200_ERR_U}" ]     && M200_ERR_U="null"
[ -z "${L200_VAL}" ]       && L200_VAL="null"
[ -z "${L200_ERR}" ]       && L200_ERR="null"
[ -z "${MGAS200_VAL}" ]    && MGAS200_VAL="null"
[ -z "${MGAS200_ERR_L}" ]  && MGAS200_ERR_L="null"
[ -z "${MGAS200_ERR_U}" ]  && MGAS200_ERR_U="null"
[ -z "${FGAS200_VAL}" ]    && FGAS200_VAL="null"
[ -z "${FGAS200_ERR_L}" ]  && FGAS200_ERR_L="null"
[ -z "${FGAS200_ERR_U}" ]  && FGAS200_ERR_U="null"
# 200 }}}
# 500 data {{{
R500_VAL=`\grep '^r500' ${RES_FINAL} | awk '{ print $2 }'`
R500_ERR_L=`\grep '^r500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
R500_ERR_U=`\grep '^r500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
M500_VAL=`\grep '^m500' ${RES_FINAL} | awk '{ print $2 }'`
M500_ERR_L=`\grep '^m500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
M500_ERR_U=`\grep '^m500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
L500_VAL=`\grep '^L500' ${RES_FINAL} | awk '{ print $2 }'`
L500_ERR=`\grep '^L500' ${RES_FINAL} | awk '{ print $4 }'`
MGAS500_VAL=`\grep '^gas_m500' ${RES_FINAL} | awk '{ print $2 }'`
MGAS500_ERR_L=`\grep '^gas_m500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
MGAS500_ERR_U=`\grep '^gas_m500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
FGAS500_VAL=`\grep '^gas_fraction500' ${RES_FINAL} | awk '{ print $2 }'`
FGAS500_ERR_L=`\grep '^gas_fraction500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
FGAS500_ERR_U=`\grep '^gas_fraction500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
[ -z "${R500_VAL}" ]       && R500_VAL="null"
[ -z "${R500_ERR_L}" ]     && R500_ERR_L="null"
[ -z "${R500_ERR_U}" ]     && R500_ERR_U="null"
[ -z "${M500_VAL}" ]       && M500_VAL="null"
[ -z "${M500_ERR_L}" ]     && M500_ERR_L="null"
[ -z "${M500_ERR_U}" ]     && M500_ERR_U="null"
[ -z "${L500_VAL}" ]       && L500_VAL="null"
[ -z "${L500_ERR}" ]       && L500_ERR="null"
[ -z "${MGAS500_VAL}" ]    && MGAS500_VAL="null"
[ -z "${MGAS500_ERR_L}" ]  && MGAS500_ERR_L="null"
[ -z "${MGAS500_ERR_U}" ]  && MGAS500_ERR_U="null"
[ -z "${FGAS500_VAL}" ]    && FGAS500_VAL="null"
[ -z "${FGAS500_ERR_L}" ]  && FGAS500_ERR_L="null"
[ -z "${FGAS500_ERR_U}" ]  && FGAS500_ERR_U="null"
# 500 }}}
# 1500 data {{{
R1500_VAL=`\grep '^r1500' ${RES_FINAL} | awk '{ print $2 }'`
R1500_ERR_L=`\grep '^r1500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
R1500_ERR_U=`\grep '^r1500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
M1500_VAL=`\grep '^m1500' ${RES_FINAL} | awk '{ print $2 }'`
M1500_ERR_L=`\grep '^m1500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
M1500_ERR_U=`\grep '^m1500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
L1500_VAL=`\grep '^L1500' ${RES_FINAL} | awk '{ print $2 }'`
L1500_ERR=`\grep '^L1500' ${RES_FINAL} | awk '{ print $4 }'`
MGAS1500_VAL=`\grep '^gas_m1500' ${RES_FINAL} | awk '{ print $2 }'`
MGAS1500_ERR_L=`\grep '^gas_m1500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
MGAS1500_ERR_U=`\grep '^gas_m1500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
FGAS1500_VAL=`\grep '^gas_fraction1500' ${RES_FINAL} | awk '{ print $2 }'`
FGAS1500_ERR_L=`\grep '^gas_fraction1500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
FGAS1500_ERR_U=`\grep '^gas_fraction1500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
[ -z "${R1500_VAL}" ]      && R1500_VAL="null"
[ -z "${R1500_ERR_L}" ]    && R1500_ERR_L="null"
[ -z "${R1500_ERR_U}" ]    && R1500_ERR_U="null"
[ -z "${M1500_VAL}" ]      && M1500_VAL="null"
[ -z "${M1500_ERR_L}" ]    && M1500_ERR_L="null"
[ -z "${M1500_ERR_U}" ]    && M1500_ERR_U="null"
[ -z "${L1500_VAL}" ]      && L1500_VAL="null"
[ -z "${L1500_ERR}" ]      && L1500_ERR="null"
[ -z "${MGAS1500_VAL}" ]   && MGAS1500_VAL="null"
[ -z "${MGAS1500_ERR_L}" ] && MGAS1500_ERR_L="null"
[ -z "${MGAS1500_ERR_U}" ] && MGAS1500_ERR_U="null"
[ -z "${FGAS1500_VAL}" ]   && FGAS1500_VAL="null"
[ -z "${FGAS1500_ERR_L}" ] && FGAS1500_ERR_L="null"
[ -z "${FGAS1500_ERR_U}" ] && FGAS1500_ERR_U="null"
# 1500 }}}
# 2500 data {{{
R2500_VAL=`\grep '^r2500' ${RES_FINAL} | awk '{ print $2 }'`
R2500_ERR_L=`\grep '^r2500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
R2500_ERR_U=`\grep '^r2500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
M2500_VAL=`\grep '^m2500' ${RES_FINAL} | awk '{ print $2 }'`
M2500_ERR_L=`\grep '^m2500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
M2500_ERR_U=`\grep '^m2500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
L2500_VAL=`\grep '^L2500' ${RES_FINAL} | awk '{ print $2 }'`
L2500_ERR=`\grep '^L2500' ${RES_FINAL} | awk '{ print $4 }'`
MGAS2500_VAL=`\grep '^gas_m2500' ${RES_FINAL} | awk '{ print $2 }'`
MGAS2500_ERR_L=`\grep '^gas_m2500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
MGAS2500_ERR_U=`\grep '^gas_m2500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
FGAS2500_VAL=`\grep '^gas_fraction2500' ${RES_FINAL} | awk '{ print $2 }'`
FGAS2500_ERR_L=`\grep '^gas_fraction2500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $1 }'`
FGAS2500_ERR_U=`\grep '^gas_fraction2500' ${RES_FINAL} | awk '{ print $3 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
[ -z "${R2500_VAL}" ]      && R2500_VAL="null"
[ -z "${R2500_ERR_L}" ]    && R2500_ERR_L="null"
[ -z "${R2500_ERR_U}" ]    && R2500_ERR_U="null"
[ -z "${M2500_VAL}" ]      && M2500_VAL="null"
[ -z "${M2500_ERR_L}" ]    && M2500_ERR_L="null"
[ -z "${M2500_ERR_U}" ]    && M2500_ERR_U="null"
[ -z "${L2500_VAL}" ]      && L2500_VAL="null"
[ -z "${L2500_ERR}" ]      && L2500_ERR="null"
[ -z "${MGAS2500_VAL}" ]   && MGAS2500_VAL="null"
[ -z "${MGAS2500_ERR_L}" ] && MGAS2500_ERR_L="null"
[ -z "${MGAS2500_ERR_U}" ] && MGAS2500_ERR_U="null"
[ -z "${FGAS2500_VAL}" ]   && FGAS2500_VAL="null"
[ -z "${FGAS2500_ERR_L}" ] && FGAS2500_ERR_L="null"
[ -z "${FGAS2500_ERR_U}" ] && FGAS2500_ERR_U="null"
# 2500 }}}
FGRR=`\grep '^gas_fraction.*r2500.*r500=' ${RES_FINAL} | sed 's/^.*r500=//' | awk '{ print $1 }'`
FGRR_ERR_L=`\grep '^gas_fraction.*r2500.*r500=' ${RES_FINAL} | sed 's/^.*r500=//' | awk '{ print $2 }' | awk -F'/' '{ print $1 }'`
FGRR_ERR_U=`\grep '^gas_fraction.*r2500.*r500=' ${RES_FINAL} | sed 's/^.*r500=//' | awk '{ print $2 }' | awk -F'/' '{ print $2 }' | tr -d '+'`
[ -z "${FGRR}" ]       && FGRR="null"
[ -z "${FGRR_ERR_L}" ] && FGRR_ERR_L="null"
[ -z "${FGRR_ERR_U}" ] && FGRR_ERR_U="null"
## mrl }}}

## rcool & cooling time {{{
RCOOL=`\grep '^cooling_radius=' ${RES_FINAL} | awk '{ print $2 }'`
COOLING_TIME=`\grep '^cooling_time=' ${RES_FINAL} | awk -F'=' '{ print $2 }' | tr -d ' Gyr'`
[ -z "${RCOOL}" ] && RCOOL="null"
[ -z "${COOLING_TIME}" ] && COOLING_TIME="null"
## cooling time }}}
## repro/mass }}}

cd ${BASEDIR}
## orig json file {{{
printf "## collect data from original info file ...\n"
OBJ_NAME=`\grep '"Source\ Name' ${JSON_FILE} | sed 's/.*"Source.*":\ //' | sed 's/^"//' | sed 's/"\ *,$//'`
OBJ_UNAME=`\grep '"Unified\ Name' ${JSON_FILE} | sed 's/.*"Unified.*":\ //' | sed 's/^"//' | sed 's/"\ *,$//'`
OBJ_RA=`\grep '"R\.\ A\.' ${JSON_FILE} | sed 's/.*"R\.\ A\.":\ //' | sed 's/^"//' | sed 's/"\ *,$//'`
OBJ_DEC=`\grep '"Dec\.' ${JSON_FILE} | sed 's/.*"Dec\.":\ //' | sed 's/^"//' | sed 's/"\ *,$//'`
OBJ_XCRA=`\grep '"XCNTRD_RA' ${JSON_FILE} | sed 's/.*"XCNTRD_RA":\ //' | sed 's/^"//' | sed 's/"\ *,$//'`
OBJ_XCDEC=`\grep '"XCNTRD_DEC' ${JSON_FILE} | sed 's/.*"XCNTRD_DEC":\ //' | sed 's/^"//' | sed 's/"\ *,$//'`
REDSHIFT=`\grep '"redshift' ${JSON_FILE} | sed 's/.*"redshift.*":\ //' | sed 's/\ *,$//'`
COOLCORE=`\grep -i '"cool.*core' ${JSON_FILE} | sed 's/.*"[cC]ool.*":\ //' | sed 's/\ *,$//'`
[ -z "${COOLCORE}" ] && COOLCORE="null"
OBJ_FEATURE=`\grep '"Feature' ${JSON_FILE} | sed 's/.*"Feature":\ //' | sed 's/^"//' | sed 's/"\ *,*$//'`
OBJ_NOTE=`\grep '"NOTE' ${JSON_FILE} | sed 's/.*"NOTE":\ //' | sed 's/^"//' | sed 's/"\ *,*$//'`

# T & Z {{{
T_1R500=`\grep '"T(0\.1.*R500' ${JSON_FILE} | sed 's/.*"T.*":\ //' | sed 's/\ *,$//'`
T_1ERR=`\grep '"T_err(.*0\.1.*R500' ${JSON_FILE} | sed 's/.*"T.*":\ //' | sed 's/\ *,$//'`
T_1ERR_L=`\grep '"T_err_l.*0\.1.*R500' ${JSON_FILE} | sed 's/.*"T.*":\ //' | sed 's/\ *,$//'`
T_1ERR_U=`\grep '"T_err_u.*0\.1.*R500' ${JSON_FILE} | sed 's/.*"T.*":\ //' | sed 's/\ *,$//'`
Z_1R500=`\grep '"Z(0\.1.*R500' ${JSON_FILE} | sed 's/.*"Z.*":\ //' | sed 's/\ *,$//'`
Z_1ERR=`\grep '"Z_err(.*0\.1.*R500' ${JSON_FILE} | sed 's/.*"Z.*":\ //' | sed 's/\ *,$//'`
Z_1ERR_L=`\grep '"Z_err_l.*0\.1.*R500' ${JSON_FILE} | sed 's/.*"Z.*":\ //' | sed 's/\ *,$//'`
Z_1ERR_U=`\grep '"Z_err_u.*0\.1.*R500' ${JSON_FILE} | sed 's/.*"Z.*":\ //' | sed 's/\ *,$//'`
T_2R500=`\grep '"T(0\.2.*R500' ${JSON_FILE} | sed 's/.*"T.*":\ //' | sed 's/\ *,$//'`
T_2ERR=`\grep '"T_err(.*0\.2.*R500' ${JSON_FILE} | sed 's/.*"T.*":\ //' | sed 's/\ *,$//'`
T_2ERR_L=`\grep '"T_err_l.*0\.2.*R500' ${JSON_FILE} | sed 's/.*"T.*":\ //' | sed 's/\ *,$//'`
T_2ERR_U=`\grep '"T_err_u.*0\.2.*R500' ${JSON_FILE} | sed 's/.*"T.*":\ //' | sed 's/\ *,$//'`
Z_2R500=`\grep '"Z(0\.2.*R500' ${JSON_FILE} | sed 's/.*"Z.*":\ //' | sed 's/\ *,$//'`
Z_2ERR=`\grep '"Z_err(.*0\.2.*R500' ${JSON_FILE} | sed 's/.*"Z.*":\ //' | sed 's/\ *,$//'`
Z_2ERR_L=`\grep '"Z_err_l.*0\.2.*R500' ${JSON_FILE} | sed 's/.*"Z.*":\ //' | sed 's/\ *,$//'`
Z_2ERR_U=`\grep '"Z_err_u.*0\.2.*R500' ${JSON_FILE} | sed 's/.*"Z.*":\ //' | sed 's/\ *,$//'`
[ -z "${T_1R500}" ]  && T_1R500="null"
[ -z "${T_1ERR}" ]   && T_1ERR="null"
[ -z "${T_1ERR_L}" ] && T_1ERR_L="null"
[ -z "${T_1ERR_U}" ] && T_1ERR_U="null"
[ -z "${Z_1R500}" ]  && Z_1R500="null"
[ -z "${Z_1ERR}" ]   && Z_1ERR="null"
[ -z "${Z_1ERR_L}" ] && Z_1ERR_L="null"
[ -z "${Z_1ERR_U}" ] && Z_1ERR_U="null"
[ -z "${T_2R500}" ]  && T_2R500="null"
[ -z "${T_2ERR}" ]   && T_2ERR="null"
[ -z "${T_2ERR_L}" ] && T_2ERR_L="null"
[ -z "${T_2ERR_U}" ] && T_2ERR_U="null"
[ -z "${Z_2R500}" ]  && Z_2R500="null"
[ -z "${Z_2ERR}" ]   && Z_2ERR="null"
[ -z "${Z_2ERR_L}" ] && Z_2ERR_L="null"
[ -z "${Z_2ERR_U}" ] && Z_2ERR_U="null"
# T & Z }}}
## json data }}}

## output data to JSON file {{{
printf "## save collected data into file \`${JSON_FILE}' ...\n"
mv -fv ${JSON_FILE} ${JSON_FILE}_bak
cat > ${JSON_FILE} << _EOF_
{
    "Obs. ID": ${OBS_ID},
    "Source Name": "${OBJ_NAME}",
    "Unified Name": "${OBJ_UNAME}",
    "Obs. Date": "${DATE_OBS}",
    "Detector": "${ACIS_TYPE}",
    "Exposure (ks)": ${EXPOSURE_RAW},
    "Clean Exposure (ks)": ${EXPOSURE_CLEAN},
    "R. A.": "${OBJ_RA}",
    "Dec.": "${OBJ_DEC}",
    "XCNTRD_RA": "${OBJ_XCRA}",
    "XCNTRD_DEC": "${OBJ_XCDEC}",
    "nH (10^22 cm^-2)": ${N_H},
    "redshift": ${REDSHIFT},
    "E(z)": ${E_Z},
    "T_ref (keV)": null,
    "Z_ref (solar)": ${ABUND},
    "Rmax_SBP (pixel)": ${RMAX_SBP_PIX},
    "Rmax_Tpro (pixel)": ${RMAX_TPRO_PIX},
    "Rmax_SBP (kpc)": ${RMAX_SBP_KPC},
    "Rmax_Tpro (kpc)": ${RMAX_TPRO_KPC},
    "NFW_Rmin (kpc)": ${NFW_RMIN_KPC},
    "Model_SBP": "${MODEL_SBP}",
    "n01": ${N01},
    "beta1": ${BETA1},
    "rc1": ${RC1},
    "rc1_kpc": ${RC1_KPC},
    "n02": ${N02},
    "beta2": ${BETA2},
    "rc2": ${RC2},
    "rc2_kpc": ${RC2_KPC},
    "bkg": ${BKG},
    "R200 (kpc)": ${R200_VAL},
    "R200_err_lower (1sigma)": ${R200_ERR_L},
    "R200_err_upper (1sigma)": ${R200_ERR_U},
    "M200 (M_sun)": ${M200_VAL},
    "M200_err_lower (1sigma)": ${M200_ERR_L},
    "M200_err_upper (1sigma)": ${M200_ERR_U},
    "L200 (erg/s)": ${L200_VAL},
    "L200_err (1sigma)": ${L200_ERR},
    "M_gas200 (M_sun)": ${MGAS200_VAL},
    "M_gas200_err_lower (1sigma)": ${MGAS200_ERR_L},
    "M_gas200_err_upper (1sigma)": ${MGAS200_ERR_U},
    "F_gas200": ${FGAS200_VAL},
    "F_gas200_err_lower (1sigma)": ${FGAS200_ERR_L},
    "F_gas200_err_upper (1sigma)": ${FGAS200_ERR_U},
    "R500 (kpc)": ${R500_VAL},
    "R500_err_lower (1sigma)": ${R500_ERR_L},
    "R500_err_upper (1sigma)": ${R500_ERR_U},
    "M500 (M_sun)": ${M500_VAL},
    "M500_err_lower (1sigma)": ${M500_ERR_L},
    "M500_err_upper (1sigma)": ${M500_ERR_U},
    "L500 (erg/s)": ${L500_VAL},
    "L500_err (1sigma)": ${L500_ERR},
    "M_gas500 (M_sun)": ${MGAS500_VAL},
    "M_gas500_err_lower (1sigma)": ${MGAS500_ERR_L},
    "M_gas500_err_upper (1sigma)": ${MGAS500_ERR_U},
    "F_gas500": ${FGAS500_VAL},
    "F_gas500_err_lower (1sigma)": ${FGAS500_ERR_L},
    "F_gas500_err_upper (1sigma)": ${FGAS500_ERR_U},
    "R1500": ${R1500_VAL},
    "R1500_err_lower": ${R1500_ERR_L},
    "R1500_err_upper": ${R1500_ERR_U},
    "M1500": ${M1500_VAL},
    "M1500_err_lower": ${M1500_ERR_L},
    "M1500_err_upper": ${M1500_ERR_U},
    "L1500": ${L1500_VAL},
    "L1500_err": ${L1500_ERR},
    "M_gas1500": ${MGAS1500_VAL},
    "M_gas1500_err_lower": ${MGAS1500_ERR_L},
    "M_gas1500_err_upper": ${MGAS1500_ERR_U},
    "F_gas1500": ${FGAS1500_VAL},
    "F_gas1500_err_lower": ${FGAS1500_ERR_L},
    "F_gas1500_err_upper": ${FGAS1500_ERR_U},
    "R2500": ${R2500_VAL},
    "R2500_err_lower": ${R2500_ERR_L},
    "R2500_err_upper": ${R2500_ERR_U},
    "M2500": ${M2500_VAL},
    "M2500_err_lower": ${M2500_ERR_L},
    "M2500_err_upper": ${M2500_ERR_U},
    "L2500": ${L2500_VAL},
    "L2500_err": ${L2500_ERR},
    "M_gas2500": ${MGAS2500_VAL},
    "M_gas2500_err_lower": ${MGAS2500_ERR_L},
    "M_gas2500_err_upper": ${MGAS2500_ERR_U},
    "F_gas2500": ${FGAS2500_VAL},
    "F_gas2500_err_lower": ${FGAS2500_ERR_L},
    "F_gas2500_err_upper": ${FGAS2500_ERR_U},
    "T(0.1-0.5 R500)": ${T_1R500},
    "T_err(0.1-0.5 R500)": ${T_1ERR},
    "T_err_l(0.1-0.5 R500)": ${T_1ERR_L},
    "T_err_u(0.1-0.5 R500)": ${T_1ERR_U},
    "Z(0.1-0.5 R500)": ${Z_1R500},
    "Z_err(0.1-0.5 R500)": ${Z_1ERR},
    "Z_err_l(0.1-0.5 R500)": ${Z_1ERR_L},
    "Z_err_u(0.1-0.5 R500)": ${Z_1ERR_U},
    "T(0.2-0.5 R500)": ${T_2R500},
    "T_err(0.2-0.5 R500)": ${T_2ERR},
    "T_err_l(0.2-0.5 R500)": ${T_2ERR_L},
    "T_err_u(0.2-0.5 R500)": ${T_2ERR_U},
    "Z(0.2-0.5 R500)": ${Z_2R500},
    "Z_err(0.2-0.5 R500)": ${Z_2ERR},
    "Z_err_l(0.2-0.5 R500)": ${Z_2ERR_L},
    "Z_err_u(0.2-0.5 R500)": ${Z_2ERR_U},
    "F_gas(R2500-R500)": ${FGRR},
    "F_gas_err_l(R2500-R500)": ${FGRR_ERR_L},
    "F_gas_err_u(R2500-R500)": ${FGRR_ERR_U},
    "R_cool (kpc)": ${RCOOL},
    "Cooling_time (Gyr)": ${COOLING_TIME},
    "Cool_core": ${COOLCORE},
    "Feature": "${OBJ_FEATURE}",
    "NOTE": "${OBJ_NOTE}"
},
_EOF_
## output JSON }}}

exit 0
