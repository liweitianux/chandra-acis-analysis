#!/bin/sh
#
# extract background spectra from src and blanksky
# renormalization the blank spectrum
#
# References:
# * Chandra spectrum analysis
#   http://cxc.harvard.edu/ciao/threads/extended/
# * specextract
#   http://cxc.harvard.edu/ciao/ahelp/specextract.html
# * CIAO v4.4 region bugs
#   http://cxc.harvard.edu/ciao/bugs/regions.html#bug-12187
#
# Weitian LI
# 2012-07-24

# Change logs:
# 2017-02-26, Weitian LI
#   * Use 'manifest.py', 'results.py', and 'renorm_spectrum.py'
#   * Simplify 'specextract' parameters handling
# v5.0, 2015/06/02, Weitian LI
#   * Removed 'GREP_OPTIONS' and replace 'grep' with '\grep'
#   * Removed 'trap INT date'
#   * Copy needed pfiles to current working directory, and
#     set environment variable $PFILES to use these first.
#   * replaced 'grppha' with 'dmgroup' to group spectra
#     (dmgroup will add history to fits file, while grppha NOT)
# v4.1, 2014/07/29, Weitian LI
#   fix 'pbkfile' parameters for CIAO-4.6
# v4, 2012/08/13
#   add `clobber=yes'
#   improve error code
#   improve cmdline arguements
#   provide a flexible way to pass parameters
#     (through cmdline which similar to CIAO,
#     and default filename match patterns)
#   add simple `logging' function
# v3, 2012/08/09
#   fix `scientific notation' for `bc'
#   change `spec group' method to `min 15'
#


## usage, help {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` reg=<reglist> [ evt=<evt2_clean> blank=<blanksky_evt> nh=<nH> z=<redshift> grouptype=<NUM_CTS|BIN> grouptypeval=<number> binspec=<binspec> log=<log_file> ]\n"
        printf "\nNotes:\n"
        printf "    If grouptype=NUM_CTS, then grouptypeval required.\n"
        printf "    If grouptype=BIN, then binspec required.\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
# default `event file' which used to match `blanksky' files
DFT_EVT=$(manifest.py -b getpath -r evt2_clean)
# default `blanksky file'
DFT_BLANK=$(manifest.py -b getpath -r bkg_blank)
# default parameters for 'dmgroup'
DFT_GROUPTYPE="NUM_CTS"
DFT_GROUPTYPEVAL="20"
#DFT_GROUPTYPE="BIN"
DFT_BINSPEC="1:128:2,129:256:4,257:512:8,513:1024:16"
# default `log file'
DFT_LOGFILE="bkg_spectra_`date '+%Y%m%d'`.log"

ASOL=$(manifest.py -b -s "," getpath -r asol)
BPIX=$(manifest.py -b getpath -r bpix)
MSK=$(manifest.py -b getpath -r msk)
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
    N_H=$(results.py -b get nh)
else
    N_H=${nh}
fi
printf "## use nH: ${N_H}\n" | ${TOLOG}
# check given redshift
if [ -z "${z}" ]; then
    REDSHIFT=$(results.py -b get z)
else
    REDSHIFT=${z}
fi
printf "## use redshift: ${REDSHIFT}\n" | ${TOLOG}
# check given dmgroup parameters: grouptype, grouptypeval, binspec
if [ -z "${grouptype}" ]; then
    GROUPTYPE="${DFT_GROUPTYPE}"
elif [ "x${grouptype}" = "xNUM_CTS" ] || [ "x${grouptype}" = "xBIN" ]; then
    GROUPTYPE="${grouptype}"
else
    printf "ERROR: given grouptype \`${grouptype}' invalid.\n"
    exit ${ERR_GRPTYPE}
fi
printf "## use grouptype: \`${GROUPTYPE}'\n" | ${TOLOG}
if [ ! -z "${grouptypeval}" ]; then
    GROUPTYPEVAL="${grouptypeval}"
else
    GROUPTYPEVAL="${DFT_GROUPTYPEVAL}"
fi
printf "## use grouptypeval: \`${GROUPTYPEVAL}'\n" | ${TOLOG}
if [ ! -z "${binspec}" ]; then
    BINSPEC="${binspec}"
else
    BINSPEC="${DFT_BINSPEC}"
fi
printf "## use binspec: \`${BINSPEC}'\n" | ${TOLOG}
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
INVALID=`cat ${REGLIST} | \grep -i 'pie' | awk -F, '{ print $6 }' | tr -d ')' | awk '$1 > 360'`
if [ "x${INVALID}" != "x" ]; then
    printf "WARNING: some pie region's END_ANGLE > 360\n" | ${TOLOG}
    printf "    CIAO v4.4 tools may run into trouble\n"
fi
## check files }}}

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="dmstat dmkeypar dmhedit specextract dmextract dmgroup"

# Copy necessary pfiles for localized usage
for tool in ${CIAO_TOOLS}; do
    pfile=`paccess ${tool}`
    [ -n "${pfile}" ] && punlearn ${tool} && cp -Lvf ${pfile} .
done

# Modify environment variable 'PFILES' to use local pfiles first
export PFILES="./:${PFILES}"
## pfiles }}}

## main part {{{
## use 'for' loop to process every region file
for reg_i in ${REGLIST}; do
    printf "\n==============================\n"
    printf "PROCESS REGION fle \`${reg_i}' ...\n"

    REG_TMP="_tmp.reg"
    [ -f "${REG_TMP}" ] && rm -fv ${REG_TMP}         # remove tmp files
    cp -fv ${reg_i} ${REG_TMP}
    # check the validity of *pie* regions {{{
    INVALID=`\grep -i 'pie' ${REG_TMP} | awk -F, '{ print $6 }' | tr -d ')' | awk '$1 > 360'`
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

    printf "use \`specextract' to generate spectra and response ...\n"
    ## use `specextract' to extract local bkg spectrum {{{
    # NOTE: set `binarfwmap=2' to save the time for generating `ARF'
    # I have tested that this bin factor has little impact on the results.
    # NO background response files
    # NO background spectrum (generate by self)
    # NO spectrum grouping (group by self using `dmgroup')
    punlearn specextract
    specextract infile="${EVT}[sky=region(${REG_TMP})]" \
        outroot=${LBKG_PI%.pi} bkgfile="" asp="${ASOL}" \
        mskfile="${MSK}" badpixfile="${BPIX}" \
        correctpsf=no weight=yes weight_rmf=yes \
        energy="0.3:11.0:0.01" channel="1:1024:1" \
        bkgresp=no combine=no binarfwmap=2 \
        grouptype=NONE binspec=NONE \
        clobber=yes verbose=2
    # specextract }}}

    ## generate the blanksky bkg spectrum {{{
    printf "generate the blanksky bkg spectrum ...\n"
    BBKG_PI="blanksky_${LBKG_PI}"
    punlearn dmextract
    dmextract infile="${BLANK}[sky=region(${REG_TMP})][bin pi]" \
        outfile=${BBKG_PI} wmap="[bin det=8]" clobber=yes
    ## blanksky bkg spectrum }}}

    ## bkg renormalization {{{
    printf "Renormalize background ...\n"
    renorm_spectrum.py -r ${LBKG_PI} ${BBKG_PI}
    ## bkg renorm }}}

    ## group spectrum {{{
    # use 'dmgroup' instead of 'grppha', because 'dmgroup' will add
    # command history to FITS header (maybe useful for later reference).
    printf "group spectrum using \`dmgroup'\n"
    LBKG_GRP_PI="${LBKG_PI%.pi}_grp.pi"
    punlearn dmgroup
    dmgroup infile="${LBKG_PI}" outfile="${LBKG_GRP_PI}" \
        grouptype="${GROUPTYPE}" grouptypeval=${GROUPTYPEVAL} \
        binspec="${BINSPEC}" xcolumn="CHANNEL" ycolumn="COUNTS" \
        clobber=yes
    ## group }}}

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

# vim: set ts=8 sw=4 tw=0 fenc=utf-8 ft=sh: #
