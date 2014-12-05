#!/bin/sh
#
# This script is used to make a bare '_INFO.json' file
# placed under directory 'repro/',
# thus scripts 'ciao_calc_ct.sh' and 'ciao_calc_csb.sh'
# can get required information from this file.
#
# Run this script in directory 'repro/'.
#
# Weitian LI <liweitianux@gmail.com>
# 2014/06/24
#
# ChangeLog:
# v1.1, 2014/12/05, Weitian LI
#   regex '\s+' not supported by old grep version, change to use '[[:space:]]+'
#

## usage, help {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` evtdir=<evt_dir> spcdir=<spc_dir> imgdir=<img_dir> massdir=<mass_dir> json=<info_json>\n"
        printf "NOTE: run this script in dir 'repro/'\n"
        exit 1
        ;;
esac
## usage, help }}}

## default parameters {{{
# basedir: . (run this script under basedir)
BASEDIR=`pwd -P`
#
## directory structure of wjy's data
# default evtdir relative to 'basedir'
DFT_EVTDIR="../evt2/evt"
# default spcdir relative to 'basedir'
DFT_SPCDIR="../evt2/spc/profile"
# default imgdir relative to 'basedir'
DFT_IMGDIR="../evt2/img"
# default massdir relative to 'basedir'
DFT_MASSDIR="../evt2/mass"
## }}}

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

# evt dir
if [ ! -z "${evtdir}" ] && [ -d "${BASEDIR}/${evtdir}" ]; then
    EVT_DIR=`( cd ${BASEDIR}/${evtdir} && pwd -P )`
elif [ -d "${BASEDIR}/${DFT_EVTDIR}" ]; then
    EVT_DIR=`( cd ${BASEDIR}/${DFT_EVTDIR} && pwd -P )`
else
    read -p "> evt dir (relative to basedir): " EVT_DIR
    if [ ! -d "${BASEDIR}/${EVT_DIR}" ]; then
        printf "ERROR: given \`${EVT_DIR}' invalid\n"
        exit 20
    else
        EVT_DIR="${BASEDIR}/${EVT_DIR}"
    fi
fi
printf "## use evtdir: \`${EVT_DIR}'\n"

# spc dir
if [ ! -z "${spcdir}" ] && [ -d "${BASEDIR}/${spcdir}" ]; then
    SPC_DIR=`( cd ${BASEDIR}/${spcdir} && pwd -P )`
elif [ -d "${BASEDIR}/${DFT_SPCDIR}" ]; then
    SPC_DIR=`( cd ${BASEDIR}/${DFT_SPCDIR} && pwd -P )`
else
    read -p "> spc dir (relative to basedir): " SPC_DIR
    if [ ! -d "${BASEDIR}/${SPC_DIR}" ]; then
        printf "ERROR: given \`${SPC_DIR}' invalid\n"
        exit 21
    else
        SPC_DIR="${BASEDIR}/${SPC_DIR}"
    fi
fi
printf "## use spcdir: \`${SPC_DIR}'\n"

# img dir
if [ ! -z "${imgdir}" ] && [ -d "${BASEDIR}/${imgdir}" ]; then
    IMG_DIR=`( cd ${BASEDIR}/${imgdir} && pwd -P )`
elif [ -d "${BASEDIR}/${DFT_IMGDIR}" ]; then
    IMG_DIR=`( cd ${BASEDIR}/${DFT_IMGDIR} && pwd -P )`
else
    read -p "> img dir (relative to basedir): " IMG_DIR
    if [ ! -d "${BASEDIR}/${IMG_DIR}" ]; then
        printf "ERROR: given \`${IMG_DIR}' invalid\n"
        exit 22
    else
        IMG_DIR="${BASEDIR}/${IMG_DIR}"
    fi
fi
printf "## use imgdir: \`${IMG_DIR}'\n"

# mass dir
if [ ! -z "${massdir}" ] && [ -d "${BASEDIR}/${massdir}" ]; then
    MASS_DIR=`( cd ${BASEDIR}/${massdir} && pwd -P )`
elif [ -d "${BASEDIR}/${DFT_MASSDIR}" ]; then
    MASS_DIR=`( cd ${BASEDIR}/${DFT_MASSDIR} && pwd -P )`
else
    read -p "> mass dir (relative to basedir): " MASS_DIR
    if [ ! -d "${BASEDIR}/${MASS_DIR}" ]; then
        printf "ERROR: given \`${MASS_DIR}' invalid\n"
        exit 22
    else
        MASS_DIR="${BASEDIR}/${MASS_DIR}"
    fi
fi
printf "## use massdir: \`${MASS_DIR}'\n"
## }}}

# set files
EVT2_CLEAN=`readlink -f ${EVT_DIR}/evt2*_clean*.fits | head -n 1`
MASS_SBP_CFG=`readlink -f ${MASS_DIR}/source.cfg`
MASS_RES=`readlink -f ${MASS_DIR}/final_result*.txt`
SPC_CFG=`readlink -f ${IMG_DIR}/spc_fit.cfg`

# get needed data
punlearn dmkeypar
OBSID=`dmkeypar "${EVT2_CLEAN}" OBS_ID echo=yes`
NAME=`dmkeypar "${EVT2_CLEAN}" OBJECT echo=yes`
Z=`grep -E '^z[[:space:]]+' ${MASS_SBP_CFG} | awk '{ print $2 }'`
NH=`grep -E '^nh[[:space:]]+' ${SPC_CFG} | awk '{ print $2 }'`
R500=`grep -E '^r500=' ${MASS_RES} | awk '{ print $2 }'`

# generate info json file
if [ ! -z "${json}" ]; then
    JSON_FILE="${json}"
else
    JSON_FILE="oi${OBSID}_INFO.json"
fi
printf "## info json_filename: \`${JSON_FILE}'\n"

cat > ${JSON_FILE} << _EOF_
{
    "Obs. ID": ${OBSID},
    "Source Name": "${NAME}",
    "nH (10^22 cm^-2)": ${NH},
    "redshift": ${Z},
    "R500 (kpc)": ${R500},
    "Comment": "Bare info json file created by `basename $0`"
},
_EOF_

