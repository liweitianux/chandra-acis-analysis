#!/bin/sh
##
## Make exposure map and exposure-corrected image (revoke 'ciao_expcorr.sh'),
## and extract surface brightness profile (revoke 'ciao_sbp.sh').
##
## ChangeLogs:
## v4.2, 2015/03/05, Weitian LI
##   * Added exit code check for the 'EXPCORR_SCRIPT' and 'EXTRACT_SBP_SCRIPT'
##   * Removed the code of 'spc_fit.cfg' generation
##   * Removed the code to make links of sbp2.dat, sbp3.dat and radius.dat
## v4.1, 2014/10/30, Weitian LI
##   * updated 'EXPCORR_SCRIPT' & 'EXTRACT_SBP_SCRIPT',
##   * removed version number in scripts filename.
## v4, 2013/10/12, LIweitiaNux
##   * split out the 'generate regions' parts -> 'ciao_genreg_v1.sh'
## v3, 2013/05/03, LIweitiaNux
##   * add parameter 'ds9' to check the centroid and regions
##

UPDATED="2015/03/05"

unalias -a
export LC_COLLATE=C

SCRIPT_PATH=`readlink -f $0`
SCRIPT_DIR=`dirname ${SCRIPT_PATH}`
EXPCORR_SCRIPT="ciao_expcorr.sh"
EXTRACT_SBP_SCRIPT="ciao_sbp.sh"

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
        printf "    `basename $0` evt=<evt2_clean> sbp_reg=<sbprofile.reg> nh=<nh> z=<redshift> temp=<avg_temp> abund=<avg_abund> cellreg=<celld_reg> expcorr=<yes|no>\n"
        printf "\nVersion: ${UPDATED}\n"
        exit ${ERR_USG}
        ;;
esac
## usage }}}

## default parameters {{{ 
## clean evt2 file
DFT_EVT=`ls evt2*_clean.fits 2> /dev/null`
## the repro dir
DFT_BASEDIR=".."

## xcentroid region
DFT_SBP_REG="sbprofile.reg"

## log file
DFT_LOGFILE="expcorr_sbp_`date '+%Y%m%d'`.log"

## cell region
DFT_CELL_REG=`ls celld*.reg 2> /dev/null`

## background spectra
DFT_BKGD=`ls bkgcorr_bl*.pi 2> /dev/null`
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
if [ -r "${sbp_reg}" ]; then
    SBP_REG="${sbp_reg}"
elif [ -r "${DFT_SBP_REG}" ] ;then
    SBP_REG="${DFT_SBP_REG}" 
else
    read -p "sbp region file: " SBP_REG
    if [ ! -r "${SBP_REG}" ]; then
        printf "ERROR: cannot access given \`${SBP}' sbp region file\n"
        exit ${ERR_REG}
    fi
fi

## nh z temp abund
if [ -z "${nh}" ]; then
    read -p "> value of nH: " N_H
else
    N_H=${nh}
fi
if [ -z "${z}" ]; then
    read -p "> value of redshift: " REDSHIFT
else
    REDSHIFT=${z}
fi
if [ -z "${temp}" ]; then
    read -p "> object average temperature: " TEMP
else
    TEMP=${temp}
fi
if [ -z "${abund}" ]; then
    read -p "> object average abundance: " ABUND
else
    ABUND=${abund}
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

# point source region
if [ -r "${cellreg}" ]; then
    CELL_REG=${cellreg}
elif [ -r "${DFT_CELL_REG}" ]; then
    CELL_REG=${DFT_CELL_REG}
else
    read -p ">point source region file: " CELL_REG
    if [ ! -d ${CELL_REG} ] ; then
        printf " ERROR no point source region\n"
        exit ${ERR_REG}
    fi
fi

## expcorr: flag to determine whether to process expcorr
if [ ! -z "${expcorr}" ]; then
    case "${expcorr}" in
        [nN][oO]|[fF]*)
            F_EXPCORR="NO"
            ;;
        *)
            F_EXPCORR="YES"
            ;;
    esac
else
    F_EXPCORR="YES"
fi
## parameters }}}

if [ "${F_EXPCORR}" = "NO" ]; then
    printf "################################\n"
    printf "### SKIP EXPOSURE CORRECTION ###\n"
    printf "################################\n\n"
else
    printf "======== EXPOSURE CORRECTION =======\n"
    CMD="${SCRIPT_DIR}/${EXPCORR_SCRIPT} evt=${EVT} basedir=${BASEDIR} nh=${N_H} z=${REDSHIFT} temp=${TEMP} abund=${ABUND}"
    printf "CMD: ${CMD}\n"
    ${SCRIPT_DIR}/${EXPCORR_SCRIPT} evt=${EVT} basedir=${BASEDIR} nh=${N_H} z=${REDSHIFT} temp=${TEMP} abund=${ABUND}
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -ne 0 ]; then
        printf "Following command failed with code: ${EXIT_CODE}\n"
        printf "    '${CMD}'\n"
        exit ${EXIT_CODE}
    fi
    printf "======== EXPOSURE CORRECTION FINISHED =======\n\n"
fi

EXPMAP=`ls expmap*e700-7000*fits 2> /dev/null`
EVT_E=`ls evt*e700-7000*fits 2> /dev/null`

printf "======== EXTRACT SBP =======\n"
CMD="${SCRIPT_DIR}/${EXTRACT_SBP_SCRIPT} evt_e=${EVT_E} reg=${SBP_REG} expmap=${EXPMAP} cellreg=${CELL_REG}"
printf "CMD: ${CMD}\n"
${SCRIPT_DIR}/${EXTRACT_SBP_SCRIPT} evt_e=${EVT_E} reg=${SBP_REG} expmap=${EXPMAP} cellreg=${CELL_REG}
EXIT_CODE=$?
if [ ${EXIT_CODE} -ne 0 ]; then
    printf "Following command failed with code: ${EXIT_CODE}\n"
    printf "    '${CMD}'\n"
    exit ${EXIT_CODE}
fi
printf "======== EXTRACT SBP FINISHED =======\n\n"

exit 0

