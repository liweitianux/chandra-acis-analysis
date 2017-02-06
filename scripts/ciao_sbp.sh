#!/bin/sh
##
## Extract `surface brighness profile' after exposure correction finished.
##
## NOTES:
## * Only ACIS-I (chip: 0-3) and ACIS-S (chip: 7) supported
##
## Weitian LI <liweitianux@gmail.com>
## Created: 2012/08/16
##
VERSION="v4.1"
UPDATED="2017-02-06"
##
## ChangeLogs:
## v4.1, 2017-02-06, Weitian LI
##   * Specify regions format and system for ds9
## v4.0, 2015/06/03, Aaron LI
##   * Copy needed pfiles to current working directory, and
##     set environment variable $PFILES to use these first.
##   * Replaced 'grep' with '\grep', 'ls' with '\ls'
## v3.3, 2015/03/29, Weitian LI
##   * Skip skyfov generation if it already exists.
##   * Rename parameter 'aspec' to 'aspect' to match with 'skyfov'
## v3.2, 2015/03/06, Weitian LI
##   * Updated this document of the script.
##   * Added 'SKIP SINGLE' to the generated QDP of SBP file.
## v3.1, 2013/02/01, Zhenghao ZHU
##   * removes the region in ccd gap of ACIS_I
##   * removes the region in the area of point source
##   * provide asol file to correct offset
##

unalias -a
export LC_COLLATE=C

SCRIPT_PATH=`readlink -f $0`
SCRIPT_DIR=`dirname ${SCRIPT_PATH}`
CCDGAP_SCRIPT="chandra_ccdgap_rect.py"

## error code {{{
ERR_USG=1
ERR_DIR=11
ERR_EVT=12
ERR_BKG=13
ERR_REG=14
ERR_CELL_REG=15
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

## usage, help {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` evt_e=<evt_e_file> reg=<sbp_reg> expmap=<exp_map> cellreg=<cell_reg> aspect=<asol_file> [bkg=<bkg> log=<logfile> ]\n"
        printf "\nversion:\n"
        printf "    ${VERSION}, ${UPDATED}\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
# default energy band
E_RANGE="700:7000"
# default ccd edge cut pixel (20pixel)
DFT_CCD_EDGECUT=25
# default `event file' which used to match `blanksky' files
#DFT_EVT="_NOT_EXIST_"
DFT_EVT_E="`\ls evt2_*_e*.fits 2> /dev/null`"
# default expmap
DFT_EXPMAP="`\ls expmap*.fits 2> /dev/null | head -n 1`"
# default `radial region file' to extract surface brightness
#DFT_SBP_REG="_NOT_EXIST_"
DFT_SBP_REG="sbprofile.reg"
# defalut pointsource region file
DFT_CELL_REG="`\ls celld*.reg 2> /dev/null`"
# defalut asol file
DFT_ASOL_FILE="`\ls -1 pcad*asol*fits 2> /dev/null`"

# default `log file'
DFT_LOGFILE="sbp_`date '+%Y%m%d'`.log"

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

## check CIAO init {{{
if [ -z "${ASCDS_INSTALL}" ]; then
    printf "ERROR: CIAO NOT initialized\n"
    exit ${ERR_CIAO}
fi

## XXX: heasoft's `pget' etc. tools conflict with some CIAO tools
printf "set \$PATH to avoid conflicts between HEAsoft and CIAO\n"
export PATH="${ASCDS_BIN}:${ASCDS_CONTRIB}:${PATH}"
printf "## PATH: ${PATH}\n"
## check CIAO }}}

## parameters {{{
# process cmdline args using `getopt_keyval'
getopt_keyval "$@"

## check log parameters {{{
if [ ! -z "${log}" ]; then
    LOGFILE="${log}"
else
    LOGFILE=${DFT_LOGFILE}
fi
printf "## use logfile: \`${LOGFILE}'\n"
[ -e "${LOGFILE}" ] && mv -fv ${LOGFILE} ${LOGFILE}_bak
TOLOG="tee -a ${LOGFILE}"
echo "process script: `basename $0`" >> ${LOGFILE}
echo "process date: `date`" >> ${LOGFILE}
## log }}}

# check given parameters
# check evt file
if [ -r "${evt_e}" ]; then
    EVT_E=${evt_e}
elif [ -r "${DFT_EVT_E}" ]; then
    EVT_E=${DFT_EVT_E}
else
    read -p "clean evt2 file: " EVT_E
    if [ ! -r "${EVT_E}" ]; then
        printf "ERROR: cannot access given \`${EVT_E}' evt file\n"
        exit ${ERR_EVT}
    fi
fi
printf "## use evt_eng file: \`${EVT_E}'\n" | ${TOLOG}
# check evt file
if [ -r "${expmap}" ]; then
    EXPMAP=${expmap}
elif [ -r "${DFT_EXPMAP}" ]; then
    EXPMAP=${DFT_EXPMAP}
else
    read -p "expocure map file: " EXPMAP
    if [ ! -r "${EXPMAP}" ]; then
        printf "ERROR: cannot access given \`${EXPMAP}' expmap file\n"
        exit ${ERR_EVT}
    fi
fi
printf "## use expmap file: \`${EXPMAP}'\n" | ${TOLOG}
# check given region file(s)
if [ -r "${reg}" ]; then
    SBP_REG=${reg}
elif [ -r "${DFT_SBP_REG}" ]; then
    SBP_REG=${DFT_SBP_REG}
else
    read -p "> surface brighness radial region file: " SBP_REG
    if [ ! -r "${SBP_REG}" ]; then
        printf "ERROR: cannot access given \`${SBP_REG}' region file\n"
        exit ${ERR_REG}
    fi
fi
printf "## use reg file(s): \`${SBP_REG}'\n" | ${TOLOG}
# check bkg
if [ ! -z "${bkg}" ]; then
    BKG=${bkg}
#else
#    read -p "> bkg: " BKG
fi
if [ -r "${BKG}" ]; then
    printf "## use bkg: \`${BKG}'\n" | ${TOLOG}
else
    BKG="NULL"
fi
# check cell region file
if [ -r "${cellreg}" ]; then
    CELL_REG="${cellreg}"
elif [ -r "${DFT_CELL_REG}" ] ; then
    CELL_REG="${DFT_CELL_REG}"
else
    read -p "> celldetect region file: " CELL_REG
    if [ ! -r "${CELL_REG}" ]; then
        printf "ERROR: cannot access given \`${CELL_REG}' region file \n"
        exit ${ERR_CELL_REG}
    fi
fi
printf "## use cell reg file(s): \`${CELL_REG}'\n" | ${TOLOG}
# check asol file
if [ -r "${aspect}" ]; then
    ASOL_FILE="${aspect}"
elif [ -r "${DFT_ASOL_FILE}" ] ; then
    ASOL_FILE="${DFT_ASOL_FILE}"
else
    read -p ">asol file: " ASOL_FILE
    if [ ! -r "${ASOL_FILE}" ] ; then
        printf " ERROR: cannot access asol file \n"
        exit ${ERR_ASOL}
    fi
fi
printf "## use asol file(s) : \`${ASOL_FILE}'\n" | ${TOLOG}
## parameters }}}

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="dmkeypar dmlist dmextract dmtcalc skyfov"

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
DETNAM=`dmkeypar ${EVT_E} DETNAM echo=yes`
if echo ${DETNAM} | \grep -q 'ACIS-0123'; then
    printf "## \`DETNAM' (${DETNAM}) has chips 0123 -> ACIS-I\n"
    ACIS_TYPE="I"
    CCD="0:3"
elif echo ${DETNAM} | \grep -q 'ACIS-[0-6]*7'; then
    printf "## \`DETNAM' (${DETNAM}) has chip 7 -> ACIS-S\n"
    ACIS_TYPE="S"
    CCD="7"
else
    printf "ERROR: unknown detector type: ${DETNAM}\n"
    exit ${ERR_DET}
fi
## ACIS type }}}

## check validity of pie region {{{
INVALID=`\grep -i 'pie' ${SBP_REG} | awk -F'[,()]' '$7 > 360'`
SBP_REG_FIX="_${SBP_REG%.reg}_fix.reg"
if [ "x${INVALID}" != "x" ]; then
    printf "*** WARNING: some pie regions' END_ANGLE > 360\n" | ${TOLOG}
    printf "*** script will fix ...\n"
    cp -fv ${SBP_REG} ${SBP_REG_FIX}
    # using `awk' to fix
    awk -F'[,()]' '{
        if ($7 > 360) {
            printf "%s(%.2f,%.2f,%.2f,%.2f,%.2f,%.2f)\n", $1,$2,$3,$4,$5,$6,($7-360)
        }
        else {
            print $0
        }
    }' ${SBP_REG} | sed '/^\#/d' > ${SBP_REG_FIX}
else
    cat  ${SBP_REG} | sed '/^\#/d' >${SBP_REG_FIX}
fi
## pie validity }}}

## main process {{{

## generate `skyfov'
SKYFOV="skyfov.fits"
if [ ! -r "${SKYFOV}" ]; then
    printf "generate skyfov ...\n"
    punlearn skyfov
    skyfov infile="${EVT_E}" outfile="${SKYFOV}" aspect="${ASOL_FILE}" clobber=yes
fi

## get CCD fov regions {{{
printf "make regions for CCD ...\n"
TMP_LIST="_tmp_list.txt"
TMP_REC="_tmp_rec.reg"
if [ "${ACIS_TYPE}" = "S" ]; then
    # ACIS-S
    punlearn dmlist
    dmlist infile="${SKYFOV}[ccd_id=${CCD}][cols POS]" opt="data,clean" | awk '{for (i=1;i<=NF;i++) print $i }' |sed -e ':a;N;s/\n/,/;ta' | awk -F"]," '{print "polygon("$2}' | awk -F"NaN" '{print $1}' >${TMP_LIST}
    python ${SCRIPT_DIR}/${CCDGAP_SCRIPT} ${TMP_LIST} >${TMP_REC}
    XC=` cat ${TMP_REC} | awk -F\( '{print $2}' |awk -F\) '{print $1}' |awk -F\, '{print $1}'`
    YC=` cat ${TMP_REC} | awk -F\( '{print $2}' |awk -F\) '{print $1}' |awk -F\, '{print $2}'`
    ADD_L=` cat ${TMP_REC} | awk -F\( '{print $2}' |awk -F\) '{print $1}' |awk -F\, '{print $3/2}'`
    ANG=` cat ${TMP_REC} | awk -F\( '{print $2}' |awk -F\) '{print $1}' |awk -F\, '{print $5}'`
    while [ 1 -eq 1 ]; do
        if [ `echo "${ANG} < 0" |bc -l ` -eq 1 ] ; then
            ANG=` echo " ${ANG} + 90 " | bc -l `
        elif [ `echo "${ANG} >=90" |bc -l ` -eq 1 ] ; then
            ANG=` echo " ${ANG} - 90 " | bc -l`
        else
            break
        fi
    done
    ANG=`echo "${ANG}/180*3.1415926" |bc -l`
    CCD_1_X_RAW=` echo " ${XC}  ${ADD_L} ${ANG} "| awk '{print $1-$2*cos($3)-$2*sin($3)}' `
    CCD_2_X_RAW=` echo " ${XC}  ${ADD_L} ${ANG} "| awk '{print $1+$2*cos($3)-$2*sin($3)}' `
    CCD_3_X_RAW=` echo " ${XC}  ${ADD_L} ${ANG} "| awk '{print $1-$2*cos($3)+$2*sin($3)}' `
    CCD_4_X_RAW=` echo " ${XC}  ${ADD_L} ${ANG} "| awk '{print $1+$2*cos($3)+$2*sin($3)}' `
    CCD_1_Y_RAW=` echo " ${YC}  ${ADD_L} ${ANG} "| awk '{print $1+$2*cos($3)-$2*sin($3)}' `
    CCD_2_Y_RAW=` echo " ${YC}  ${ADD_L} ${ANG} "| awk '{print $1+$2*cos($3)+$2*sin($3)}' `
    CCD_3_Y_RAW=` echo " ${YC}  ${ADD_L} ${ANG} "| awk '{print $1-$2*cos($3)-$2*sin($3)}' `
    CCD_4_Y_RAW=` echo " ${YC}  ${ADD_L} ${ANG} "| awk '{print $1-$2*cos($3)+$2*sin($3)}' `
    CCD_1_RAW=` echo "${CCD_1_X_RAW},${CCD_1_Y_RAW}"`
    CCD_2_RAW=` echo "${CCD_2_X_RAW},${CCD_2_Y_RAW}"`
    CCD_3_RAW=` echo "${CCD_3_X_RAW},${CCD_3_Y_RAW}"`
    CCD_4_RAW=` echo "${CCD_4_X_RAW},${CCD_4_Y_RAW}"`
    REG_CCD_RAW="`echo "polygon(${CCD_1_RAW}, ${CCD_2_RAW}, ${CCD_4_RAW}, ${CCD_3_RAW}) " `"
    DX_2T1=$(echo "`echo ${CCD_2_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_1_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_2T1=$(echo "`echo ${CCD_2_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_1_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_WIDTH=`echo "sqrt(${DX_2T1}*${DX_2T1}+${DY_2T1}*${DY_2T1})" | bc -l`
    CCD_2T1_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_2T1}/${CCD_WIDTH}" | bc -l`
    CCD_2T1_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_2T1}/${CCD_WIDTH}" | bc -l`
    DX_3T1=$(echo "`echo ${CCD_3_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_1_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_3T1=$(echo "`echo ${CCD_3_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_1_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_3T1_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_3T1}/${CCD_WIDTH}" | bc -l`
    CCD_3T1_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_3T1}/${CCD_WIDTH}" | bc -l`
    CCD_1_X=$(echo "` echo ${CCD_1_RAW} |awk -F\, '{print $1}' ` + `echo ${CCD_2T1_MOV_X}` +`echo ${CCD_3T1_MOV_X}` "| bc -l)
    CCD_1_Y=$(echo "` echo ${CCD_1_RAW} |awk -F\, '{print $2}' ` + `echo ${CCD_2T1_MOV_Y}` +`echo ${CCD_3T1_MOV_Y}` "| bc -l)
    DX_1T2=$(echo "`echo ${CCD_1_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_2_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_1T2=$(echo "`echo ${CCD_1_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_2_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_1T2_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_1T2}/${CCD_WIDTH}" | bc -l`
    CCD_1T2_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_1T2}/${CCD_WIDTH}" | bc -l`
    DX_4T2=$(echo "`echo ${CCD_4_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_2_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_4T2=$(echo "`echo ${CCD_4_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_2_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_4T2_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_4T2}/${CCD_WIDTH}" | bc -l`
    CCD_4T2_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_4T2}/${CCD_WIDTH}" | bc -l`
    CCD_2_X=$(echo "` echo ${CCD_2_RAW} |awk -F\, '{print $1}' ` + `echo ${CCD_1T2_MOV_X}` +`echo ${CCD_4T2_MOV_X}` "| bc -l)
    CCD_2_Y=$(echo "` echo ${CCD_2_RAW} |awk -F\, '{print $2}' ` + `echo ${CCD_1T2_MOV_Y}` +`echo ${CCD_4T2_MOV_Y}` "| bc -l)
    DX_1T3=$(echo "`echo ${CCD_1_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_3_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_1T3=$(echo "`echo ${CCD_1_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_3_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_1T3_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_1T3}/${CCD_WIDTH}" | bc -l`
    CCD_1T3_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_1T3}/${CCD_WIDTH}" | bc -l`
    DX_4T3=$(echo "`echo ${CCD_4_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_3_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_4T3=$(echo "`echo ${CCD_4_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_3_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_4T3_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_4T3}/${CCD_WIDTH}" | bc -l`
    CCD_4T3_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_4T3}/${CCD_WIDTH}" | bc -l`
    CCD_3_X=$(echo "` echo ${CCD_3_RAW} |awk -F\, '{print $1}' ` + `echo ${CCD_1T3_MOV_X}` +`echo ${CCD_4T3_MOV_X}` "| bc -l)
    CCD_3_Y=$(echo "` echo ${CCD_3_RAW} |awk -F\, '{print $2}' ` + `echo ${CCD_1T3_MOV_Y}` +`echo ${CCD_4T3_MOV_Y}` "| bc -l)
    DX_2T4=$(echo "`echo ${CCD_2_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_4_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_2T4=$(echo "`echo ${CCD_2_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_4_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_2T4_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_2T4}/${CCD_WIDTH}" | bc -l`
    CCD_2T4_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_2T4}/${CCD_WIDTH}" | bc -l`
    DX_3T4=$(echo "`echo ${CCD_3_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_4_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_3T4=$(echo "`echo ${CCD_3_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_4_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_3T4_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_3T4}/${CCD_WIDTH}" | bc -l`
    CCD_3T4_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_3T4}/${CCD_WIDTH}" | bc -l`
    CCD_4_X=$(echo "` echo ${CCD_4_RAW} |awk -F\, '{print $1}' ` + `echo ${CCD_2T4_MOV_X}` +`echo ${CCD_3T4_MOV_X}` "| bc -l)
    CCD_4_Y=$(echo "` echo ${CCD_4_RAW} |awk -F\, '{print $2}' ` + `echo ${CCD_2T4_MOV_Y}` +`echo ${CCD_3T4_MOV_Y}` "| bc -l)
    REG_CCD_CUT=`echo "polygon(${CCD_1_X},${CCD_1_Y},${CCD_2_X},${CCD_2_Y},${CCD_4_X},${CCD_4_Y},${CCD_3_X},${CCD_3_Y})"`
    REG_FILE_CCD="_ccd.reg"
    [ -e "${REG_FILE_CCD}" ] && mv -f ${REG_FILE_CCD} ${REG_FILE_CCD}_bak
    echo "${REG_CCD_CUT}" >>${REG_FILE_CCD}

elif [ "${ACIS_TYPE}" = "I" ]; then
    # ACIS-I
    TMP_REG_FILE_CCD="_ccd_tmp.reg"
    [ -e "${TMP_REG_FILE_CCD}" ] && mv -f ${TMP_REG_FILE_CCD} ${TMP_REG_FILE_CCD}_bak
    for i in `seq 0 3` ; do
    punlearn dmlist
    dmlist infile="${SKYFOV}[ccd_id=${i}][cols POS]" opt="data,clean" | awk '{for (i=1;i<=NF;i++) print $i }' |sed -e ':a;N;s/\n/,/;ta' | awk -F"]," '{print "polygon("$2}' | awk -F"NaN" '{print $1}' >${TMP_LIST}
    python ${SCRIPT_DIR}/${CCDGAP_SCRIPT} ${TMP_LIST} >${TMP_REC}
    XC=` cat ${TMP_REC} | awk -F\( '{print $2}' |awk -F\) '{print $1}' |awk -F\, '{print $1}'`
    YC=` cat ${TMP_REC} | awk -F\( '{print $2}' |awk -F\) '{print $1}' |awk -F\, '{print $2}'`
    ADD_L=` cat ${TMP_REC} | awk -F\( '{print $2}' |awk -F\) '{print $1}' |awk -F\, '{print $3/2}'`
    ANG=` cat ${TMP_REC} | awk -F\( '{print $2}' |awk -F\) '{print $1}' |awk -F\, '{print $5}'`
    while [ 1 -eq 1 ]; do
        if [ `echo "${ANG} < 0" |bc -l ` -eq 1 ] ; then
            ANG=` echo " ${ANG} + 90 " | bc -l `
        elif [ `echo "${ANG} >=90" |bc -l ` -eq 1 ] ; then
            ANG=` echo " ${ANG} - 90 " | bc -l`
        else
            break
        fi
    done
    ANG=`echo "${ANG}/180*3.1415926" |bc -l`
    CCD_1_X_RAW=` echo " ${XC}  ${ADD_L} ${ANG} "| awk '{print $1-$2*cos($3)-$2*sin($3)}' `
    CCD_2_X_RAW=` echo " ${XC}  ${ADD_L} ${ANG} "| awk '{print $1+$2*cos($3)-$2*sin($3)}' `
    CCD_3_X_RAW=` echo " ${XC}  ${ADD_L} ${ANG} "| awk '{print $1-$2*cos($3)+$2*sin($3)}' `
    CCD_4_X_RAW=` echo " ${XC}  ${ADD_L} ${ANG} "| awk '{print $1+$2*cos($3)+$2*sin($3)}' `
    CCD_1_Y_RAW=` echo " ${YC}  ${ADD_L} ${ANG} "| awk '{print $1+$2*cos($3)-$2*sin($3)}' `
    CCD_2_Y_RAW=` echo " ${YC}  ${ADD_L} ${ANG} "| awk '{print $1+$2*cos($3)+$2*sin($3)}' `
    CCD_3_Y_RAW=` echo " ${YC}  ${ADD_L} ${ANG} "| awk '{print $1-$2*cos($3)-$2*sin($3)}' `
    CCD_4_Y_RAW=` echo " ${YC}  ${ADD_L} ${ANG} "| awk '{print $1-$2*cos($3)+$2*sin($3)}' `
    CCD_1_RAW=` echo "${CCD_1_X_RAW},${CCD_1_Y_RAW}"`
    CCD_2_RAW=` echo "${CCD_2_X_RAW},${CCD_2_Y_RAW}"`
    CCD_3_RAW=` echo "${CCD_3_X_RAW},${CCD_3_Y_RAW}"`
    CCD_4_RAW=` echo "${CCD_4_X_RAW},${CCD_4_Y_RAW}"`
    REG_CCD_RAW=`echo "polygon(${CCD_1_RAW}, ${CCD_2_RAW}, ${CCD_4_RAW}, ${CCD_3_RAW}) " `
    DX_2T1=$(echo "`echo ${CCD_2_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_1_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_2T1=$(echo "`echo ${CCD_2_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_1_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_WIDTH=`echo "sqrt(${DX_2T1}*${DX_2T1}+${DY_2T1}*${DY_2T1})" | bc -l`
    CCD_2T1_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_2T1}/${CCD_WIDTH}" | bc -l`
    CCD_2T1_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_2T1}/${CCD_WIDTH}" | bc -l`
    DX_3T1=$(echo "`echo ${CCD_3_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_1_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_3T1=$(echo "`echo ${CCD_3_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_1_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_3T1_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_3T1}/${CCD_WIDTH}" | bc -l`
    CCD_3T1_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_3T1}/${CCD_WIDTH}" | bc -l`
    CCD_1_X=$(echo "` echo ${CCD_1_RAW} |awk -F\, '{print $1}' ` + `echo ${CCD_2T1_MOV_X}` +`echo ${CCD_3T1_MOV_X}` "| bc -l)
    CCD_1_Y=$(echo "` echo ${CCD_1_RAW} |awk -F\, '{print $2}' ` + `echo ${CCD_2T1_MOV_Y}` +`echo ${CCD_3T1_MOV_Y}` "| bc -l)
    DX_1T2=$(echo "`echo ${CCD_1_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_2_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_1T2=$(echo "`echo ${CCD_1_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_2_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_1T2_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_1T2}/${CCD_WIDTH}" | bc -l`
    CCD_1T2_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_1T2}/${CCD_WIDTH}" | bc -l`
    DX_4T2=$(echo "`echo ${CCD_4_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_2_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_4T2=$(echo "`echo ${CCD_4_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_2_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_4T2_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_4T2}/${CCD_WIDTH}" | bc -l`
    CCD_4T2_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_4T2}/${CCD_WIDTH}" | bc -l`
    CCD_2_X=$(echo "` echo ${CCD_2_RAW} |awk -F\, '{print $1}' ` + `echo ${CCD_1T2_MOV_X}` +`echo ${CCD_4T2_MOV_X}` "| bc -l)
    CCD_2_Y=$(echo "` echo ${CCD_2_RAW} |awk -F\, '{print $2}' ` + `echo ${CCD_1T2_MOV_Y}` +`echo ${CCD_4T2_MOV_Y}` "| bc -l)
    DX_1T3=$(echo "`echo ${CCD_1_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_3_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_1T3=$(echo "`echo ${CCD_1_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_3_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_1T3_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_1T3}/${CCD_WIDTH}" | bc -l`
    CCD_1T3_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_1T3}/${CCD_WIDTH}" | bc -l`
    DX_4T3=$(echo "`echo ${CCD_4_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_3_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_4T3=$(echo "`echo ${CCD_4_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_3_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_4T3_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_4T3}/${CCD_WIDTH}" | bc -l`
    CCD_4T3_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_4T3}/${CCD_WIDTH}" | bc -l`
    CCD_3_X=$(echo "` echo ${CCD_3_RAW} |awk -F\, '{print $1}' ` + `echo ${CCD_1T3_MOV_X}` +`echo ${CCD_4T3_MOV_X}` "| bc -l)
    CCD_3_Y=$(echo "` echo ${CCD_3_RAW} |awk -F\, '{print $2}' ` + `echo ${CCD_1T3_MOV_Y}` +`echo ${CCD_4T3_MOV_Y}` "| bc -l)
    DX_2T4=$(echo "`echo ${CCD_2_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_4_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_2T4=$(echo "`echo ${CCD_2_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_4_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_2T4_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_2T4}/${CCD_WIDTH}" | bc -l`
    CCD_2T4_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_2T4}/${CCD_WIDTH}" | bc -l`
    DX_3T4=$(echo "`echo ${CCD_3_RAW} | awk -F\, '{print $1}'`-`echo  ${CCD_4_RAW} |awk -F\, '{print $1}'`" |bc -l)
    DY_3T4=$(echo "`echo ${CCD_3_RAW} | awk -F\, '{print $2}'`-`echo  ${CCD_4_RAW} |awk -F\, '{print $2}'`" |bc -l)
    CCD_3T4_MOV_X=`echo "${DFT_CCD_EDGECUT}*${DX_3T4}/${CCD_WIDTH}" | bc -l`
    CCD_3T4_MOV_Y=`echo "${DFT_CCD_EDGECUT}*${DY_3T4}/${CCD_WIDTH}" | bc -l`
    CCD_4_X=$(echo "` echo ${CCD_4_RAW} |awk -F\, '{print $1}' ` + `echo ${CCD_2T4_MOV_X}` +`echo ${CCD_3T4_MOV_X}` "| bc -l)
    CCD_4_Y=$(echo "` echo ${CCD_4_RAW} |awk -F\, '{print $2}' ` + `echo ${CCD_2T4_MOV_Y}` +`echo ${CCD_3T4_MOV_Y}` "| bc -l)
    REG_CCD_CUT=`echo "polygon(${CCD_1_X},${CCD_1_Y},${CCD_2_X},${CCD_2_Y},${CCD_4_X},${CCD_4_Y},${CCD_3_X},${CCD_3_Y})"`
    echo ${REG_CCD_CUT} >>${TMP_REG_FILE_CCD}
done
    REG_FILE_CCD="_ccd.reg"
    [ -e "${REG_FILE_CCD}" ] && mv -fv ${REG_FILE_CCD} ${REG_FILE_CCD}_bak
 #   echo "` cat ${TMP_REG_FILE_CCD} | head -n 1 | tail -n 1` + ` cat ${TMP_REG_FILE_CCD} | head -n 2 | tail -n 1` +`cat ${TMP_REG_FILE_CCD} | head -n 3 | tail -n 1`+`cat ${TMP_REG_FILE_CCD} | head -n 4 | tail -n 1 `" >${REG_FILE_CCD}
    cat "${TMP_REG_FILE_CCD}">${REG_FILE_CCD}
else
    #
    printf "*** ERROR ACIS_TYPE ***\n"
    exit 255
fi
## }}}

## cut ccd region edge
echo "${REG_CCD_RAW}" >_ccd_raw.reg

# exit 233

## generate new regions within CCD for dmextract
SBP_REG_INCCD="_${SBP_REG%.reg}_inccd.reg"
[ -e "${SBP_REG_INCCD}" ] && mv -fv ${SBP_REG_INCCD} ${SBP_REG_INCCD}_bak

echo "CMD: cat ${CELL_REG} | \grep \( | sed -e ':a;N;s/\n/-/;ta'"
CELL_REG_USE=`cat ${CELL_REG} | \grep \( | sed -e ':a;N;s/\n/-/;ta'`
# exit 233

if [ "${ACIS_TYPE}" = "S" ]; then
    \grep -iE '^(pie|annulus)' ${SBP_REG_FIX} | sed "s/$/\ \&\ `cat ${REG_FILE_CCD}`/" | sed "s/$/\ \-\ ${CELL_REG_USE}/" > ${SBP_REG_INCCD}
    else
    L=`cat ${SBP_REG_FIX} | wc -l `

    for i in `seq 1 $L` ; do
        echo "`cat ${SBP_REG_FIX} |head -n $i | tail -n 1 ` & `cat ${REG_FILE_CCD} | head -n 1 `- ${CELL_REG_USE} | `cat ${SBP_REG_FIX} |head -n $i | tail -n 1` & `cat ${REG_FILE_CCD} | head -n 2| tail -n 1 `- ${CELL_REG_USE} |`cat ${SBP_REG_FIX} |head -n $i | tail -n 1 ` & `cat ${REG_FILE_CCD} | head -n 3 | tail -n 1 `- ${CELL_REG_USE} |`cat ${SBP_REG_FIX} |head -n $i | tail -n 1 ` & `cat ${REG_FILE_CCD} | tail -n 1 `- ${CELL_REG_USE}  " >>${SBP_REG_INCCD}
    done
fi
# ds9 ${EVT_E} -regions format ciao \
#     -regions system physical \
#     -regions ${SBP_REG_INCCD} \
#     -cmap he -bin factor 4

## `surface brightness profile' related data {{{
## extract sbp
printf "extract surface brightness profile ...\n"
SBP_DAT="${SBP_REG%.reg}.fits"
[ -e "${SBP_DAT}" ] && mv -fv ${SBP_DAT} ${SBP_DAT}_bak
if [ -r "${BKG}" ]; then
    punlearn dmkeypar
    EXPO_EVT=`dmkeypar ${EVT_E} EXPOSURE echo=yes`
    EXPO_BKG=`dmkeypar ${BKG} EXPOSURE echo=yes`
    BKG_NORM=`echo "${EXPO_EVT} ${EXPO_BKG}" | awk '{ printf("%g", $1/$2) }'`
    printf "   == (BKG subtracted; bkgnorm=${BKG_NORM}, energy:${E_RANGE}) ==\n"
    punlearn dmextract
    dmextract infile="${EVT_E}[bin sky=@${SBP_REG_INCCD}]" outfile="${SBP_DAT}" \
        exp="${EXPMAP}" bkg="${BKG}[energy=${E_RANGE}][bin sky=@${SBP_REG_INCCD}]" \
        bkgexp=")exp" bkgnorm=${BKG_NORM} opt=generic clobber=yes
else
    punlearn dmextract
    dmextract infile="${EVT_E}[bin sky=@${SBP_REG_INCCD}]" outfile="${SBP_DAT}" \
        exp="${EXPMAP}" opt=generic clobber=yes
fi

## add `rmid' column
printf "add \`RMID' & \`R_ERR' column ...\n"
SBP_RMID="${SBP_DAT%.fits}_rmid.fits"
[ -e "${SBP_RMID}" ] && mv -fv ${SBP_RMID} ${SBP_RMID}_bak
punlearn dmtcalc
dmtcalc infile="${SBP_DAT}" outfile="${SBP_RMID}" \
    expression="RMID=(R[0]+R[1])/2,R_ERR=(R[1]-R[0])/2" \
    clobber=yes

## output needed sbp data to files
printf "output needed sbp data ...\n"
SBP_TXT="${SBP_DAT%.fits}.txt"
SBP_QDP="${SBP_DAT%.fits}.qdp"
[ -e "${SBP_TXT}" ] && mv -fv ${SBP_TXT} ${SBP_TXT}_bak
[ -e "${SBP_QDP}" ] && mv -fv ${SBP_QDP} ${SBP_QDP}_bak
punlearn dmlist
dmlist infile="${SBP_RMID}[cols RMID,R_ERR,SUR_FLUX,SUR_FLUX_ERR]" \
    outfile="${SBP_TXT}" opt="data,clean"

## QDP for sbp {{{
printf "generate a handy QDP file for sbp ...\n"
cp -fv ${SBP_TXT} ${SBP_QDP}
# change comment sign
sed -i'' 's/#/!/g' ${SBP_QDP}
# add QDP commands
sed -i'' '1 i\
SKIP SINGLE' ${SBP_QDP}
sed -i'' '1 i\
READ SERR 1 2' ${SBP_QDP}
sed -i'' '2 i\
LABEL Y "Surface Flux (photons/cm\\u2\\d/pixel\\u2\\d/s)"' ${SBP_QDP}
sed -i'' '2 i\
LABEL X "Radius (pixel)"' ${SBP_QDP}
sed -i'' '2 i\
LABEL T "Surface Brightness Profile"' ${SBP_QDP}
## QDP }}}

printf "generate sbp fitting needed files ...\n"
SBP_RADIUS="radius_sbp.txt"
SBP_FLUX="flux_sbp.txt"
[ -e "${SBP_RADIUS}" ] && mv -fv ${SBP_RADIUS} ${SBP_RADIUS}_bak
[ -e "${SBP_FLUX}" ] && mv -fv ${SBP_FLUX} ${SBP_FLUX}_bak
punlearn dmlist
dmlist infile="${SBP_RMID}[cols R]" \
    opt="data,clean" | awk '{ print $2 }' > ${SBP_RADIUS}
# change the first line `R[2]' to `0.0'
sed -i'' 's/R.*/0\.0/' ${SBP_RADIUS}
dmlist infile="${SBP_RMID}[cols SUR_FLUX,SUR_FLUX_ERR]" \
    opt="data,clean" > ${SBP_FLUX}
# remove the first comment line
sed -i'' '/#.*/d' ${SBP_FLUX}

## sbp data }}}

## main }}}

exit 0
