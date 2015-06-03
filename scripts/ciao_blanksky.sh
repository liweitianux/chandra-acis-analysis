#!/bin/sh
#
unalias -a
export LC_COLLATE=C
###########################################################
## process `blanksky' bkg files for spectra analysis     ##
## http://cxc.harvard.edu/ciao/threads/acisbackground/   ##
##                                                       ##
## for extracting the spectrum of the background         ##
## for determining the background components             ##
##                                                       ##
## inputs: `evt2_clean', `asol files'                    ##
## output: `blanksky_c7.fits' for ACIS-S,                ##
##         `blanksky-c0-3.fits' for ACIS-I               ##
##                                                       ##
## Weitian LI                                            ##
## 2011/01/11                                            ##
###########################################################

###########################################################
## ChangeLogs:
## v2: 2012/08/01
##   add ACIS-I support (chips 0-3)
## v3: 2012/08/06, Junhua Gu
##   pass parameters by cmd line param
## v4: 2012/08/13, Weitian LI
##   add `clobber=yes' parameters to CIAO tools
##   improve `commandline arguements'
##   add `default parameters'
## v5.0, 2015/06/02, Aaron LI
##   * Replaced 'ls' with '\ls'
##   * Copy needed pfiles to current working directory, and
##     set environment variable $PFILES to use these first.
##   * Strip the directory of asol files in the 'asol*.lis' file.
##     CIAO-4.6 save the *absolute path* of asol files in 'asol*.lis',
##     which may cause problems if the data directory was moved later.
###########################################################

## about, used in `usage' {{{
VERSION="v4"
UPDATE="2012-08-14"
## about }}}

## usage, help {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` evt=<evt2_clean> basedir=<base_dir> [ outfile=<outfile_name> ]\n"
        printf "\nversion:\n"
        printf "${VERSION}, ${UPDATE}\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
# default `event file' which used to match `blanksky' files
#DFT_EVT="_NOT_EXIST_"
DFT_EVT="`\ls evt2*_clean.fits`"
# default dir which contains `asols, asol.lis, ...' files
# DFT_BASEDIR="_NOT_EXIST_"
DFT_BASEDIR=".."

## howto find files in `basedir'
# default `asol.lis pattern'
DFT_ASOLIS_PAT="acis*asol?.lis"
## default parameters }}}

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
## error code }}}

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

# reprocess blanksky evt with matched gainfile
blank_regain() {
    mv $1 ${1%.fits}_ungain.fits
    punlearn acis_process_events
    acis_process_events infile="${1%.fits}_ungain.fits" \
        outfile="$1" \
        acaofffile=NONE stop="none" doevtgrade=no \
        apply_cti=yes apply_tgain=no \
        calculate_pi=yes pix_adj=NONE \
        gainfile="$2" \
        eventdef="{s:ccd_id,s:node_id,i:expno,s:chip,s:tdet,f:det,f:sky,s:phas,l:pha,l:pha_ro,f:energy,l:pi,s:fltgrade,s:grade,x:status}" \
        clobber=yes
    rm -fv ${1%.fits}_ungain.fits
}
## functions end }}}

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
    read -p "evt2 file: " EVT
    if ! [ -r "${EVT}" ]; then
        printf "ERROR: cannot access given \`${EVT}' evt file\n"
        exit ${ERR_EVT}
    fi
fi
printf "## use evt file: \`${EVT}'\n"
# check given dir
if [ -d "${basedir}" ]; then
    BASEDIR=${basedir}
elif [ -d "${DFT_BASEDIR}" ]; then
    BASEDIR=${DFT_BASEDIR}
else
    read -p "basedir (contains asol files): " BASEDIR
    if [ ! -d ${BASEDIR} ]; then
        printf "ERROR: given \`${BASEDIR}' NOT a directory\n"
        exit ${ERR_DIR}
    fi
fi
# remove the trailing '/'
BASEDIR=`echo ${BASEDIR} | sed 's/\/*$//'`
printf "## use basedir: \`${BASEDIR}'\n"
## parameters }}}

## check files in `basedir' {{{
# check asol files
ASOLIS=`\ls -1 ${BASEDIR}/${DFT_ASOLIS_PAT} | head -n 1`
if [ -z ${ASOLIS} ]; then
    printf "ERROR: cannot find \"${DFT_ASOLIS_PAT}\" in dir \`${BASEDIR}'\n"
    exit ${ERR_ASOL}
fi
printf "## use asolis: \`${ASOLIS}'\n"
## check files }}}

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="acis_bkgrnd_lookup dmmerge dmcopy dmmakepar dmreadpar reproject_events acis_process_events"

# Copy necessary pfiles for localized usage
for tool in ${CIAO_TOOLS}; do
    pfile=`paccess ${tool}`
    [ -n "${pfile}" ] && punlearn ${tool} && cp -Lvf ${pfile} .
done

# Modify environment variable 'PFILES' to use local pfiles first
export PFILES="./:${PFILES}"
## pfiles }}}

#### main start {{{
# Strip the directory of asol files in the 'asol*.lis' file
# CIAO-4.6 save the absolute path of asol files in 'asol*.lis' file,
# which may cause problems if the data directory was moved later.
mv -fv ${ASOLIS} ${ASOLIS}_bak
awk -F'/' '{ print $NF }' ${ASOLIS}_bak > ${ASOLIS}

printf "look up coresponding background file ...\n"
punlearn acis_bkgrnd_lookup
BKG_LKP="`acis_bkgrnd_lookup ${EVT}`"
AS_NUM=`echo ${BKG_LKP} | tr ' ' '\n' | \grep 'acis7sD' | wc -l`
AI_NUM=`echo ${BKG_LKP} | tr ' ' '\n' | \grep 'acis[0123]iD' | wc -l`
## determine detector type: ACIS-S / ACIS-I {{{
if [ ${AS_NUM} -eq 1 ]; then
    printf "## ACIS-S, chip: 7\n"
    BKG_ROOT="blanksky_c7"
    cp -v ${BKG_LKP} ${BKG_ROOT}_orig.fits
elif [ ${AI_NUM} -eq 4 ]; then
    printf "## ACIS-I, chip: 0-3\n"
    BKG_ROOT="blanksky_c0-3"
    AI_FILES=""
    for bf in ${BKG_LKP}; do
        cp -v ${bf} .
        AI_FILES="${AI_FILES},`basename ${bf}`"
    done
    AI_FILES=${AI_FILES#,}      # remove the first ','
    printf "## ACIS-I blanksky files to merge:\n"
    printf "##   \`${AI_FILES}'\n"
    printf "\`dmmerge' to merge the above blanksky files ...\n"
    # merge 4 chips blanksky evt files
    punlearn dmmerge
    dmmerge "${AI_FILES}" ${BKG_ROOT}_orig.fits clobber=yes
    rm -fv `echo ${AI_FILES} | tr ',' ' '`      # remove original files
else
    printf "## ERROR: UNKNOW blanksky files:\n"
    printf "##   ${BKG_ORIG}\n"
    exit ${ERR_BKG}
fi
## determine ACIS type }}}

## check 'DATMODE' {{{
## filter blanksky files (status=0) for `VFAINT' observations
DATA_MODE="`dmkeypar ${EVT} DATAMODE echo=yes`"
printf "## DATAMODE: ${DATA_MODE}\n"
if [ "${DATA_MODE}" = "VFAINT" ]; then
    mv -fv ${BKG_ROOT}_orig.fits ${BKG_ROOT}_tmp.fits
    printf "apply \`status=0' to filter blanksky file ...\n"
    punlearn dmcopy
    dmcopy "${BKG_ROOT}_tmp.fits[status=0]" ${BKG_ROOT}_orig.fits clobber=yes
    rm -fv ${BKG_ROOT}_tmp.fits
fi
## DATAMODE, status=0 }}}

## check `GAINFILE' of blanksky and evt2 file {{{
## if NOT match, then reprocess blanksky
GAINFILE_EVT="`dmkeypar ${EVT} GAINFILE echo=yes`"
GAINFILE_BG="`dmkeypar "${BKG_ROOT}_orig.fits" GAINFILE echo=yes`"
if ! [ "${GAINFILE_EVT}" = "${GAINFILE_BG}" ]; then
    printf "WARNING: GAINFILE NOT match.\n"
    printf "event: ${GAINFILE_EVT}\n"
    printf "blank: ${GAINFILE_BG}\n"
    printf "reprocess blanksky with evt gainfile ...\n"
    # reprocess blanksky using matched evt GAINFILE
    GAINFILE="$CALDB/data/chandra/acis/det_gain/`basename ${GAINFILE_EVT}`"
    printf "GAINFILE: ${GAINFILE}\n"
    blank_regain "${BKG_ROOT}_orig.fits" ${GAINFILE}
fi
## check & match GAINFILE }}}

printf "add the PNT header keywords ... "
EVT_HEADER="_evt_header.par"
EVT_PNT="_evt_pnt.par"
punlearn dmmakepar
dmmakepar ${EVT} ${EVT_HEADER} clobber=yes
\grep -i '_pnt' ${EVT_HEADER} > ${EVT_PNT}
punlearn dmreadpar
dmreadpar ${EVT_PNT} "${BKG_ROOT}_orig.fits[EVENTS]" clobber=yes
printf "DONE\n"

printf "reproject the background ...\n"
punlearn reproject_events
reproject_events infile=${BKG_ROOT}_orig.fits \
    outfile=${BKG_ROOT}.fits match=${EVT} \
    aspect="@${ASOLIS}" random=0 clobber=yes

# rename output file if specified
if ! [ -z "${outfile}" ]; then
    mv -fv ${BKG_ROOT}.fits ${outfile}
fi
## main end }}}

# clean
printf "\nclean ...\n"
rm -fv ${BKG_ROOT}_orig.fits ${EVT_PNT}

printf "\nFINISHED\n"

# vim: set ts=8 sw=4 tw=0 fenc=utf-8 ft=sh #
