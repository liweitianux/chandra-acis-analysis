#!/bin/sh
#
# chandra particle background
# 9.5-12.0 keV (channel: 651-822)
# PI = [ energy(eV) / 14.6 eV + 1 ]
#
# Weitian <liweitianux@gmail.com>
# 2012/07/30
#
# ChangeLog:
# v2.0, 2015/06/03, Aaron LI
#   * Copy needed pfiles to tmp directory,
#     set environment variable $PFILES to use these first.
#     and remove them after usage.
# v1.1: August 2, 2012
#   * fix bugs with scientific notation in `bc'
#

if [ $# -eq 0 ] || [ "x$1" = "x-h" ]; then
    echo "usage:"
    echo "    `basename $0` <spec> ..."
    exit 1
fi

## energy range: 9.5 -- 12.0 keV
EN_LOW="9.5"
EN_HI="12.0"
CH_LOW=651
CH_HI=822

echo "Energy: $EN_LOW -- $EN_HI (keV)"
echo "Channel: $CH_LOW -- $CH_HI"

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="dmstat dmkeypar"

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

while ! [ -z $1 ]; do
    f=$1
    shift
    echo "FILE: $f"
    punlearn dmstat
    COUNTS=`dmstat "$f[channel=${CH_LOW}:${CH_HI}][cols counts]" | grep 'sum:' | awk '{ print $2 }'`
    punlearn dmkeypar
    EXPTIME=`dmkeypar $f EXPOSURE echo=yes`
    BACK=`dmkeypar $f BACKSCAL echo=yes`
    # fix `scientific notation' bug for `bc'
    EXPTIME_B=`echo ${EXPTIME} | sed 's/[eE]/\*10\^/' | sed 's/+//'`
    BACK_B=`echo "( ${BACK} )" | sed 's/[eE]/\*10\^/' | sed 's/+//'`
    PB_FLUX=`echo "scale = 16; ${COUNTS} / ${EXPTIME_B} / ${BACK_B}" | bc -l`
    echo "    counts / exptime / backscal: ${COUNTS} / ${EXPTIME} / ${BACK}"
    echo "    ${PB_FLUX}"
done

# clean pfiles
rm -rf ${PFILES_TMPDIR}

