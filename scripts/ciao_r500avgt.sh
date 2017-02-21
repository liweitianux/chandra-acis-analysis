#!/bin/sh
##
## To extract the spectrum and prepare the necessary files for
## calculating the average temperature within (0.1-0.5 r500) region.
##
## NOTE:
## 1) r500 default in unit `pixel', if in `kpc',
##    then `redshift z' and `calculator' are needed.
## 2) `background process' is same as `deproj_spectra'
##    which supports `spectrum', `local' and `blanksky'
## 3) ARF/RMF files either provided or use the ARF/RMF
##    of the outmost region
##
## Weitian LI <liweitianux@gmail.com>
##
## Change logs
## v1.1, 2012/08/26, Weitian LI
##   modify `KPC_PER_PIX', able to use the newest version `calc_distance'
## v1.2, 2012/08/26, Weitian LI
##   fix a bug with `DFT_BKGD'
## v2.0, 2012/09/04, Weitian LI
##   add parameter `inner' and `outer' to adjust the region range
##   modify parameter `r500' to take `kpc' as the default unit
## v2.1, 2012/10/05, Weitian LI
##   change `DFT_GRP_CMD' to `group 1 128 4 ...'
## v3.0, 2013/02/09, Weitian LI
##   modify for new process
## v3.1, 2015/05/27, Weitian LI
##   update 'DFT_ARF' & 'DFT_RMF' to find '*.arf' & '*.rmf' files
##   (specextract only use .arf & .rmf extensions since revision 2014-12)
## v3.2, 2015/05/30, Weitian LI
##   Added options '-cmap he -bin factor 4' to ds9 command
## v4.0, 2015/06/03, Weitian LI
##   * Copy needed pfiles to current working directory, and
##     set environment variable $PFILES to use these first.
##   * Replace 'grep' with '\grep', 'ls' with '\ls'
##   * replaced 'grppha' with 'dmgroup' to group spectra
##     (dmgroup will add history to fits file, while grppha NOT)
## 2016-06-08, Weitian LI
##   * Drop 'calc_distance' in favor of 'cosmo_calc'
## 2017-02-06, Weitian LI
##   * Specify regions format and system for ds9
##

## error code {{{
ERR_USG=1
ERR_DIR=11
ERR_EVT=12
ERR_BKG=13
ERR_REG=14
ERR_JSON=15
ERR_ASOL=21
ERR_BPIX=22
ERR_PBK=23
ERR_MSK=24
ERR_BKGTY=31
ERR_SPEC=32
ERR_ARF=51
ERR_RMF=52
ERR_UNI=61
## error code }}}

## usage, help {{{
case "$1" in
    -[hH]*|--[hH]*)
        printf "usage:\n"
        printf "    `basename $0` evt=<evt2_clean> r500=<r500_kpc> basedir=<basedir> info=<info_json> inner=<inner_val> outer=<outer_val> regin=<input_reg> regout=<output_reg> bkgd=<blank_evt|lbkg_reg|bkg_spec> nh=<nH> z=<redshift> arf=<arf_file> rmf=<rmf_file> [ grouptype=<NUM_CTS|BIN> grouptypeval=<number> binspec=<binspec> log=<log_file> ]\n"
        exit ${ERR_USG}
        ;;
esac
## usage, help }}}

## default parameters {{{
# default `event file' which used to match `blanksky' files
#DFT_EVT="_NOT_EXIST_"
DFT_EVT="`\ls evt2*_clean.fits 2> /dev/null`"
# default `bkgd', use `bkgcorr_blanksky*' corrected bkg spectrum
DFT_BKGD="`\ls bkgcorr_blanksky_*.pi 2> /dev/null`"
# default basedir
DFT_BASEDIR="../.."
# default `radial region file'
#DFT_REG_IN="_NOT_EXIST_"
DFT_REG_IN="rspec.reg"
# default region range (0.1-0.5 R500)
DFT_INNER="0.1"
DFT_OUTER="0.5"
# default ARF/RMF, the one of the outmost region
DFT_ARF="`\ls -1 r?_*.warf r?_*.arf 2> /dev/null | tail -n 1`"
DFT_RMF="`\ls -1 r?_*.wrmf r?_*.rmf 2> /dev/null | tail -n 1`"

# default parameters for 'dmgroup'
DFT_GROUPTYPE="NUM_CTS"
DFT_GROUPTYPEVAL="25"
#DFT_GROUPTYPE="BIN"
DFT_BINSPEC="1:128:2,129:256:4,257:512:8,513:1024:16"

# default JSON pattern
DFT_JSON_PAT="*_INFO.json"

# default `log file'
DFT_LOGFILE="r500avgt_`date '+%Y%m%d%H'`.log"
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

## background renormalization (BACKSCAL) {{{
# renorm background according to particle background
# energy range: 9.5-12.0 keV (channel: 651-822)
CH_LOW=651
CH_HI=822
pb_flux() {
    punlearn dmstat
    COUNTS=`dmstat "$1[channel=${CH_LOW}:${CH_HI}][cols COUNTS]" | \grep -i 'sum:' | awk '{ print $2 }'`
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
    punlearn dmkeypar
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
if [ -d "${basedir}" ]; then
    BASEDIR=${basedir}
else
    BASEDIR=${DFT_BASEDIR}
fi
if [ ! -z "${json}" ] && [ -r "${BASEDIR}/${json}" ]; then
    JSON_FILE="${BASEDIR}/${json}"
elif ls ${BASEDIR}/${DFT_JSON_PAT} > /dev/null 2>&1; then
    JSON_FILE=`\ls ${BASEDIR}/${DFT_JSON_PAT}`
else
    read -p "> JSON_file: " JSON_FILE
    if [ ! -r "${JSON_FILE}" ]; then
        printf "ERROR: cannot access given \`${JSON_FILE}'\n"
        exit ${ERR_JSON}
    fi
fi
printf "## use json_file: \`${JSON_FILE}'\n" | ${TOLOG}

# process `nh' and `redshift' {{{
NH_JSON=`\grep '"nH' ${JSON_FILE} | sed 's/.*"nH.*":\ //' | sed 's/\ *,$//'`
Z_JSON=`\grep '"redshift' ${JSON_FILE} | sed 's/.*"redshift.*":\ //' | sed 's/\ *,$//'`
printf "## get nh: \`${NH_JSON}' (from \`${JSON_FILE}')\n" | ${TOLOG}
printf "## get redshift: \`${Z_JSON}' (from \`${JSON_FILE}')\n" | ${TOLOG}
## if `nh' and `redshift' supplied in cmdline, then use them
if [ ! -z "${nh}" ]; then
    N_H=${nh}
else
    N_H=${NH_JSON}
fi
# redshift
if  [ ! -z "${z}" ]; then
    REDSHIFT=${z}
else
    REDSHIFT=${Z_JSON}
fi
printf "## use nH: ${N_H}\n" | ${TOLOG}
printf "## use redshift: ${REDSHIFT}\n" | ${TOLOG}
# nh & redshift }}}

# region range {{{
if [ ! -z "${inner}" ]; then
    INNER="${inner}"
else
    INNER=${DFT_INNER}
fi
if [ ! -z "${outer}" ]; then
    OUTER="${outer}"
else
    OUTER=${DFT_OUTER}
fi
printf "## region range: (${INNER} - ${OUTER} R500)\n" | ${TOLOG}
# range }}}

# process `r500' {{{
R500_RAW=`\grep '"R500.*kpc' ${JSON_FILE} | sed 's/.*"R500.*":\ //' | sed 's/\ *,$//'`
if [ ! -z "${r500}" ]; then
    R500_RAW=${r500}
fi
if [ -z "${R500_RAW}" ]; then
    printf "## input R500 followed with unit, e.g.: 800kpc, 400pix\n"
    read -p "> value of \`R500' (in pixel/kpc): " R500_RAW
fi
R500_VAL=`echo "${R500_RAW}" | tr -d 'a-zA-Z, '`
R500_UNI=`echo "${R500_RAW}" | tr -d '0-9, '`
printf "## get \`R500': ${R500_VAL} in unit \`${R500_UNI}'\n" | ${TOLOG}

# if in kpc, convert to pix
case "${R500_UNI}" in
    [pP]*)
        printf "## units in \`pixel', conversion not needed\n" | ${TOLOG}
        R500_PIX_B=`echo ${R500_VAL} | sed 's/[eE]/\*10\^/' | sed 's/+//'`
        ;;
    *)
        printf "## units in \`kpc', convert to \`Chandra pixel'\n" | ${TOLOG}
        KPC_PER_PIX=`cosmo_calc.py -b --kpc-per-pix ${REDSHIFT}`
        # convert scientific notation for `bc'
        KPC_PER_PIX_B=`echo ${KPC_PER_PIX} | sed 's/[eE]/\*10\^/' | sed 's/+//'`
        printf "## calculated \`kpc/pixel': ${KPC_PER_PIX_B}\n"
        R500_VAL_B=`echo ${R500_VAL} | sed 's/[eE]/\*10\^/' | sed 's/+//'`
        R500_PIX_B=`echo "scale = 4; ${R500_VAL_B} / ( ${KPC_PER_PIX_B} )" | bc -l`
        ;;
esac
# calc (inner-outer R500)
R_IN=`echo "scale = 4; ${INNER} * ${R500_PIX_B}" | bc -l`
R_OUT=`echo "scale = 4; ${OUTER} * ${R500_PIX_B}" | bc -l`
printf "## R500 in units pixel: ${R500_PIX_B}\n" | ${TOLOG}
printf "## (${INNER}-${OUTER} R500) range in pixel: ${R_IN} - ${R_OUT}\n" | ${TOLOG}
# r500 }}}

# check evt file
if [ -r "${evt}" ]; then
    EVT=${evt}
elif [ -r "${DFT_EVT}" ]; then
    EVT=${DFT_EVT}
else
    read -p "> clean evt2 file: " EVT
    if [ ! -r "${EVT}" ]; then
        printf "ERROR: cannot access given \`${EVT}' evt file\n"
        exit ${ERR_EVT}
    fi
fi
printf "## use evt file: \`${EVT}'\n" | ${TOLOG}

# input and output region files {{{
if [ -r "${regin}" ]; then
    REG_IN="${regin}"
elif [ -r "${DFT_REG_IN}" ]; then
    REG_IN=${DFT_REG_IN}
else
    read -p "> previous used radial spec regfile: " REG_IN
    if [ ! -r "${REG_IN}" ]; then
        printf "ERROR: cannot access given \`${REG_IN}' region file\n"
        exit ${ERR_REG}
    fi
fi
printf "## use previous regfile: \`${REG_IN}'\n" | ${TOLOG}
if [ ! -z "${regout}" ]; then
    REG_OUT="${regout}"
else
    REG_OUT="r500avgt_${INNER}-${OUTER}.reg"
fi
[ -e "${REG_OUT}" ] && mv -fv ${REG_OUT} ${REG_OUT}_bak
printf "## set output regfile: \`${REG_OUT}'\n" | ${TOLOG}

# get center position from `regin'
# only consider `pie' or `annulus'-shaped region
TMP_REG=`\grep -iE '(pie|annulus)' ${REG_IN} | head -n 1`
XC=`echo ${TMP_REG} | tr -d 'a-zA-Z() ' | awk -F',' '{ print $1 }'`
YC=`echo ${TMP_REG} | tr -d 'a-zA-Z() ' | awk -F',' '{ print $2 }'`
printf "## get center coord: (${XC},${YC})\n" | ${TOLOG}
# region files }}}

# check given bkgd, determine background {{{
if [ -r "${bkgd}" ]; then
    BKGD=${bkgd}
elif [ -r "${DFT_BKGD}" ]; then
    BKGD=${DFT_BKGD}
else
    read -p "> background (blanksky_evt | lbkg_reg | bkg_spec): " BKGD
    if [ ! -r "${BKGD}" ]; then
        printf "ERROR: cannot access given \`${BKGD}'\n"
        exit ${ERR_BKG}
    fi
fi
printf "## use bkgd: \`${BKGD}'\n" | ${TOLOG}
# determine bkg type: blanksky, lbkg_reg, bkg_spec ?
# according to file type first: text / FITS
# if FITS, then get values of `HDUCLAS1' and `OBJECT'
if file -bL ${BKGD} | \grep -qi 'text'; then
    printf "## given \`${BKGD}' is a \`text file'\n"
    printf "##   use it as local bkg region file\n"
    printf "##   use *LOCAL BKG SPEC*\n" | ${TOLOG}
    # just set flags, extract spectrum later
    USE_LBKG_REG=YES
    USE_BLANKSKY=NO
    USE_BKG_SPEC=NO
elif file -bL ${BKGD} | \grep -qi 'FITS'; then
    printf "## given \`${BKGD}' is a \`FITS file'\n"
    # get FITS header keyword
    punlearn dmkeypar
    HDUCLAS1=`dmkeypar ${BKGD} HDUCLAS1 echo=yes`
    if [ "${HDUCLAS1}" = "EVENTS" ]; then
        # event file
        printf "##   given file is \`event'\n"
        # check if `blanksky' or `stowed bkg'
        BKG_OBJ=`dmkeypar ${BKGD} OBJECT echo=yes`
        if [ "${BKG_OBJ}" = "BACKGROUND DATASET" ] || [ "${BKG_OBJ}" = "ACIS STOWED" ]; then
            # valid bkg evt file
            printf "##   given FITS file is a valid bkgrnd file\n"
            printf "##   use *BLANKSKY*\n" | ${TOLOG}
            USE_BLANKSKY=YES
            USE_LBKG_REG=NO
            USE_BKG_SPEC=NO
            # specify `BLANKSKY'
            BLANKSKY=${BKGD}
        else
            # invalid bkg evt file
            printf "ERROR: invalid bkg evt file given\n"
            exit ${ERR_BKGTY}
        fi
    elif [ "${HDUCLAS1}" = "SPECTRUM" ]; then
        # spectrum file
        printf "##   given file is \`spectrum'\n"
        printf "##   use *BKG SPECTRUM*\n" | ${TOLOG}
        USE_BKG_SPEC=YES
        USE_BLANKSKY=NO
        USE_LBKG_REG=NO
        # specify `BKG_SPEC'
        BKG_SPEC=${BKGD}
    else
        # other type
        printf "ERROR: other type FITS given\n"
        exit ${ERR_BKGTY}
    fi
else
    printf "ERROR: given \`${BKGD}' type UNKNOWN\n"
    exit ${ERR_BKGTY}
fi
# bkgd }}}

# check `arf' and `rmf' {{{
if [ -r "${arf}" ]; then
    ARF=${arf}
elif [ -r "${DFT_ARF}" ]; then
    ARF=${DFT_ARF}
else
    read -p "> provide the ARF to use: " ARF
    if [ ! -r "${ARF}" ]; then
        printf "ERROR: cannot access given \`${ARF}'\n"
        exit ${ERR_ARF}
    fi
fi
printf "## use ARF: \`${ARF}'\n" | ${TOLOG}
# rmf
if [ -r "${rmf}" ]; then
    RMF=${rmf}
elif [ -r "${DFT_RMF}" ]; then
    RMF=${DFT_RMF}
else
    read -p "> provide the RMF to use: " RMF
    if [ ! -r "${RMF}" ]; then
        printf "ERROR: cannot access given \`${RMF}'\n"
        exit ${ERR_RMF}
    fi
fi
printf "## use RMF: \`${RMF}'\n" | ${TOLOG}
# arf & rmf }}}

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

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="dmstat dmkeypar dmhedit dmextract dmgroup"

# Copy necessary pfiles for localized usage
for tool in ${CIAO_TOOLS}; do
    pfile=`paccess ${tool}`
    [ -n "${pfile}" ] && punlearn ${tool} && cp -Lvf ${pfile} .
done

# Modify environment variable 'PFILES' to use local pfiles first
export PFILES="./:${PFILES}"
## pfiles }}}

### main ###

## region related {{{
## generate the needed region file
printf "generate the output region file ...\n"
cat > ${REG_OUT} << _EOF_
# Region file format: CIAO version 1.0
pie(${XC},${YC},${R_IN},${R_OUT},0,360)
_EOF_

## open the evt file to verify or modify
printf "## check the generated pie region ...\n"
printf "## if modified, save with the same name \`${REG_OUT}' (overwrite)\n"
ds9 ${EVT} -regions format ciao \
    -regions system physical \
    -regions ${REG_OUT} \
    -cmap he -bin factor 4

## check the (modified) region (pie region end angle)
printf "check the above region (for pie region end angle) ...\n"
INVALID=`\grep -i 'pie' ${REG_OUT} | awk -F'[,()]' '$7 > 360'`
if [ "x${INVALID}" != "x" ]; then
    printf "*** WARNING: there are pie regions' END_ANGLE > 360\n" | ${TOLOG}
    printf "*** will to fix ...\n"
    mv -fv ${REG_OUT} ${REG_OUT}_tmp
    # using `awk' to fix
    awk -F'[,()]' '{
        if ($7 > 360) {
            printf "%s(%.2f,%.2f,%.2f,%.2f,%.2f,%.2f)\n", $1,$2,$3,$4,$5,$6,($7-360)
        }
        else {
            print $0
        }
    }' ${REG_OUT}_tmp > ${REG_OUT}
    rm -f ${REG_OUT}_tmp
fi
## region related }}}

## generate spectrum {{{
# object
AVGT_SPEC="${REG_OUT%.reg}.pi"
AVGT_SPEC_GRP="${AVGT_SPEC%.pi}_grp.pi"
printf "extract object spectrum \`${AVGT_SPEC}' ...\n"
punlearn dmextract
dmextract infile="${EVT}[sky=region(${REG_OUT})][bin PI]" \
    outfile="${AVGT_SPEC}" wmap="[bin det=8]" clobber=yes
# group spectrum
printf "group object spectrum ...\n"
punlearn dmgroup
dmgroup infile="${AVGT_SPEC}" outfile="${AVGT_SPEC_GRP}" \
    grouptype="${GROUPTYPE}" grouptypeval=${GROUPTYPEVAL} \
    binspec="${BINSPEC}" xcolumn="CHANNEL" ycolumn="COUNTS" \
    clobber=yes

# background
printf "generate the background spectrum ...\n"
AVGT_BKG="${AVGT_SPEC%.pi}_bkg.pi"
if [ "${USE_BLANKSKY}" = "YES" ]; then
    # use blanksky as background file
    printf "extract spectrum from blanksky ...\n"
    punlearn dmextract
    dmextract infile="${BLANKSKY}[sky=region(${REG_OUT})][bin PI]" \
        outfile=${AVGT_BKG} wmap="[bin det=8]" clobber=yes
elif [ "${USE_LBKG_REG}" = "YES" ]; then
    printf "extract local background ...\n"
    punlearn dmextract
    dmextract infile="${EVT}[sky=region(${BKGD})][bin PI]" \
        outfile=${AVGT_BKG} wmap="[bin det=8]" clobber=yes
elif [ "${USE_BKG_SPEC}" = "YES" ]; then
    printf "copy specified background spectrum ...\n"
    cp -fv ${BKG_SPEC} ${AVGT_BKG}
fi

printf "renormalize the background ...\n"
bkg_renorm ${AVGT_SPEC} ${AVGT_BKG}

## spectrum }}}

## generate XSPEC script {{{
printf "generate a XSPEC script ...\n"
# default output xspec scripts
XSPEC_SCRIPT="xspec_${REG_OUT%.reg}.xcm"
[ -e "${XSPEC_SCRIPT}" ] && mv -fv ${XSPEC_SCRIPT} ${XSPEC_SCRIPT}_bak
cat > ${XSPEC_SCRIPT} << _EOF_
## XSPEC script
## spectrum analysis to get the average temperatue with (0.1-0.5 R500)
##
## generated by: \``basename $0`'
## date: \``date`'
##

# xspec settings
statistic chi
abund grsa
query yes

# data
data ${AVGT_SPEC_GRP}
response ${RMF}
arf ${ARF}
backgrnd ${AVGT_BKG}

# fitting range
ignore bad
ignore 0.0-0.7,7.0-**

# plot related
setplot energy

method leven 10 0.01
xsect bcmc
cosmo 70 0 0.73
xset delta 0.01
systematic 0

# model
model wabs*apec
         ${N_H}     -0.001          0          0     100000      1e+06
            1.0       0.01      0.008      0.008         64         64
            0.4      0.001          0          0          5          5
    ${REDSHIFT}      -0.01     -0.999     -0.999         10         10
            0.0       0.01          0          0      1e+24      1e+24

## xspec script end
_EOF_
## xspec script }}}

exit 0
