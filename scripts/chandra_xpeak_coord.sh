#!/bin/sh
#
###########################################################
## get the coord of the X-ray peak in given evt file     ##
## 1) given `evt_clean' file                             ##
## 2) `aconvolve' and then `dmstat'                      ##
## 3) `dmcoords' convert `sky x, y' to `ra, dec'         ##
##                                                       ##
## NOTES:                                                ##
## support ACIS-I(chip: 0-3) and ACIS-S(chip: 7)         ##
## determine by check `DETNAM' for chip number           ##
## if `DETNAM' has `0123', then `ACIS-I'                 ##
## if `DETNAM' has `7', then `ACIS-S'                    ##
##                                                       ##
## LIweitiaNux <liweitianux@gmail.com>                   ##
## November 8, 2012                                      ##
###########################################################

###########################################################
## ChangeLogs:
## v1.1, 2012/11/08, LIweitiaNux
##   get x-ray peak coord from given region file
###########################################################

## about, used in `usage' {{{
VERSION="v1.1"
UPDATE="2012-11-08"
## about }}}

## error code {{{
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
## error code }}}

## usage, help {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` evt=<evt_cl> asol=<asol> [ reg=<reg> chip=<chip> ]\n"
        printf "\nversion:\n"
        printf "${VERSION}, ${UPDATE}\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
# default `evt clean file'
DFT_EVT="`ls evt*clean.fits *clean*evt*.fits 2> /dev/null | head -n 1`"
# default `asol file'
DFT_ASOL="`ls ../pcadf*_asol1.fits pcadf*_asol1.fits 2> /dev/null | head -n 1`"
# default region file
DFT_REG="`ls sbprofile.reg rspec.reg 2> /dev/null | head -n 1`"
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

## check given parameters
# check evt file
if [ -r "${evt}" ]; then
    EVT=${evt}
elif [ -r "${DFT_EVT}" ]; then
    EVT=${DFT_EVT}
else
    read -p "evt clean file: " EVT
    if ! [ -r "${EVT}" ]; then
        printf "ERROR: cannot access given \`${EVT}' evt file\n"
        exit ${ERR_EVT}
    fi
fi
printf "## use evt file: \`${EVT}'\n"

# asol
if [ ! -z "${asol}" ]; then
    ASOL=${asol}
elif [ -r "${DFT_ASOL}" ]; then
    ASOL=${DFT_ASOL}
else
    read -p "asol file: " ASOL
    if ! [ -r "${ASOL}" ]; then
        printf "ERROR: cannot access given \`${ASOL}' asol file\n"
        exit ${ERR_ASOL}
    fi
fi
printf "## use asol file: \`${ASOL}'\n"

# region file (optional)
if [ ! -z "${reg}" ]; then
    REG=${reg}
else
    REG=${DFT_REG}
fi
printf "## use reg file: \`${REG}'\n"

# determine chip
if [ ! -z "${chip}" ]; then
    CHIP="${chip}"
    printf "## use chip: \`${CHIP}'\n"
else
    # determine chip by ACIS type
    punlearn dmkeypar
    DETNAM=`dmkeypar ${EVT} DETNAM echo=yes`
    if echo ${DETNAM} | grep -q 'ACIS-0123'; then
        printf "## \`DETNAM' (${DETNAM}) has chips 0123\n"
        printf "## ACIS-I\n"
        ACIS_TYPE="ACIS-I"
        CHIP="0:3"
    elif echo ${DETNAM} | grep -q 'ACIS-[0-6]*7'; then
        printf "## \`DETNAM' (${DETNAM}) has chip 7\n"
        printf "## ACIS-S\n"
        ACIS_TYPE="ACIS-S"
        CHIP="7"
    else
        printf "ERROR: unknown detector type: ${DETNAM}\n"
        exit ${ERR_DET}
    fi
fi
## parameters }}}

## main part {{{
# generate `skyfov'
SKYFOV="_skyfov.fits"
printf "generate skyfov: \`${SKYFOV}' ...\n"
punlearn skyfov
skyfov infile="${EVT}" outfile="${SKYFOV}" clobber=yes

# generate image
# energy range: 500-7000 eV
E_RANGE="500:7000"
IMG="img_c`echo ${CHIP} | tr ':' '-'`_e`echo ${E_RANGE} | tr ':' '-'`.fits"
printf "generate image: \`${IMG}' ...\n"
punlearn dmcopy
dmcopy infile="${EVT}[sky=region(${SKYFOV}[ccd_id=${CHIP}])][energy=${E_RANGE}][bin sky=::1]" outfile="${IMG}" clobber=yes

# aconvolve
IMG_ACONV="${IMG%.fits}_aconv.fits"
KERNELSPEC="lib:gaus(2,5,1,10,10)"
METHOD="fft"
printf "\`aconvolve' to smooth img: \`${IMG_ACONV}' ...\n"
printf "## aconvolve: kernelspec=\"${KERNELSPEC}\" method=\"${METHOD}\"\n"
punlearn aconvolve
aconvolve infile="${IMG}" outfile="${IMG_ACONV}" kernelspec="${KERNELSPEC}" method="${METHOD}" clobber=yes

# dmstat
printf "\`dmstat' to analyze the img ...\n"
punlearn dmstat
dmstat infile="${IMG_ACONV}"
MAX_X=`pget dmstat out_max_loc | cut -d',' -f1`
MAX_Y=`pget dmstat out_max_loc | cut -d',' -f2`
# dmcoords to convert (x,y) to (ra,dec)
printf "\`dmcoords' to convert (x,y) to (ra,dec) ...\n"
punlearn dmcoords
dmcoords infile="${EVT}" asolfile="${ASOL}" option=sky x=${MAX_X} y=${MAX_Y}
MAX_RA=`pget dmcoords ra`
MAX_DEC=`pget dmcoords dec`

# output results
PHY_REG="peak_phy.reg"
WCS_REG="peak_wcs.reg"
[ -e "${PHY_REG}" ] && mv -f ${PHY_REG} ${PHY_REG}_bak
[ -e "${WCS_REG}" ] && mv -f ${WCS_REG} ${WCS_REG}_bak
echo "point(${MAX_X},${MAX_Y})" > ${PHY_REG}
echo "point(${MAX_RA},${MAX_DEC})" > ${WCS_REG}

printf "\n"
printf "++++++++++++++++++++++++++++++++++++++++++++\n"
printf "X-ray peak coordinates:\n"
printf "via dmstat:\n"
printf "  (X,Y):      (${MAX_X},${MAX_Y})\n"
printf "  (RA,DEC):   (${MAX_RA},${MAX_DEC})\n"

## region file based {{{
if [ -r "${REG}" ]; then
    MAX_X2=`grep -iE '(pie|annulus)' ${REG} | head -n 1 | tr -d 'a-zA-Z()' | awk -F',' '{ print $1 }'`
    MAX_Y2=`grep -iE '(pie|annulus)' ${REG} | head -n 1 | tr -d 'a-zA-Z()' | awk -F',' '{ print $2 }'`
    punlearn dmcoords
    dmcoords infile="${EVT}" asolfile="${ASOL}" option=sky x=${MAX_X2} y=${MAX_Y2}
    MAX_RA2=`pget dmcoords ra`
    MAX_DEC2=`pget dmcoords dec`
    # calc offset
    OFFSET=`echo "scale=5; sqrt((${MAX_X}-${MAX_X2})^2 + (${MAX_Y}-${MAX_Y2})^2)" | bc -l`

    printf "via region:\n"
    printf "  (X2,Y2):    (${MAX_X2},${MAX_Y2})\n"
    printf "  (RA2,DEC2): (${MAX_RA2},${MAX_DEC2})\n"
    printf "offset (unit pixel):\n"
    printf "  offset:     ${OFFSET}\n"
fi
## region file }}}
printf "++++++++++++++++++++++++++++++++++++++++++++\n"
## main }}}

exit 0

