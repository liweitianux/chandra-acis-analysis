#!/bin/sh
##
## Generate regions for 'radial spectra analysis' (rspec.reg),
## and regions for 'surface brightness profile' extraction.
##
## Author: Weitian LI
## Created: 2013/10/12
##
VERSION="v1.0"
UPDATE="2013/10/12"
##
## Changelogs:
## v2.0, 2015/06/03, Aaron LI
##   * Updated script description
##   * Replaced 'grep' with '\grep', 'ls' with '\ls'
##   * ds9 colormap changed from 'sls' to 'he'
##   * Copy needed pfiles to current working directory, and
##     set environment variable $PFILES to use these first.
## v1.0, 2013/10/12, Weitian LI
##   split from 'ciao_expcorr_sbp_v3.sh'
##

unalias -a
export LC_COLLATE=C

SCRIPT_PATH=`readlink -f $0`
SCRIPT_DIR=`dirname ${SCRIPT_PATH}`
XCENTROID_SCRIPT="chandra_xcentroid.sh"
GEN_SPCREG_SCRIPT="chandra_genspcreg.sh"
GEN_SBPREG_SCRIPT="chandra_gensbpreg.sh"

## err code {{{
ERR_USG=1
ERR_DIR=11
ERR_EVT=12
ERR_BKG=13
ERR_REG=14
ERR_ASOL=21
ERR_BPIX=22
ERR_PBK=23
ERR_MSK=24
ERR_BKGTY=31
ERR_SPEC=32
ERR_DET=41
ERR_ENG=42
ERR_CIAO=100
## error code }}}

## usage {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` evt=<evt2_clean> reg_in=<reg_in> bkgd=<bkgd_spec> ds9=<Yes|no>\n"
        printf "\nversion:\n"
        printf "    ${VERSION}, ${UPDATED}\n"
        exit ${ERR_USG}
        ;;
esac
## usage }}}

## link needed files {{{
BKGD_FILE=`\ls ../bkg/bkgcorr_bl*.pi 2> /dev/null | head -n 1`
if [ -r "${BKGD_FILE}" ]; then
    ln -svf ${BKGD_FILE} .
fi
ASOL_FILE=`\ls ../pcad*_asol?.fits 2> /dev/null`
if [ -r "${ASOL_FILE}" ]; then
    ln -svf ${ASOL_FILE} .
fi
CELL_REG_FILE=`\ls ../evt/celld*.reg 2> /dev/null | \grep -v 'orig'`
if [ -r "${CELL_REG_FILE}" ]; then
    ln -svf ${CELL_REG_FILE} .
fi
# }}}

## default parameters {{{ 
## clean evt2 file
DFT_EVT=`\ls evt2*_clean.fits 2> /dev/null`
## the repro dir
DFT_BASEDIR=".."
# default `asol file'
ASOL="`\ls pcadf*_asol1.fits 2> /dev/null | head -n 1`"

## energy range
# format: `E_START:E_END:E_WIDTH'
DFT_ENERGY=700:7000:100
E_START=`echo ${DFT_ENERGY} | awk -F':' '{ print $1 }'`
E_END=`echo ${DFT_ENERGY} | awk -F':' '{ print $2 }'`

## log file
DFT_LOGFILE="genreg_`date '+%Y%m%d'`.log"

## background spectra
DFT_BKGD=`\ls bkgcorr_bl*.pi | head -n 1`
## default parameters }}}

## functions {{{
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

## check ciao init and set path to solve conflit with heasoft {{{
if [ -z "${ASCDS_INSTALL}" ]; then
    printf "ERROR: CIAO NOT initialized\n"
    exit ${ERR_CIAO}
fi

## XXX: heasoft's `pget' etc. tools conflict with some CIAO tools
printf "set \$PATH to avoid conflicts between HEAsoft and CIAO\n"
export PATH="${ASCDS_BIN}:${ASCDS_CONTRIB}:${PATH}"
printf "## PATH: ${PATH}\n"
## check ciao&heasoft}}}

## parameters {{{
getopt_keyval "$@"

##log file
LOGFILE="not_exist"

##check evt file

if [ -r "${evt}" ]; then
    EVT=${evt}
elif [ -r "${DFT_EVT}" ]; then
    EVT=${DFT_EVT}
else
    read -p "clean evt2 file: " EVT
    if [ ! -r "${EVT}" ]; then
        printf "ERROR: cannot access given \`${EVT}' evt file\n"
        exit ${ERR_EVT}
    fi
fi

##check ori sbp region
if [ -r "${reg_in}" ]; then
    REG_IN="${reg_in}"
else
    read -p "input region file: " REG_IN
    if [ ! -r "${REG_IN}" ]; then
        printf "ERROR: cannot access given \`${REG_IN}' evt file\n"
        exit ${ERR_REG}
    fi
fi

# check give basedir
if [ -d "${basedir}" ]; then
    BASEDIR=${basedir}
elif [ -d "${DFT_BASEDIR}" ]; then
    BASEDIR=${DFT_BASEDIR}
else
    read -p "> basedir (contains asol files): " BASEDIR
    if [ ! -d "${BASEDIR}" ]; then
        printf "ERROR: given \`${BASEDIR}' NOT a directory\n"
        exit ${ERR_DIR}
    fi
fi
# remove the trailing '/'
BASEDIR=`echo ${BASEDIR} | sed 's/\/*$//'`

#background spectrum
if [ -r "${bkgd}" ] ;then
    BKGD=${bkgd}
elif [ -r "${DFT_BKGD}" ] ; then 
    BKGD="${DFT_BKGD}"
    #ln -svf ${DFT_BKGD} .
else 
    read -p ">background spectrum file: " BKGD
    if [ ! -d ${BKGD} ] ; then
        printf "ERROR on background spectrum file"
        exit ${ERR_BKG}
    fi
fi

## ds9: flag to determine whether to use ds9 check centroid and regions
if [ ! -z "${ds9}" ]; then
    case "${ds9}" in
        [nN][oO]|[fF]*)
            F_DS9="NO"
            ;;
        *)
            F_DS9="YES"
            ;;
    esac
else
    F_DS9="YES"
fi
## parameters }}}

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="dmkeypar dmcopy dmcoords"

# Copy necessary pfiles for localized usage
for tool in ${CIAO_TOOLS}; do
    pfile=`paccess ${tool}`
    [ -n "${pfile}" ] && punlearn ${tool} && cp -Lvf ${pfile} .
done

# Modify environment variable 'PFILES' to use local pfiles first
export PFILES="./:${PFILES}"
## pfiles }}}

## determine ACIS type {{{
# consistent with `ciao_procevt'
punlearn dmkeypar
DETNAM=`dmkeypar ${EVT} DETNAM echo=yes`
if echo ${DETNAM} | \grep -q 'ACIS-0123'; then
    printf "## \`DETNAM' (${DETNAM}) has chips 0123\n"
    printf "## ACIS-I\n"
    ACIS_TYPE="ACIS-I"
    CCD="0:3"
    NEW_DETNAM="ACIS-0123"
    ROOTNAME="c0-3_e${E_START}-${E_END}"
elif echo ${DETNAM} | \grep -q 'ACIS-[0-6]*7'; then
    printf "## \`DETNAM' (${DETNAM}) has chip 7\n"
    printf "## ACIS-S\n"
    ACIS_TYPE="ACIS-S"
    CCD="7"
    NEW_DETNAM="ACIS-7"
    ROOTNAME="c7_e${E_START}-${E_END}"
else
    printf "ERROR: unknown detector type: ${DETNAM}\n"
    exit ${ERR_DET}
fi
## ACIS type }}}

## filter by energy band
printf "filter out events in energy band: \`${E_START}:${E_END}' ...\n"
EVT_E="evt2_${ROOTNAME}.fits"
if [ ! -r "${EVT_E}" ]; then
    punlearn dmcopy
    dmcopy infile="${EVT}[energy=${E_START}:${E_END}]" outfile="${EVT_E}" clobber=yes
fi

printf "======== X-RAY CENTROID =======\n"
CMD="${SCRIPT_DIR}/${XCENTROID_SCRIPT} evt=${EVT} reg=${REG_IN} conv=yes 2>&1 | tee xcentroid.dat"
printf "CMD: $CMD\n"
${SCRIPT_DIR}/${XCENTROID_SCRIPT} evt=${EVT} reg=${REG_IN} conv=yes 2>&1 | tee xcentroid.dat
X=`\grep '(X,Y)' xcentroid.dat | tr -d ' XY():' | awk -F',' '{ print $2 }'`
Y=`\grep '(X,Y)' xcentroid.dat | tr -d ' XY():' | awk -F',' '{ print $3 }'`
CNTRD_WCS_REG="centroid_wcs.reg"
CNTRD_PHY_REG="centroid_phy.reg"
printf "## X centroid: ($X,$Y)\n"
if [ "${F_DS9}" = "YES" ]; then
    printf "check the X centroid ...\n"
    ds9 ${EVT_E} -regions ${CNTRD_PHY_REG} -cmap he -bin factor 4
fi
X0=$X
Y0=$Y
X=`\grep -i 'point' ${CNTRD_PHY_REG} | head -n 1 | tr -d 'a-zA-Z() ' | awk -F',' '{ print $1 }'`
Y=`\grep -i 'point' ${CNTRD_PHY_REG} | head -n 1 | tr -d 'a-zA-Z() ' | awk -F',' '{ print $2 }'`
if [ "x${X}" != "x${X0}" ] || [ "x${Y}" != "x${Y0}" ]; then
    printf "## X CENTROID CHANGED -> ($X,$Y)\n"
    # update ${CNTRD_WCS_REG}
    printf "update ${CNTRD_WCS_REG} ...\n"
    rm -f ${CNTRD_WCS_REG}
    punlearn dmcoords
    dmcoords infile="${EVT}" asolfile="${ASOL}" option=sky x=${X} y=${Y}
    RA=`pget dmcoords ra`
    DEC=`pget dmcoords dec`
    echo "point(${RA},${DEC})" > ${CNTRD_WCS_REG}
fi
printf "======== X-RAY CENTROID FINISHED =======\n\n"

SPC_REG=rspec.reg
SBP_REG=sbprofile.reg

printf "======== GENERATE SBPROFILE REGIONS =======\n"
CMD="${SCRIPT_DIR}/${GEN_SBPREG_SCRIPT} ${EVT} ${EVT_E} ${X} ${Y} ${BKGD} ${SBP_REG}"
printf "CMD: ${CMD}\n"
${SCRIPT_DIR}/${GEN_SBPREG_SCRIPT} ${EVT} ${EVT_E} ${X} ${Y} ${BKGD} ${SBP_REG}
if [ "${F_DS9}" = "YES" ]; then
    printf "check SBP regions ...\n"
    ds9 ${EVT_E} -regions ${SBP_REG} -cmap sls -bin factor 4
fi
printf "======== GENERATE SBPROFILE REGIONS FINISHED =======\n\n"

printf "======== GENERATE SPECTRUM REGIONS =======\n"
CMD="${SCRIPT_DIR}/${GEN_SPCREG_SCRIPT} ${EVT} ${EVT_E} ${BKGD} ${X} ${Y} ${SPC_REG}"
printf "CMD: ${CMD}\n"
${SCRIPT_DIR}/${GEN_SPCREG_SCRIPT} ${EVT} ${EVT_E} ${BKGD} ${X} ${Y} ${SPC_REG}
if [ "${F_DS9}" = "YES" ]; then
    printf "check SPC regions ...\n"
    ds9 ${EVT_E} -regions ${SPC_REG} -cmap he -bin factor 4
fi
printf "======== GENERATE SPECTRUM REGIONS FINISHED =======\n\n"

exit 0

