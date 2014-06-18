#!/bin/sh
#
# for 'z>0.3' or 'counts_in_0.048R500<500'
# execute this script in dir 'spc/profile'
#
# original filename: 'proxy_calc.sh', by Zhu Zhenhao
# modified by: Weitian LI
#
# ChangeLog:
#   2014/06/18: added answer for WR (warn region)
#

## error code {{{
ERR_USG=1
ERR_CALC=11
ERR_DIR=12
ERR_JSON=13
ERR_EXPMAP=14
ERR_EVTE=15
ERR_Z=21
ERR_CNT=22
## }}}

## cosmology claculator {{{
## write the path of cosmo claculator here
BASE_PATH=`dirname $0`
COSMO_CALC=`which cosmo_calc`
if [ -z "${COSMO_CALC}" ] || [ ! -x  ${COSMO_CALC} ] ; then 
    printf "ERROR: ${COSMO_CALC} neither executable nor specified\n"
    exit ${ERR_CALC}
fi
## }}}

## usage, help {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` evt_e=<evt_e_name> expmap=<expmap_name> basedir=<base_dir> imgdir=<img_dir> json=<json_name>\n"
        printf "NOTE: exec this script in dir 'spc/profile'\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
# default basedir relative to 'spc/profile'
DFT_BASEDIR="../.."
# default imgdir relative to 'basedir'
DFT_IMGDIR="img"
# default expmap pattern
DFT_EXPMAP_PAT="expmap_c*.fits"
# default evt_e pattern
DFT_EVTE_PAT="evt2_c*_e700-7000.fits"
# default json file pattern
DFT_JSON_PAT="*_INFO.json"
#
RSPEC_REG="rspec.reg"
CSB_RES="csb_results.txt"
#
INIT_DIR=`pwd -P`
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

# basedir
if [ -d "${basedir}" ] && ls ${basedir}/*repro_evt2.fits > /dev/null 2>&1; then
    BASEDIR=${basedir}
elif [ -d "${DFT_BASEDIR}" ] && ls ${DFT_BASEDIR}/*repro_evt2.fits > /dev/null 2>&1; then
    BASEDIR=${DFT_BASEDIR}
else
    read -p "> basedir (contains info json): " BASEDIR
    if [ ! -d "${BASEDIR}" ] || ! ls ${BASEDIR}/*repro_evt2.fits >/dev/null 2>&1; then
        printf "ERROR: given \`${BASEDIR}' invalid!\n"
        exit ${ERR_DIR}
    fi
fi
BASEDIR=`( cd ${BASEDIR} && pwd -P )`
printf "## use basedir: \`${BASEDIR}'\n"
# img dir
if [ ! -z "${imgdir}" ] && [ -d "${BASEDIR}/${imgdir}" ]; then
    IMG_DIR=`( cd ${BASEDIR}/${imgdir} && pwd -P )`
elif [ -d "${BASEDIR}/${DFT_IMGDIR}" ]; then
    IMG_DIR=`( cd ${BASEDIR}/${DFT_IMGDIR} && pwd -P )`
else
    read -p "> img dir (relative to basedir): " IMG_DIR
    if [ ! -d "${BASEDIR}/${IMG_DIR}" ]; then
        printf "ERROR: given \`${IMG_DIR}' invalid\n"
        exit ${ERR_DIR}
    else
        IMG_DIR="${BASEDIR}/${IMG_DIR}"
    fi
fi
printf "## use imgdir: \`${IMG_DIR}'\n"
# info json
if [ ! -z "${json}" ] && [ -r "${BASEDIR}/${json}" ]; then
    JSON_FILE="${BASEDIR}/${json}"
elif [ `ls -1 ${BASEDIR}/${DFT_JSON_PAT} 2>/dev/null | wc -l` -eq 1 ]; then
    JSON_FILE="`ls ${BASEDIR}/${DFT_JSON_PAT} 2>/dev/null`"
else
    read -p "> info json: " JSON_FILE
    if [ ! -r "${BASEDIR}/${JSON_FILE}" ]; then
        printf "ERROR: given \`${JSON_FILE}' not exist!\n"
        exit ${ERR_JSON}
    fi
fi
printf "## use json_file: \`${JSON_FILE}'\n"
# expmap
if [ ! -z "${expmap}" ] && [ -r "${IMG_DIR}/${expmap}" ]; then
    EXPMAP="${expmap}"
elif [ `ls -1 ${IMG_DIR}/${DFT_EXPMAP_PAT} 2>/dev/null | wc -l` -eq 1 ]; then
    EXPMAP="`( cd ${IMG_DIR} && ls ${DFT_EXPMAP_PAT} 2>/dev/null )`"
else
    read -p "> expmap filename: " EXPMAP
    if [ ! -r "${IMG_DIR}/${EXPMAP}" ]; then
        printf "ERROR: given \`${EXPMAP}' not exist!\n"
        exit ${ERR_EXPMAP}
    fi
fi
printf "## use expmap: \`${EXPMAP}'\n"
# evt_e
if [ ! -z "${evt_e}" ] && [ -r "${IMG_DIR}/${evt_e}" ]; then
    EVT_E="${evt_e}"
elif [ `ls -1 ${IMG_DIR}/${DFT_EVTE_PAT} 2>/dev/null | wc -l` -eq 1 ]; then
    EVT_E="`( cd ${IMG_DIR} && ls ${DFT_EVTE_PAT} 2>/dev/null )`"
else
    read -p "> evt_e filename: " EVT_E
    if [ ! -r "${IMG_DIR}/${EVT_E}" ]; then
        printf "ERROR: given \`${EVT_E}' not exist!\n"
        exit ${ERR_EVTE}
    fi
fi
printf "## use evt_e: \`${EVT_E}'\n"
## }}}

## main {{{
# in 'spc/profile'
X=`grep -iE '(pie|annulus)' ${RSPEC_REG} | head -n 1 | awk -F'(' '{ print $2 }' | awk -F',' '{ print $1 }'`
Y=`grep -iE '(pie|annulus)' ${RSPEC_REG} | head -n 1 | awk -F'(' '{ print $2 }' | awk -F',' '{ print $2 }'`
# json file
Z=`grep -i '"redshift"' ${JSON_FILE} | awk -F':' '{ print $2 }' | tr -d ' ,'`
R500=`grep '"R500.*kpc' ${JSON_FILE} | awk -F':' '{ print $2 }' | tr -d ' ,'`
OBS_ID=`grep '"Obs.*ID' ${JSON_FILE} | awk -F':' '{ print $2 }' | tr -d ' ,'`
OBJ_NAME=`grep '"Source\ Name' ${JSON_FILE} | awk -F':' '{ print $2 }' | sed -e 's/\ *"//' -e 's/"\ *,$//'`
CT=`grep '"Cooling_time' ${JSON_FILE} | awk -F':' '{ print $2 }' | tr -d ' ,'`

cd ${IMG_DIR}
printf "entered img directory\n"

### test Z>0.3?
if [ `echo "${Z} < 0.3" | bc -l` -eq 1 ]; then
    F_WZ=true
    WZ="WZ"
    printf "*** WARNING: redshift z=${Z} < 0.3 ***\n"
#    exit ${ERR_Z}
fi

KPC_PER_PIXEL=`${COSMO_CALC} ${Z} | grep 'kpc/pixel' | awk '{ print $3 }'`
RC_PIX=`echo "scale=2; 0.048 * ${R500} / ${KPC_PER_PIXEL}" | bc -l`
# test counts_in_0.048R500<500?
RC_REG="pie(${X},${Y},0,${RC_PIX},0,360)"
punlearn dmlist
CNT_RC=`dmlist infile="${EVT_E}[sky=${RC_REG}]" opt=block | grep 'EVENTS' | awk '{ print $8 }'`
printf "R500=${R500}, 0.048R500_pix=${RC_PIX}, counts_in_0.048R500=${CNT_RC}\n"
if [ ${CNT_RC} -gt 500 ]; then
    F_WC=true
    WC="WC"
    printf "*** WARNING: counts_in_0.048R500=${CNT_RC} > 500 ***\n"
#    exit ${ERR_CNT}
fi

TMP_REG="_tmp_csb.reg"
TMP_S="_tmp_csb.fits"

R1=`echo "scale=2;  40 / ${KPC_PER_PIXEL}" | bc -l`
R2=`echo "scale=2; 400 / ${KPC_PER_PIXEL}" | bc -l` 
cat > ${TMP_REG} << _EOF_
pie(${X},${Y},0,${R1},0,360)
pie(${X},${Y},0,${R2},0,360)
_EOF_

printf "CHECK the regions (R1=${R1}, R2=${R2}) ...\n"
ds9 ${EVT_E} -regions ${TMP_REG} -cmap sls -bin factor 4
read -p "> Whether the region exceeds ccd edge?(y/N) " F_WR
case "${F_WR}" in
    [yY]*)
        WR="WR"
        ;;
    *)
        WR=""
        ;;
esac

punlearn dmextract
dmextract infile="${EVT_E}[bin sky=@${TMP_REG}]" outfile="${TMP_S}" exp=${EXPMAP} opt=generic clobber=yes
punlearn dmlist
S1=`dmlist "${TMP_S}[cols SUR_FLUX]" opt="data,clean" | grep -v '#' | sed -n -e 's/\ *//' -e '1p'`
S2=`dmlist "${TMP_S}[cols SUR_FLUX]" opt="data,clean" | grep -v '#' | sed -n -e 's/\ *//' -e '2p'`
CSB=`echo "${S1} ${S2}" | awk '{ print $1/$2/100 }'` 

## back to original spc/profile directory
cd ${INIT_DIR}

[ -e ${CSB_RES} ] && mv -f ${CSB_RES} ${CSB_RES}_bak
printf "\n==============================\n"
printf "z=${Z}, R500=${R500} (kpc)\n" | tee -a ${CSB_RES}
printf "0.048R500=${RC_PIX}, counts=${CNT_RC}\n" | tee -a ${CSB_RES}
printf "R1=${R1}, R2=${R2} (pixel)\n" | tee -a ${CSB_RES}
printf "S1=${S1}, S2=${S2} (sur_flux)\n" | tee -a ${CSB_RES}
printf "C_sb: ${CSB}\n" | tee -a ${CSB_RES}
[ "x${F_WZ}" = "xtrue" ] && printf "${WZ}\n" | tee -a ${CSB_RES}
[ "x${F_WC}" = "xtrue" ] && printf "${WC}\n" | tee -a ${CSB_RES}
printf "# OBS_ID,OBJ_NAME,Z,R500,RC_PIX,CNT_RC,CT,R1_PIX,R2_PIX,S1,S2,CSB,WZ,WC,WR\n" | tee -a ${CSB_RES}
printf "# $OBS_ID,$OBJ_NAME,$Z,$R500,$RC_PIX,$CNT_RC,$CT,$R1,$R2,$S1,$S2,$CSB,$WZ,$WC,$WR\n\n" | tee -a ${CSB_RES}
## main }}}

exit 0

