#!/bin/sh -
#
trap date INT
unalias -a
export GREP_OPTIONS=""
export LC_COLLATE=C
###########################################################
## extract background spectra from src and blanksky      ##
## renormalization the blank spectrum                    ##
##                                                       ##
## Ref: Chandra spectrum analysis                        ##
## http://cxc.harvard.edu/ciao/threads/extended/         ##
## Ref: specextract                                      ##
## http://cxc.harvard.edu/ciao/ahelp/specextract.html    ##
## Ref: CIAO v4.4 region bugs                            ##
## http://cxc.harvard.edu/ciao/bugs/regions.html#bug-12187
##                                                       ##
## LIweitiaNux, July 24, 2012                            ##
###########################################################

###########################################################
# ChangeLogs:
# v3, 2012/08/09
#   fix `scientific notation' for `bc'
#   change `spec group' method to `min 15'
# v4, 2012/08/13
#   add `clobber=yes'
#   improve error code
#   improve cmdline arguements
#   provide a flexible way to pass parameters
#     (through cmdline which similar to CIAO,
#     and default filename match patterns)
#   add simple `logging' function
###########################################################

## about, used in `usage' {{{
VERSION="v4"
UPDATE="2012-08-14"
## about }}}

## usage, help {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` evt=<evt2_clean> reg=<reglist> blank=<blanksky_evt> basedir=<base_dir> nh=<nH> z=<redshift> [ grpcmd=<grppha_cmd> log=<log_file> ]\n"
        printf "\nversion:\n"
        printf "${VERSION}, ${UPDATE}\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
# default `event file' which used to match `blanksky' files
#DFT_EVT="_NOT_EXIST_"
DFT_EVT="`ls evt2*_clean.fits`"
# default `blanksky file'
#DFT_BLANK="_NOT_EXIST_"
DFT_BLANK="`ls blanksky*.fits`"
# default dir which contains `asols, asol.lis, ...' files
#DFT_BASEDIR="_NOT_EXIST_"
DFT_BASEDIR=".."
# default `group command' for `grppha'
#DFT_GRP_CMD="group 1 128 2 129 256 4 257 512 8 513 1024 16"
DFT_GRP_CMD="group min 20"
# default `log file'
DFT_LOGFILE="bkg_spectra_`date '+%Y%m%d'`.log"

## howto find files in `basedir'
# default `asol.lis pattern'
DFT_ASOLIS_PAT="acis*asol?.lis"
# default `bad pixel filename pattern'
DFT_BPIX_PAT="acis*repro*bpix?.fits"
# default `pbk file pattern'
DFT_PBK_PAT="acis*pbk?.fits"
# default `msk file pattern'
DFT_MSK_PAT="acis*msk?.fits"
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

## background renormalization (BACKSCAL) {{{
# renorm background according to particle background
# energy range: 9.5-12.0 keV (channel: 651-822)
CH_LOW=651
CH_HI=822
pb_flux() {
    punlearn dmstat
    COUNTS=`dmstat "$1[channel=${CH_LOW}:${CH_HI}][cols COUNTS]" | grep -i 'sum:' | awk '{ print $2 }'`
    punlearn dmkeypar
    EXPTIME=`dmkeypar $1 EXPOSURE echo=yes`
    BACK=`dmkeypar $1 BACKSCAL echo=yes`
    # fix `scientific notation' bug for `bc'
    EXPTIME_B=`echo ${EXPTIME} | sed 's/[eE]/\*10\^/' | sed 's/+//'`
    BACK_B=`echo "( ${BACK} )" | sed 's/[eE]/\*10\^/' | sed 's/+//'`
    PB_FLUX=`echo "scale = 16; ${COUNTS} / ${EXPTIME_B} / ${BACK_B}" | bc -l`
    echo ${PB_FLUX}
}

bkg_renorm() {
    # $1: src spectrum, $2: back spectrum
    PBFLUX_SRC=`pb_flux $1`
    PBFLUX_BKG=`pb_flux $2`
    BACK_OLD=`dmkeypar $2 BACKSCAL echo=yes`
    BACK_OLD_B=`echo "( ${BACK_OLD} )" | sed 's/[eE]/\*10\^/' | sed 's/+//'`
    BACK_NEW=`echo "scale = 16; ${BACK_OLD_B} * ${PBFLUX_BKG} / ${PBFLUX_SRC}" | bc -l`
    printf "\`$2': BACKSCAL:\n"
    printf "    ${BACK_OLD} --> ${BACK_NEW}\n"
    punlearn dmhedit
    dmhedit infile=$2 filelist=none operation=add \
        key=BACKSCAL value=${BACK_NEW} comment="old value: ${BACK_OLD}"
}
## bkg renorm }}}
## functions end }}}

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
if [ -z "${reg}" ]; then
    read -p "> selected local bkg region file: " REGLIST
else
    REGLIST="${reg}"
fi
REGLIST=`echo ${REGLIST} | tr ',' ' '`      # use *space* to separate
printf "## use reg file(s): \`${REGLIST}'\n" | ${TOLOG}
# check given blanksky
if [ -r "${blank}" ]; then
    BLANK=${blank}
elif [ -r "${DFT_BLANK}" ]; then
    BLANK=${DFT_BLANK}
else
    read -p "> matched blanksky evtfile: " BLANK
    if [ ! -r "${BLANK}" ]; then
        printf "ERROR: cannot acces given \`${BLANK}' blanksky file\n"
        exit ${ERR_BKG}
    fi
fi
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
# check given `grpcmd'
if [ ! -z "${grpcmd}" ]; then
    GRP_CMD="${grpcmd}"
else
    GRP_CMD="${DFT_GRP_CMD}"
fi
printf "## use grppha cmd: \`${GRP_CMD}'\n" | ${TOLOG}
## parameters }}}

## check needed files {{{
# check reg file(s)
printf "check accessibility of reg file(s) ...\n"
for reg_f in ${REGLIST}; do
    if [ ! -r "${reg_f}" ]; then
        printf "ERROR: file \`${reg_f}' NOT accessiable\n"
        exit ${ERR_REG}
    fi
done
# check the validity of *pie* regions
printf "check pie reg validity ...\n"
INVALID=`cat ${REGLIST} | grep -i 'pie' | awk -F, '{ print $6 }' | tr -d ')' | awk '$1 > 360'`
if [ "x${INVALID}" != "x" ]; then
    printf "WARNING: some pie region's END_ANGLE > 360\n" | ${TOLOG}
    printf "    CIAO v4.4 tools may run into trouble\n"
fi

# check files in `basedir'
printf "check needed files in basedir \`${BASEDIR}' ...\n"
# check asolis files
ASOLIS=`ls -1 ${BASEDIR}/${DFT_ASOLIS_PAT} | head -n 1`
if [ -z "${ASOLIS}" ]; then
    printf "ERROR: cannot find \"${DFT_ASOLIS_PAT}\" in dir \`${BASEDIR}'\n"
    exit ${ERR_ASOL}
fi
printf "## use asolis: \`${ASOLIS}'\n" | ${TOLOG}
# check badpixel file
BPIX=`ls -1 ${BASEDIR}/${DFT_BPIX_PAT} | head -n 1`
if [ -z "${BPIX}" ]; then
    printf "ERROR: cannot find \"${DFT_BPIX_PAT}\" in dir \`${BASEDIR}'\n"
    exit ${ERR_BPIX}
fi
printf "## use badpixel: \`${BPIX}'\n" | ${TOLOG}
# check pbk file
PBK=`ls -1 ${BASEDIR}/${DFT_PBK_PAT} | head -n 1`
if [ -z "${PBK}" ]; then
    printf "ERROR: cannot find \"${DFT_PBK_PAT}\" in dir \`${BASEDIR}'\n"
    exit ${ERR_PBK}
fi
printf "## use pbk: \`${PBK}'\n" | ${TOLOG}
# check msk file
MSK=`ls -1 ${BASEDIR}/${DFT_MSK_PAT} | head -n 1`
if [ -z "${MSK}" ]; then
    printf "ERROR: cannot find \"${DFT_MSK_PAT}\" in dir \`${BASEDIR}'\n"
    exit ${ERR_MSK}
fi
printf "## use msk: \`${MSK}'\n" | ${TOLOG}
## check files }}}

## main part {{{
## use 'for' loop to process every region file
for reg_i in ${REGLIST}; do
    printf "\n==============================\n"
    printf "PROCESS REGION fle \`${reg_i}' ...\n"

    REG_TMP="_tmp.reg"
    [ -f "${REG_TMP}" ] && rm -fv ${REG_TMP}         # remove tmp files
    cp -fv ${reg_i} ${REG_TMP}
    # check the validity of *pie* regions {{{
    INVALID=`grep -i 'pie' ${REG_TMP} | awk -F, '{ print $6 }' | tr -d ')' | awk '$1 > 360'`
    if [ "x${INVALID}" != "x" ]; then
        printf "WARNING: fix for *pie* region in file \`${reg_i}'\n"
        cat ${REG_TMP}
        A_OLD=`echo ${INVALID} | sed 's/\./\\\./'`
        A_NEW=`echo ${INVALID}-360 | bc -l | sed 's/\./\\\./'`
        sed -i'' "s/${A_OLD}\ *)/${A_NEW})/" ${REG_TMP}
        printf "    --> "
        cat ${REG_TMP}
    fi
    ## check pie region }}}

    LBKG_PI="${reg_i%.reg}.pi"
    ## use `specextract' to extract local bkg spectrum {{{
    # NOTE: set `binarfwmap=2' to save the time for generating `ARF'
    # I have tested that this bin factor has little impact on the results.
    # NO background response files
    # NO background spectrum (generate by self)
    # NO spectrum grouping (group by self using `grppha')
    printf "use \`specextract' to generate spectra and response ...\n"
    punlearn specextract
    specextract infile="${EVT}[sky=region(${REG_TMP})]" \
        outroot=${LBKG_PI%.pi} bkgfile="" asp="@${ASOLIS}" \
        pbkfile="${PBK}" mskfile="${MSK}" badpixfile="${BPIX}" \
        weight=yes correct=no bkgresp=no \
        energy="0.3:11.0:0.01" channel="1:1024:1" \
        combine=no binarfwmap=2 \
        grouptype=NONE binspec=NONE \
        verbose=2 clobber=yes
    # `specextract' }}}

    ## generate the blanksky bkg spectrum {{{
    printf "generate the blanksky bkg spectrum ...\n"
    BBKG_PI="blanksky_${LBKG_PI}"
    punlearn dmextract
    dmextract infile="${BLANK}[sky=region(${REG_TMP})][bin pi]" \
        outfile=${BBKG_PI} wmap="[bin det=8]" clobber=yes
    ## blanksky bkg spectrum }}}

    ## bkg renormalization {{{
    printf "Renormalize background ...\n"
    bkg_renorm ${LBKG_PI} ${BBKG_PI}
    ## bkg renorm }}}

    ## group spectrum {{{
    printf "group spectrum using \`grppha'\n"
    LBKG_GRP_PI="${LBKG_PI%.pi}_grp.pi"
    grppha infile="${LBKG_PI}" outfile="${LBKG_GRP_PI}" \
        comm="${GRP_CMD} & exit" clobber=yes > /dev/null
    ## group spectra }}}

    ## generate a script for XSPEC {{{
    XSPEC_XCM="xspec_${LBKG_PI%.pi}_model.xcm"
    if [ -e ${XSPEC_XCM} ]; then
        mv -fv ${XSPEC_XCM} ${XSPEC_XCM}_bak
    fi
    cat >> ${XSPEC_XCM} << _EOF_
## xspec script
## analysis chandra acis background components
## xspec model: apec+apec+wabs*(pow+apec)
##
## generated by script \``basename $0`'
## `date`
## NOTES: needs XSPEC v12.x

# settings
statistic chi
#weight churazov
abund grsa
query yes

# data
data ${LBKG_GRP_PI}
response ${LBKG_PI%.pi}.wrmf
arf ${LBKG_PI%.pi}.warf
backgrnd ${BBKG_PI}

# fitting range
ignore bad
ignore 0.0-0.4,8.0-**

# plot related
setplot energy

method leven 10 0.01
xsect bcmc
cosmo 70 0 0.73
xset delta 0.01
systematic 0

# model
model  apec + apec + wabs(powerlaw + apec)
           0.08      -0.01      0.008      0.008         64         64
              1     -0.001          0          0          5          5
              0      -0.01     -0.999     -0.999         10         10
            0.0       0.01         -1          0          0          1
            0.2      -0.01      0.008      0.008         64         64
              1     -0.001          0          0          5          5
              0      -0.01     -0.999     -0.999         10         10
            0.0       0.01         -1          0          0          1
         ${N_H}     -0.001          0          0     100000      1e+06
            1.4      -0.01         -3         -2          9         10
            0.0       0.01         -1          0          0          1
            1.0       0.01      0.008      0.008         64         64
            0.4      0.001          0          0          5          5
    ${REDSHIFT}      -0.01     -0.999     -0.999         10         10
            0.0       0.01          0          0      1e+24      1e+24

freeze 1 2 3
freeze 5 6 7
freeze 9 10 14
thaw 12 13
_EOF_
    ## XSPEC script }}}

done  # end 'for', `specextract'
## main part }}}

# clean
printf "clean ...\n"
rm -f ${REG_TMP}

printf "DONE\n"
###########################################################

# vim: set ts=8 sw=4 tw=0 fenc=utf-8 ft=sh: #
