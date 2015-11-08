#!/bin/sh
#
unalias -a
export LC_COLLATE=C
##
## Take the `X-ray centroid' coordinate from region `sbprofile.reg'
## as the start location, then search for X-ray peak in a circle region
## of radius ${SEARCH_RADIUS} pixels centered on the X-ray centroid.
## After that the found X-ray peak is convert from physical coordinate to
## WCS coordinate and added/updated to the INFO json file.
##
## Note: The image on which the X-ray peak is to be searched is generated
## as following:
##     (1) original event file (c7, c0-3)
##     (2) filter flares (deflare)
##     (3) filter energy (${E_RANGE})
##     (4) smooth with aconvolve
##
## Based on `chandra_update_xcentroid.sh'
##
## Weitian LI <liweitianux@gmail.com>
## Created: 2015-11-08
##
VERSION="v1.0"
UPDATED="2015-11-08"
##
## ChangeLogs:
##

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
        printf "    `basename $0` evt=<evt_file> reg=<sbp_reg> basedir=<base_dir> info=<INFO.json> conv=<yes|NO> update=<YES|no>\n"
        printf "\nversion:\n"
        printf "${VERSION}, ${UPDATED}\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
# critical offset (in pixel)
OFFSET_CRIC=20
# energy range: 700-2000 eV
E_RANGE="700:2000"
# default `event file' which used to match `blanksky' files
DFT_EVT="`\ls evt2*_clean.fits 2> /dev/null`"
# default dir which contains `asols, asol.lis, ...' files
DFT_BASEDIR=".."
# default `radial region file' to extract surface brightness
DFT_SBP_REG="`\ls sbprofile.reg rspec.reg 2> /dev/null | head -n 1`"

## howto find files in `basedir'
# default `asol.lis pattern'
DFT_ASOLIS_PAT="acis*asol?.lis"
# default INFO.json pattern
DFT_INFO_PAT="*_INFO.json"

# default circle radius within which to search the X-ray peak
SEARCH_RADIUS=100
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
elif [ "`\ls ${BASEDIR}/${DFT_INFO_PAT} | wc -l`" -eq 1 ]; then
    INFO_JSON=`( cd ${BASEDIR} && \ls ${DFT_INFO_PAT} )`
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
## parameters }}}

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="dmcopy dmstat aconvolve dmcoords"

# Copy necessary pfiles for localized usage
for tool in ${CIAO_TOOLS}; do
    pfile=`paccess ${tool}`
    [ -n "${pfile}" ] && punlearn ${tool} && cp -Lvf ${pfile} .
done

# Modify environment variable 'PFILES' to use local pfiles first
export PFILES="./:${PFILES}"
## pfiles }}}

## main process {{{
CUR_DIR=`pwd -P`

# Generate the defalred event file (without filtering out the point sources)
EVT_DIR=$(dirname $(readlink ${EVT}))
cd ${EVT_DIR}
EVT_ORIG="`\ls evt*_orig.fits`"
GTI="`\ls *.gti`"
printf "make a deflared evt (without filtering out point sources) ...\n"
EVT_DEFLARE="${EVT_ORIG%_orig.fits}_deflare.fits"
punlearn dmcopy
dmcopy infile="${EVT_ORIG}[@${GTI}]" outfile="${EVT_DEFLARE}" clobber=yes

cd ${CUR_DIR}
ln -svf ${EVT_DIR}/${EVT_DEFLARE} .

# Use previously generated `skyfov'
SKYFOV=`\ls *skyfov*.fits 2>/dev/null | head -n 1`

# Extract chip(s) from evt filename
CHIP=`echo "${EVT}" | sed 's/^.*_c\(7\|0-3\)_.*$/\1/' | tr '-' ':'`

# generate image
IMG="img_c`echo ${CHIP} | tr ':' '-'`_e`echo ${E_RANGE} | tr ':' '-'`_deflare.fits"
printf "generate image: \`${IMG}' ...\n"
punlearn dmcopy
dmcopy infile="${EVT_DEFLARE}[sky=region(${SKYFOV}[ccd_id=${CHIP}])][energy=${E_RANGE}][bin sky=::1]" outfile="${IMG}" clobber=yes

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

# Get X-ray centroid coordinate from sbp region
printf "get (x,y) from ${SBP_REG}\n"
CNTRD_X=`\grep -iE '(pie|annulus)' ${SBP_REG} | head -n 1 | awk -F',' '{ print $1 }' | tr -d 'a-zA-Z() '`
CNTRD_Y=`\grep -iE '(pie|annulus)' ${SBP_REG} | head -n 1 | awk -F',' '{ print $2 }' | tr -d 'a-zA-Z() '`

SEARCH_REGION="circle(${CNTRD_X},${CNTRD_Y},${SEARCH_RADIUS})"
# dmstat to find the maximum location
printf "\`dmstat' to find the peak ...\n"
punlearn dmstat
dmstat infile="${IMG_ACONV}[sky=${SEARCH_REGION}]" verbose=0
PEAK_X=`pget dmstat out_max_loc | cut -d',' -f1`
PEAK_Y=`pget dmstat out_max_loc | cut -d',' -f2`

# asolis
ASOLIS=`( cd ${BASEDIR} && \ls ${DFT_ASOLIS_PAT} 2> /dev/null )`

# Use "dmcoords" to convert (x,y) to (ra,dec)
printf "\`dmcoords' to convert (x,y) to (ra,dec) ...\n"
punlearn dmcoords
dmcoords infile="${EVT}" asolfile="@${BASEDIR}/${ASOLIS}" option=sky x=${PEAK_X} y=${PEAK_Y}
PEAK_RA=`pget dmcoords ra`
PEAK_DEC=`pget dmcoords dec`

# Calculate the offset between peak and centroid coordinate
OFFSET=`echo "scale=5; sqrt((${PEAK_X}-${CNTRD_X})^2 + (${PEAK_Y}-${CNTRD_Y})^2)" | bc -l`

printf "## X-ray centroid (x,y): (${CNTRD_X},${CNTRD_Y})\n"
printf "## X-ray peak (x,y): (${PEAK_X},${PEAK_Y})\n"
printf "## X-ray peak (ra,dec): (${PEAK_RA},${PEAK_DEC})\n"
printf "## Offset (pixel): ${OFFSET}\n"
if [ `echo "${OFFSET} > ${OFFSET_CRIC}" | bc -l` -eq 1 ]; then
    printf "*** WARNING: large offset (> ${OFFSET_CRIC}) ***\n"
fi

# Output X-ray peak coordinate to a region file
PEAK_PHY_REG="peak_phy.reg"
[ -e "${PEAK_PHY_REG}" ] && mv -f ${PEAK_PHY_REG} ${PEAK_PHY_REG}_bak
echo "point(${PEAK_X},${PEAK_Y})" > ${PEAK_PHY_REG}
PEAK_WCS_REG="peak_wcs.reg"
[ -e "${PEAK_WCS_REG}" ] && mv -f ${PEAK_WCS_REG} ${PEAK_WCS_REG}_bak
echo "point(${PEAK_RA},${PEAK_DEC})" > ${PEAK_WCS_REG}

if [ "${F_UPDATE}" = "YES" ]; then
    cp -f ${INFO_JSON} ${INFO_JSON}_bak
    printf "update/add X-ray peak coordinate to info.json ...\n"
    if \grep -qE 'XPEAK_(RA|DEC)' ${INFO_JSON}; then
        printf "update ...\n"
        sed -i'' "s/XPEAK_RA.*$/XPEAK_RA\":\ \"${PEAK_RA}\",/" ${INFO_JSON}
        sed -i'' "s/XPEAK_DEC.*$/XPEAK_DEC\":\ \"${PEAK_DEC}\",/" ${INFO_JSON}
        sed -i'' "s/XPEAK_XCNTRD_dist.*$/XPEAK_XCNTRD_dist\ (pix)\":\ \"${OFFSET}\",/" ${INFO_JSON}
    else
        printf "add ...\n"
        sed -i'' "/\"Dec\.\"/ a\
\ \ \ \ \"XPEAK_XCNTRD_dist\ (pix)\": \"${OFFSET}\"," ${INFO_JSON}
        sed -i'' "/\"Dec\.\"/ a\
\ \ \ \ \"XPEAK_DEC\": \"${PEAK_DEC}\"," ${INFO_JSON}
        sed -i'' "/\"Dec\.\"/ a\
\ \ \ \ \"XPEAK_RA\": \"${PEAK_RA}\"," ${INFO_JSON}
    fi
fi
## main }}}

exit 0

