#!/bin/sh
#
###########################################################
## get the coord of the X-ray centroid in given evt file ##
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
## Weitian LI <liweitianux@gmail.com>                    ##
## 2012/11/08                                            ##
###########################################################
##
VERSION="v3.1"
UPDATED="2015-11-08"
##
## ChangeLogs:
## v3.1, 2015-11-08, Aaron LI
##   * Use previously generated skyfov instead to make a new one without asol
## v3.0, 2015/06/03, Aaron LI
##   * Copy needed pfiles to current working directory, and
##     set environment variable $PFILES to use these first.
##   * Replace 'grep' with '\grep', 'ls' with '\ls'
##   * Removed section of 'dmstat.par' deletion
## v2.1, 2013/10/12, Weitian LI
##   add support for extract center coordinates from 'point' and 'circle' regs
## v2.0, 2013/01/22, Weitian LI
##   aconvolve switch
##   add iterations for better accuracy
## v1.1, 2012/11/08, Weitian LI
##   get x-ray peak coord from given region file
##

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
        printf "    `basename $0` evt=<evt_cl> reg=<reg> [ asol=<asol> chip=<chip> ] [ conv=yes|No ]\n"
        printf "\nversion:\n"
        printf "${VERSION}, ${UPDATED}\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## check ciao init & solve confilt with heasoft {{{
if [ -z "${ASCDS_INSTALL}" ]; then
    printf "ERROR: CIAO NOT initialized\n"
    exit ${ERR_CIAO}
fi

## XXX: heasoft's `pget' etc. tools conflict with some CIAO tools
printf "set \$PATH to avoid conflicts between HEAsoft and CIAO\n"
export PATH="${ASCDS_BIN}:${ASCDS_CONTRIB}:${PATH}"
printf "## PATH: ${PATH}\n"

## ciao & heasoft }}}

## default parameters {{{
# critical offset (in pixel)
OFFSET_CRIC=10
# energy range: 700-2000 eV
E_RANGE="700:2000"
# default `evt clean file'
DFT_EVT="`\ls evt*clean.fits *clean*evt*.fits 2> /dev/null | head -n 1`"
# default `asol file'
DFT_ASOL="`\ls pcadf*_asol1.fits 2> /dev/null | head -n 1`"
# default region file
DFT_REG="`\ls sbprofile.reg rspec.reg 2> /dev/null | head -n 1`"
# iteration step, ~150 arcsec, ~50 arcsec
R_STP1=300
R_STP2=100
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
    # read -p "asol file: " ASOL
    # if ! [ -r "${ASOL}" ]; then
    #     printf "ERROR: cannot access given \`${ASOL}' asol file\n"
    #     exit ${ERR_ASOL}
    # fi
    ASOL="NO"
    printf "## asol file not supplied !\n"
fi
printf "## use asol file: \`${ASOL}'\n"

# region file (optional)
if [ -r "${reg}" ]; then
    REG=${reg}
elif [ -r "${DFT_REG}" ]; then
    REG=${DFT_REG}
else
    read -p "region file: " REG
    if [ ! -r "${REG}" ]; then
        printf "ERROR: cannot access given \`${REG}' region file\n"
        exit ${ERR_REG}
    fi
fi
printf "## use reg file: \`${REG}'\n"
# get centroid from the regionnn file
CNTRD_X2=`\grep -iE '(point|circle|pie|annulus)' ${REG} | head -n 1 | tr -d 'a-zA-Z()' | awk -F',' '{ print $1 }'`
CNTRD_Y2=`\grep -iE '(point|circle|pie|annulus)' ${REG} | head -n 1 | tr -d 'a-zA-Z()' | awk -F',' '{ print $2 }'`
printf "## center from given regfile: (${CNTRD_X2},${CNTRD_Y2})\n"


# convolve (optional)
if [ -z "${conv}" ]; then
    CONV="NO"
else
    case "${conv}" in
        [yY]*)
            CONV="YES"
            printf "## apply \`aconvolve' !\n"
            ;;
        *)
            CONV="NO"
            ;;
    esac
fi

# determine chip
if [ ! -z "${chip}" ]; then
    CHIP="${chip}"
    printf "## use chip: \`${CHIP}'\n"
else
    # determine chip by ACIS type
    punlearn dmkeypar
    DETNAM=`dmkeypar ${EVT} DETNAM echo=yes`
    if echo ${DETNAM} | \grep -q 'ACIS-0123'; then
        printf "## \`DETNAM' (${DETNAM}) has chips 0123\n"
        printf "## ACIS-I\n"
        ACIS_TYPE="ACIS-I"
        CHIP="0:3"
    elif echo ${DETNAM} | \grep -q 'ACIS-[0-6]*7'; then
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

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="dmkeypar dmcopy dmstat dmcoords aconvolve"

# Copy necessary pfiles for localized usage
for tool in ${CIAO_TOOLS}; do
    pfile=`paccess ${tool}`
    [ -n "${pfile}" ] && punlearn ${tool} && cp -Lvf ${pfile} .
done

# Modify environment variable 'PFILES' to use local pfiles first
export PFILES="./:${PFILES}"
## pfiles }}}

## main part {{{
# Use previously generated `skyfov'
SKYFOV=`\ls *skyfov*.fits 2>/dev/null | head -n 1`

# generate image
IMG="img_c`echo ${CHIP} | tr ':' '-'`_e`echo ${E_RANGE} | tr ':' '-'`.fits"
printf "generate image: \`${IMG}' ...\n"
punlearn dmcopy
dmcopy infile="${EVT}[sky=region(${SKYFOV}[ccd_id=${CHIP}])][energy=${E_RANGE}][bin sky=::1]" outfile="${IMG}" clobber=yes

# aconvolve
if [ "${CONV}" = "YES" ]; then
    IMG_ACONV="${IMG%.fits}_aconv.fits"
    KERNELSPEC="lib:gaus(2,5,1,10,10)"
    METHOD="fft"
    printf "\`aconvolve' to smooth img: \`${IMG_ACONV}' ...\n"
    printf "## aconvolve: kernelspec=\"${KERNELSPEC}\" method=\"${METHOD}\"\n"
    punlearn aconvolve
    aconvolve infile="${IMG}" outfile="${IMG_ACONV}" kernelspec="${KERNELSPEC}" method="${METHOD}" clobber=yes
else
    IMG_ACONV=${IMG}
fi

# tmp analysis region
TMP_REG="_tmp_centroid.reg"
[ -r "${TMP_REG}" ] && rm -f ${TMP_REG}
echo "circle(${CNTRD_X2},${CNTRD_Y2},${R_STP1})" > ${TMP_REG}

# dmstat to find the centroid
printf "\`dmstat' to find the centroid ...\n"
# step1
printf "  region size ${R_STP1}pix: "
for i in `seq 1 5`; do
    printf "#$i ... "
    punlearn dmstat
    dmstat infile="${IMG_ACONV}[sky=region(${TMP_REG})]" centroid=yes verbose=0
    CNTRD_X=`pget dmstat out_cntrd_phys | cut -d',' -f1`
    CNTRD_Y=`pget dmstat out_cntrd_phys | cut -d',' -f2`
    # printf "\n${CNTRD_X},${CNTRD_Y}\n"
    echo "circle(${CNTRD_X},${CNTRD_Y},${R_STP1})" > ${TMP_REG}
done
printf " done\n"
   echo "circle(${CNTRD_X},${CNTRD_Y},${R_STP2})" >${TMP_REG}
# step2
printf "  region size ${R_STP2}pix: "
for i in `seq 1 5`; do
    printf "#$i ... "
    punlearn dmstat
    dmstat infile="${IMG_ACONV}[sky=region(${TMP_REG})]" centroid=yes verbose=0
    CNTRD_X=`pget dmstat out_cntrd_phys | cut -d',' -f1`
    CNTRD_Y=`pget dmstat out_cntrd_phys | cut -d',' -f2`
    # printf "\n${CNTRD_X},${CNTRD_Y}\n"
    echo "circle(${CNTRD_X},${CNTRD_Y},${R_STP2})" > ${TMP_REG}
done
printf " done\n"

# calc offset vs. given
OFFSET=`echo "scale=5; sqrt((${CNTRD_X}-${CNTRD_X2})^2 + (${CNTRD_Y}-${CNTRD_Y2})^2)" | bc -l`

# output
CNTRD_PHY_REG="centroid_phy.reg"
[ -e "${CNTRD_PHY_REG}" ] && mv -f ${CNTRD_PHY_REG} ${CNTRD_PHY_REG}_bak
echo "point(${CNTRD_X},${CNTRD_Y})" > ${CNTRD_PHY_REG}

# dmcoords to convert (x,y) to (ra,dec)
if [ -r "${ASOL}" ]; then
    printf "\`dmcoords' to convert (x,y) to (ra,dec) ...\n"
    punlearn dmcoords
    dmcoords infile="${EVT}" asolfile="${ASOL}" option=sky x=${CNTRD_X} y=${CNTRD_Y}
    CNTRD_RA=`pget dmcoords ra`
    CNTRD_DEC=`pget dmcoords dec`
    CNTRD_WCS_REG="centroid_wcs.reg"
    [ -e "${CNTRD_WCS_REG}" ] && mv -f ${CNTRD_WCS_REG} ${CNTRD_WCS_REG}_bak
    echo "point(${CNTRD_RA},${CNTRD_DEC})" > ${CNTRD_WCS_REG}
    ## from region
    punlearn dmcoords
    dmcoords infile="${EVT}" asolfile="${ASOL}" option=sky x=${CNTRD_X2} y=${CNTRD_Y2}
    CNTRD_RA2=`pget dmcoords ra`
    CNTRD_DEC2=`pget dmcoords dec`
fi

printf "\n"
printf "++++++++++++++++++++++++++++++++++++++++++++\n"
printf "X-ray centroid coordinates:\n"
printf "via dmstat:\n"
printf "  (X,Y):      (${CNTRD_X},${CNTRD_Y})\n"
if [ -r "${ASOL}" ]; then
    printf "  (RA,DEC):   (${CNTRD_RA},${CNTRD_DEC})\n"
fi
printf "via region:\n"
printf "  (X2,Y2):    (${CNTRD_X2},${CNTRD_Y2})\n"
if [ -r "${ASOL}" ]; then
    printf "  (RA2,DEC2): (${CNTRD_RA2},${CNTRD_DEC2})\n"
fi
printf "offset (unit pixel):\n"
printf "  offset:     ${OFFSET}\n"
if [ `echo "${OFFSET} > ${OFFSET_CRIC}" | bc -l` -eq 1 ]; then
    printf "*****************************\n"
    printf "*** WARNING: large offset ***\n"
fi
printf "++++++++++++++++++++++++++++++++++++++++++++\n"
## main }}}

exit 0

