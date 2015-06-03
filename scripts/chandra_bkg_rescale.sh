#!/bin/sh
#
# background rescale, by adjusting `BACKSCAL'
# according to the photon flux values in `9.5-12.0 keV'
#
# Weitian LI <liweitianux@gmail.com>
# 2012/08/14
#
# Changelogs:
# 2015/06/03, Aaron LI
#   * Copy needed pfiles to tmp directory,
#     set environment variable $PFILES to use these first.
#     and remove them after usage.
#

## background rescale (BACKSCAL) {{{
# rescale background according to particle background
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

bkg_rescale() {
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
## bkg rescale }}}

if [ $# -ne 2 ] || [ "x$1" = "x-h" ]; then
    printf "usage:\n"
    printf "    `basename $0` <src_spec> <bkg_spec>\n"
    printf "\nNOTE:\n"
    printf "<bkg_spec> is the spectrum to be adjusted\n"
    exit 1
fi

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="dmstat dmkeypar dmhedit"

PFILES_TMPDIR="/tmp/pfiles-$$"
[ -d "${PFILES_TMPDIR}" ] && rm -rf ${PFILES_TMPDIR} || mkdir ${PFILES_TMPDIR}

# Copy necessary pfiles for localized usage
for tool in ${CIAO_TOOLS}; do
    pfile=`paccess ${tool}`
    [ -n "${pfile}" ] && punlearn ${tool} && cp -Lvf ${pfile} ${PFILES_TMPDIR}/
done

# Modify environment variable 'PFILES' to use local pfiles first
export PFILES="${PFILES_TMPDIR}:${PFILES}"
## pfiles }}}

# perform `bkg_rescale'
bkg_rescale "$1" "$2"

# clean pfiles
rm -rf ${PFILES_TMPDIR}

exit 0

