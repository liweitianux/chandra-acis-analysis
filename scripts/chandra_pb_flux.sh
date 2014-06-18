#!/bin/sh
#
# chandra particle background
# 9.5-12.0 keV (channel: 651-822)
# PI = [ energy(eV) / 14.6 eV + 1 ]
#
# LIweitiaNux <liweitianux@gmail.com>
# July 30, 2012
#
# ChangeLog:
#   v1.1: August 2, 2012
#       fix bugs with scientific notation in `bc'
#

if [ $# -eq 0 ]; then
    echo "usage:"
    echo "    `basename $0` <spec> ..."
    exit 1
fi

## energy range: 9.5 -- 12.0 keV
CH_LOW=651
CH_HI=822

echo "CHANNEL: $CH_LOW -- $CH_HI"

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

