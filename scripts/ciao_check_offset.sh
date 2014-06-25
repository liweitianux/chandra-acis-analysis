#!/bin/sh
#
export LC_COLLATE=C
###########################################################
## based on `ciao_update_xcentroid.sh'                   ##
## get `xcentroid' from region `sbprofile.reg'           ##
## convert from physical coords to WCS corrds            ##
## calculate offset with chandra pointing coords         ##
##                                                       ##
## Weitian LI <liweitianux@gmail.com>                    ##
## 2014/06/25                                            ##
###########################################################

## about, used in `usage' {{{
VERSION="v1.0"
UPDATE="2014-06-25"
## about }}}

## error code {{{
ERR_USG=1
ERR_DIR=11
ERR_EVT=12
ERR_BKG=13
ERR_REG=14
ERR_INFO=15
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
        printf "    `basename $0` evt=<evt_file> reg=<sbp_reg> basedir=<base_dir>\n"
        printf "\nversion:\n"
        printf "${VERSION}, ${UPDATE}\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
# critical offset values (unit: dd:mm:ss)
OFF_CRIT_S="0:3:0"  # 0deg 3min 0sec
OFF_CRIT_I="0:7:0"  # 0deg 7min 0sec

# default `event file' which used to match `blanksky' files
#DFT_EVT="_NOT_EXIST_"
DFT_EVT="`ls evt2*_clean.fits 2> /dev/null`"
# default dir which contains `asols, asol.lis, ...' files
# DFT_BASEDIR="_NOT_EXIST_"
DFT_BASEDIR=".."
# default `radial region file' to extract surface brightness
#DFT_SBP_REG="_NOT_EXIST_"
DFT_SBP_REG="sbprofile.reg"

## howto find files in `basedir'
# default `asol.lis pattern'
DFT_ASOLIS_PAT="acis*asol?.lis"
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

## unit/format conversion
ddmmss2deg() {
    # convert 'dd:mm:ss' to 'deg'
    echo "$1" | awk -F':' '
    function abs(x) { return ((x<0.0)? (-x) : x) }
    function sign(x) { return ((x<0.0)? (-1.0) : 1.0) }
    {
        value = abs($1) + ($2)/60.0 + ($3)/3600.0;
        printf("%.8f", sign($1)*value);
    }'
}

deg2ddmmss() {
    # convert 'deg' to 'dd:mm:ss'
    echo "$1" | awk '
    function abs(x) { return ((x<0.0)? (-x) : x) }
    {
        deg = $1;
        dd = int(deg);
        mm = int(abs(deg-dd)*60.0);
        ss = (abs(deg-dd)*60.0 - mm)*60.0;
        printf("%d:%d:%.2f", dd, mm, ss);
    }'
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
## check CIAO }}}

## parameters {{{
# process cmdline args using `getopt_keyval'
getopt_keyval "$@"

# check given parameters
# check evt file
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
printf "## use evt file: \`${EVT}'\n" | ${TOLOG}
# check given region file(s)
if [ -r "${reg}" ]; then
    SBP_REG="${reg}"
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
# check given dir
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
printf "## use basedir: \`${BASEDIR}'\n" | ${TOLOG}
## parameters }}}

## main process {{{
# asolis
ASOLIS=`( cd ${BASEDIR} && ls ${DFT_ASOLIS_PAT} 2> /dev/null )`

# get (x,y) from sbp region
printf "get (x,y) from ${SBP_REG}\n"
X=`grep -iE '(pie|annulus)' ${SBP_REG} | head -n 1 | awk -F',' '{ print $1 }' | tr -d 'a-zA-Z() '`
Y=`grep -iE '(pie|annulus)' ${SBP_REG} | head -n 1 | awk -F',' '{ print $2 }' | tr -d 'a-zA-Z() '`

# dmcoords to convert (x,y) to (ra,dec)
printf "\`dmcoords' to convert (x,y) to (ra,dec) ...\n"
punlearn dmcoords
dmcoords infile="${EVT}" asolfile="@${BASEDIR}/${ASOLIS}" option=sky celfmt=deg x=${X} y=${Y}
RA=`pget dmcoords ra`
DEC=`pget dmcoords dec`

# get observation pointing coordinates
punlearn dmkeypar
RA_PNT=`dmkeypar infile="${EVT}" keyword="RA_PNT" echo=yes`
DEC_PNT=`dmkeypar infile="${EVT}" keyword="DEC_PNT" echo=yes`

## determine ACIS type {{{
punlearn dmkeypar
DETNAM=`dmkeypar ${EVT} DETNAM echo=yes`
if echo ${DETNAM} | grep -q 'ACIS-0123'; then
    #printf "## \`DETNAM' (${DETNAM}) has chips 0123\n"
    #printf "## ACIS-I\n"
    ACIS_TYPE="ACIS-I"
elif echo ${DETNAM} | grep -q 'ACIS-[0-6]*7'; then
    #printf "## \`DETNAM' (${DETNAM}) has chip 7\n"
    #printf "## ACIS-S\n"
    ACIS_TYPE="ACIS-S"
else
    printf "ERROR: unknown detector type: ${DETNAM}\n"
    exit ${ERR_DET}
fi
## ACIS type }}}

# calculate offset
OFF_DEG=`echo "${RA} ${RA_PNT} ${DEC} ${DEC_PNT}" | awk '{ printf("%.8f", sqrt(($1-$2)^2 + ($3-$4)^2)) }'`
OFF_DDMMSS=`deg2ddmmss ${OFF_DEG}`

# compare offset with the given critical values
if [ "${ACIS_TYPE}" = "ACIS-S" ]; then
    DEG_OFF_CRIT=`ddmmss2deg ${OFF_CRIT_S}`
else
    DEG_OFF_CRIT=`ddmmss2deg ${OFF_CRIT_I}`
fi
if [ `echo "${OFF_DEG} > ${DEG_OFF_CRIT}" | bc -l` -eq 1 ]; then
    LARGE_OFFSET="YES"
else
    LARGE_OFFSET="NO"
fi

# output results
printf "###################################################\n"
printf "## Detector type: ${ACIS_TYPE}\n"
printf "## Critical offset values: (format: dd:mm:ss)\n"
printf "##   OFF_CRIT_S: ${OFF_CRIT_S}\n"
printf "##   OFF_CRIT_I: ${OFF_CRIT_I}\n"
printf "##\n"
printf "## Our Results:\n"
printf "## Chandra sky coordinates:\n"
printf "##   (x,y):      ($X,$Y)\n"
printf "## WCS coordinates in 'deg' unit:\n"
printf "##   (ra,dec):   (${RA},${DEC})\n"
printf "##\n"
printf "## Observation pointing coordinates:\n"
printf "##   (ra,dec):   (${RA_PNT},${DEC_PNT})\n"
printf "##\n"
printf "## Offset (format: dd:mm:ss):\n"
printf "##   offset:     ${OFF_DDMMSS}\n"
printf "##   offset_deg: ${OFF_DEG}\n"
if [ "${LARGE_OFFSET}" = "YES" ]; then
printf "## *** WARNING: LARGE OFFSET ***\n"
fi
printf "###################################################\n"

## main }}}

exit 0

