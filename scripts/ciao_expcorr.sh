#!/bin/sh
#
unalias -a
export LC_COLLATE=C
###########################################################
## make `image' from `evt file'                          ##
## make `spectral weight' using `make_instmap_weights'   ##
## use `fluximage' to generating `exposure map'          ##
## make `exposure-corrected' image                       ##
## and extract `surface brighness profile'               ##
##                                                       ##
## NOTES:                                                ##
## only ACIS-I (chip: 0-3) and ACIS-S (chip: 7) supported##
## `merge_all' conflict with Heasoft's `pget' etc. tools ##
##                                                       ##
## LIweitiaNux <liweitianux@gmail.com>                   ##
## August 16, 2012                                       ##
###########################################################

###########################################################
## ChangeLogs:
## v2.0, 2014/07/29, Weitian LI
##   `merge_all' deprecated, use `fluximage' if possible
## v1.2, 2012-08-21, LIweitiaNux
##   set `ardlib' before process `merge_all'
## v1.1, 2012-08-21, LIweitiaNux
##   fix a bug with `sed'
###########################################################

## about, used in `usage' {{{
VERSION="v2.0"
UPDATE="2014-07-29"
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
ERR_ENG=42
ERR_CIAO=100
## error code }}}

## usage, help {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` evt=<evt_file> energy=<e_start:e_end:e_width> basedir=<base_dir> nh=<nH> z=<redshift> temp=<avg_temperature> abund=<avg_abund> [ logfile=<log_file> ]\n"
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
DFT_SBP_REG="_NOT_EXIST_"
#DFT_SBP_REG="sbprofile.reg"
# default `energy band' applying to `images' analysis
# format: `E_START:E_END:E_WIDTH'
DFT_ENERGY="700:7000:100"

# default `log file'
DFT_LOGFILE="expcorr_sbp_`date '+%Y%m%d'`.log"

## howto find files in `basedir'
# default `asol.lis pattern'
DFT_ASOLIS_PAT="acis*asol?.lis"
# default `bad pixel filename pattern'
DFT_BPIX_PAT="acis*repro*bpix?.fits"
# default `msk file pattern'
DFT_MSK_PAT="acis*msk?.fits"
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
fi
printf "## use reg file(s): \`${SBP_REG}'\n" | ${TOLOG}
## check given `energy' {{{
if [ ! -z "${energy}" ]; then
    ENERGY="${energy}"
else
    ENERGY="${DFT_ENERGY}"
fi
# split energy variable
ENG_N=`echo ${ENERGY} | awk -F':' '{ print NF }'`
if [ ${ENG_N} -eq 1 ]; then
    E_START=`echo ${DFT_ENERGY} | awk -F':' '{ print $1 }'`
    E_END=`echo ${DFT_ENERGY} | awk -F':' '{ print $2 }'`
    E_WIDTH=${ENERGY}
elif [ ${ENG_N} -eq 2 ]; then
    E_START=`echo ${ENERGY} | awk -F':' '{ print $1 }'`
    E_END=`echo ${ENERGY} | awk -F':' '{ print $2 }'`
    E_WIDTH=`echo ${DFT_ENERGY} | awk -F':' '{ print $3 }'`
elif [ ${ENG_N} -eq 3 ]; then
    E_START=`echo ${ENERGY} | awk -F':' '{ print $1 }'`
    E_END=`echo ${ENERGY} | awk -F':' '{ print $2 }'`
    E_WIDTH=`echo ${ENERGY} | awk -F':' '{ print $3 }'`
else
    printf "ERROR: invalid energy: \`${ENERGY}'\n"
    exit ${ERR_ENG}
fi
ENG_RANGE="${E_START}:${E_END}"
printf "## use energy range: \`${ENG_RANGE}' eV\n" | ${TOLOG}
printf "## use energy width: \`${E_WIDTH}' eV\n" | ${TOLOG}
## parse energy }}}
# parameters (nH, z, avg_temp, avg_abund) used to calculate {{{
# `spectral weights' for `mkinstmap'
# check given nH
if [ -z "${nh}" ]; then
    read -p "> value of nH: " N_H
else
    N_H=${nh}
fi
printf "## use nH: ${N_H}\n" | ${TOLOG}
# check given redshift
if [ -z "${z}" ]; then
    read -p "> value of redshift: " REDSHIFT
else
    REDSHIFT=${z}
fi
printf "## use redshift: ${REDSHIFT}\n" | ${TOLOG}
# check given temperature
if [ -z "${temp}" ]; then
    read -p "> object average temperature: " TEMP
else
    TEMP=${temp}
fi
printf "## use temperature: ${TEMP}\n" | ${TOLOG}
# check given abundance
if [ -z "${abund}" ]; then
    read -p "> object average abundance: " ABUND
else
    ABUND=${abund}
fi
printf "## use abundance: ${ABUND}\n" | ${TOLOG}
# `spectral weights' parameters }}}
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

## check files in `basedir' {{{
# check asol files
ASOLIS=`ls -1 ${BASEDIR}/${DFT_ASOLIS_PAT} | head -n 1`
if [ -z "${ASOLIS}" ]; then
    printf "ERROR: cannot find \"${DFT_ASOLIS_PAT}\" in dir \`${BASEDIR}'\n"
    exit ${ERR_ASOL}
fi
printf "## use asolis: \`${ASOLIS}'\n"
# check badpixel file
BPIX=`ls -1 ${BASEDIR}/${DFT_BPIX_PAT} | head -n 1`
if [ -z "${BPIX}" ]; then
    printf "ERROR: cannot find \"${DFT_BPIX_PAT}\" in dir \`${BASEDIR}'\n"
    exit ${ERR_BPIX}
fi
printf "## use badpixel: \`${BPIX}'\n" | ${TOLOG}
# check msk file
MSK=`ls -1 ${BASEDIR}/${DFT_MSK_PAT} | head -n 1`
if [ -z "${MSK}" ]; then
    printf "ERROR: cannot find \"${DFT_MSK_PAT}\" in dir \`${BASEDIR}'\n"
    exit ${ERR_MSK}
fi
printf "## use msk file: \`${MSK}'\n" | ${TOLOG}
## check files }}}

## determine ACIS type {{{
# consistent with `ciao_procevt'
punlearn dmkeypar
DETNAM=`dmkeypar ${EVT} DETNAM echo=yes`
if echo ${DETNAM} | grep -q 'ACIS-0123'; then
    printf "## \`DETNAM' (${DETNAM}) has chips 0123\n"
    printf "## ACIS-I\n"
    ACIS_TYPE="ACIS-I"
    CCD="0:3"
    NEW_DETNAM="ACIS-0123"
    ROOTNAME="c0-3_e${E_START}-${E_END}"
elif echo ${DETNAM} | grep -q 'ACIS-[0-6]*7'; then
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


## main process {{{
## set `ardlib' at first
printf "set \`ardlib' first ...\n"
punlearn ardlib
acis_set_ardlib badpixfile="${BPIX}"

## generate `spectral weights' for `instrumental map' {{{
printf "generate \`spectral weights' for making instrumental map ...\n"
SPEC_WGT="instmap_weights.txt"
# convert `eV' to `keV'
EMIN=`echo ${E_START} | awk '{ print $1/1000 }'`
EMAX=`echo ${E_END} | awk '{ print $1/1000 }'`
EWIDTH=`echo ${E_WIDTH} | awk '{ print $1/1000 }'`
punlearn make_instmap_weights
make_instmap_weights outfile="${SPEC_WGT}" \
    model="xswabs.gal*xsapec.ap" \
    paramvals="gal.nh=${N_H};ap.kt=${TEMP};ap.abundanc=${ABUND};ap.redshift=${REDSHIFT}" \
    emin="${EMIN}" emax="${EMAX}" ewidth="${EWIDTH}" \
    abund="grsa" clobber=yes
## spectral weights }}}

## generate `skyfov'
# XXX: omit `aspec', NOT provide `asol' file
# otherwise the size of evt_img NOT match the `expmap'
printf "generate skyfov ...\n"
SKYFOV="_skyfov.fits"
[ -e "${SKYFOV}" ] && rm -fv ${SKYFOV}
punlearn skyfov
skyfov infile="${EVT}" outfile="${SKYFOV}" aspect="@${ASOLIS}" clobber=yes

## filter by energy band & make image
printf "filter out events in energy band: \`${ENG_RANGE}' ...\n"
EVT_E="evt2_${ROOTNAME}.fits"
if [ ! -r "${EVT_E}" ]; then
    punlearn dmcopy
    dmcopy infile="${EVT}[energy=${E_START}:${E_END}]" outfile="${EVT_E}" clobber=yes
fi

printf "make image ...\n"
IMG_ORIG="img_${ROOTNAME}.fits"
punlearn dmcopy
dmcopy infile="${EVT_E}[sky=region(${SKYFOV}[ccd_id=${CCD}])][bin sky=1]" \
    outfile="${IMG_ORIG}" clobber=yes

## modify `DETNAM' of image
printf "modify keyword \`DETNAM' of image -> \`${NEW_DETNAM}'\n"
punlearn dmhedit
dmhedit infile="${IMG_ORIG}" filelist=none operation=add \
    key=DETNAM value="${NEW_DETNAM}"

## get `xygrid' for image
punlearn get_sky_limits
get_sky_limits image="${IMG_ORIG}"
XYGRID=`pget get_sky_limits xygrid`
printf "## get \`xygrid': \`${XYGRID}'\n" | ${TOLOG}

EXPMAP="expmap_${ROOTNAME}.fits"
IMG_EXPCORR="img_expcorr_${ROOTNAME}.fits"

if `which merge_all >/dev/null 2>&1`; then
    # merge_all available
    printf "merge_all ...\n"
    ## set `ardlib' again to make sure the matched bpix file specified
    printf "set \`ardlib' again for \`merge_all' ...\n"
    punlearn ardlib
    acis_set_ardlib badpixfile="${BPIX}"
    
    ## XXX: `merge_all' needs `asol files' in working directory
    printf "link asol files into currect dir (\`merge_all' needed) ...\n"
    for f in `cat ${ASOLIS}`; do
        ln -sv ${BASEDIR}/${f} .
    done
    
    printf "use \`merge_all' to generate \`exposure map' ONLY ...\n"
    punlearn merge_all
    merge_all evtfile="${EVT_E}" asol="@${ASOLIS}" \
        chip="${CCD}" xygrid="${XYGRID}" \
        energy="${SPEC_WGT}" expmap="${EXPMAP}" \
        dtffile="" refcoord="" merged="" expcorr="" \
        clobber=yes
    
    ## apply exposure correction
    printf "use \`dmimgcalc' to apply \`exposure correction' ...\n"
    punlearn dmimgcalc
    dmimgcalc infile="${IMG_ORIG}" infile2="${EXPMAP}" \
        outfile="${IMG_EXPCORR}" operation=div clobber=yes
else
    ## `merge_all' deprecated and not available
    ## use 'fluximage' to generate `exposure map' and apply exposure correction
    printf "fluximage ...\n"
    punlearn fluximage
    fluximage infile="${EVT_E}" outroot="${ROOTNAME}" \
        binsize=1 bands="${SPEC_WGT}" xygrid="${XYGRID}" \
        asol="@${ASOLIS}" badpixfile="${BPIX}" \
        maskfile="${MSK}" clobber=yes
    ## make symbolic links
    # clipped counts image
    ln -svf ${ROOTNAME}*band*thresh.img ${IMG_ORIG%.fits}_thresh.fits
    # clipped exposure map
    ln -svf ${ROOTNAME}*band*thresh.expmap ${EXPMAP}
    # exposure-corrected image
    ln -svf ${ROOTNAME}*band*flux.img ${IMG_EXPCORR}
fi

## main }}}

exit 0

