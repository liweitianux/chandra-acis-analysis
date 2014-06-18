#!/bin/sh
#
unalias -a
export LC_COLLATE=C
###########################################################
## based on `ciao_expcorr_sbp.sh'                        ##
## get `xcentroid' from region `sbprofile.reg'           ##
## convert from physical coords to WCS corrds            ##
## add/update xcentroid WCS to info.json                 ##
##                                                       ##
## LIweitiaNux <liweitianux@gmail.com>                   ##
## 2013/05/29                                            ##
###########################################################

###########################################################
## ChangeLogs:
## v1.0, 2013/05/29, LIweitiaNux
###########################################################

## about, used in `usage' {{{
VERSION="v1.0"
UPDATE="2013-05-29"
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
        printf "    `basename $0` evt=<evt_file> reg=<sbp_reg> basedir=<base_dir> info=<INFO.json> update=<yes|no>\n"
        printf "\nversion:\n"
        printf "${VERSION}, ${UPDATE}\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
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
# default INFO.json pattern
DFT_INFO_PAT="*_INFO.json"
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
# check INFO.json file
if [ ! -z "${info}" ] && [ -r "${BASEDIR}/${info}" ]; then
    INFO_JSON="${info}"
elif [ "`ls ${BASEDIR}/${DFT_INFO_PAT} | wc -l`" -eq 1 ]; then
    INFO_JSON=`( cd ${BASEDIR} && ls ${DFT_INFO_PAT} )`
else
    read -p "> info json file: " INFO_JSON
    if ! [ -r "${BASEDIR}/${INFO_JSON}" ]; then
        printf "ERROR: cannot access given \`${BASEDIR}/${INFO_JSON}' file\n"
        exit ${ERR_INFO}
    fi
fi
INFO_JSON=`readlink -f ${BASEDIR}/${INFO_JSON}`
printf "## use info json file: \`${INFO_JSON}'\n"
# update flag: whether to update xcentroid in the info.json file
if [ ! -z "${update}" ]; then
    case "${update}" in
        [nN][oO]|[fF]*)
            F_UPDATE="NO"
            ;;
        *)
            F_UPDATE="YES"
            ;;
    esac
else
    F_UPDATE="YES"
fi
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
dmcoords infile="${EVT}" asolfile="@${BASEDIR}/${ASOLIS}" option=sky x=${X} y=${Y}
RA=`pget dmcoords ra`
DEC=`pget dmcoords dec`

printf "## (x,y): ($X,$Y)\n"
printf "## (ra,dec): ($RA,$DEC)\n"

if [ "${F_UPDATE}" = "YES" ]; then
    cp -f ${INFO_JSON} ${INFO_JSON}_bak
    printf "update xcentroid for info.json ...\n"
    if grep -qE 'XCNTRD_(RA|DEC)' ${INFO_JSON}; then
        printf "update ...\n"
        sed -i'' "s/XCNTRD_RA.*$/XCNTRD_RA\":\ \"${RA}\",/" ${INFO_JSON}
        sed -i'' "s/XCNTRD_DEC.*$/XCNTRD_DEC\":\ \"${DEC}\",/" ${INFO_JSON}
    else
        printf "add ...\n"
        sed -i'' "/\"Dec\.\"/ a\
\ \ \ \ \"XCNTRD_DEC\": \"${DEC}\"," ${INFO_JSON}
        sed -i'' "/\"Dec\.\"/ a\
\ \ \ \ \"XCNTRD_RA\": \"${RA}\"," ${INFO_JSON}
    fi
fi
## main }}}

exit 0

