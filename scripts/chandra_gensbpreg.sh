#!/bin/sh
#
# This script generate a series of regions for the extraction of
# radial surface brightness profile (SBP).
#
# Regions geneartion algorithm:
# (1) innermost 10 regions, we require a mininal of 5 pixel as well
#     as 50 counts within the 0.7-7.0 keV range.
# (2) following regions: R_out = R_in * 1.2, and require SNR > 1.5.
#     SNR = ??? (TODO)
#
# Reference:
# [1] region generate algorithm ??? (TODO)
#
# Author: Zhenghao ZHU
# Created: ??? (TODO)
#
# Change logs:
# 2017-02-26, Weitian LI
#   * Further simplify arguments handling
#   * Remove test support (-t) for simplification
#   * Rename 'stn' to 'SNR'
#   * Add ds9 view
# v3.0, 2015/06/03, Weitian LI
#   * Copy needed pfiles to current working directory, and
#     set environment variable $PFILES to use these first.
#   * Added missing punlearn
#   * Removed the section of dmlist.par & dmextract.par deletion
# v2.1, 2015/02/13, Weitian LI
#   * added '1' to denominators when calculate SNR to avoid division by zero
#   * added script description
# v2.0, 2013/03/06, Weitian LI
#   * added the parameter `-t' to print SNR results for testing


# minimal counts
CNT_MIN=50

# energy: 700-7000eV -- channel 49:479
ERANGE=700:7000
CH_LOW=49
CH_HI=479

# energy 9.5-12keV -- channel 651:822
CH_BKG_LOW=651
CH_BKG_HI=822

if [ $# -ne 4 ]; then
    printf "usage:\n"
    printf "    `basename $0` <evt> <bkg_pi> <reg_in> <reg_out>\n"
    exit 1
fi

EVT=$1
BKGSPC=$2
REG_IN=$3
REG_OUT=$4

X=`\grep -i 'point' ${REG_IN} | head -n 1 | tr -d 'a-zA-Z() ' | awk -F',' '{ print $1 }'`
Y=`\grep -i 'point' ${REG_IN} | head -n 1 | tr -d 'a-zA-Z() ' | awk -F',' '{ print $2 }'`

echo "EVT:      ${EVT}"
echo "ERANGE:   ${ERANGE}"
echo "Center:   (${X},${Y})"
echo "BKGSPC:   ${BKGSPC}"
echo ""

## prepare parameter files (pfiles) {{{
CIAO_TOOLS="dmstat dmlist dmextract"

# Copy necessary pfiles for localized usage
for tool in ${CIAO_TOOLS}; do
    pfile=`paccess ${tool}`
    [ -n "${pfile}" ] && punlearn ${tool} && cp -Lvf ${pfile} .
done

# Modify environment variable 'PFILES' to use local pfiles first
export PFILES="./:${PFILES}"
## pfiles }}}


[ -f "${REG_OUT}" ] && mv -fv ${REG_OUT} ${REG_OUT}_bak
RIN=0
ROUT=0
CNTS=0
for i in `seq 1 10`; do
    printf "Generate region #$i @ cnts:${CNT_MIN} ...\n"
    ROUT=`expr $RIN + 5`
    TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
    punlearn dmlist
    CNTS=`dmlist "${EVT}[energy=${ERANGE}][sky=${TMP_REG}]" blocks | \grep 'EVENTS' | awk '{ print $8 }'`
    while [ `echo "$CNTS < $CNT_MIN" | bc -l` -eq 1 ]; do
        ROUT=`expr $ROUT + 1`
        TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
        punlearn dmlist
        CNTS=`dmlist "${EVT}[energy=${ERANGE}][sky=${TMP_REG}]" blocks | \grep 'EVENTS' | awk '{ print $8 }'`
    done
    TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
    echo "${TMP_REG}" >> ${REG_OUT}
    RIN=$ROUT
done

# last region width
#REG_W=`tail -n 1 ${REG_OUT} | tr -d '()' | awk -F',' '{ print $4-$3 }'`

RIN=$ROUT
ROUT=`echo "scale=2; $ROUT * 1.2" | bc -l`

SNR=10
i=11
SNR_FILE="sbp_snr.dat"
[ -e ${SNR_FILE} ] && mv -fv ${SNR_FILE} ${SNR_FILE}_bak
while [ `echo "${SNR} > 1.5" | bc -l` -eq 1 ]; do
    printf "Generate SBP region #$i \n"
    i=`expr $i + 1`
    TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"

    # next region
    RIN=$ROUT
    ROUT=`echo "scale=2; $ROUT * 1.2" | bc -l`
    TMP_SPC=_tmpspc.pi
    punlearn dmextract
    dmextract infile="${EVT}[sky=${TMP_REG}][bin pi]" outfile=${TMP_SPC} wmap="[energy=300:12000][bin det=8]" clobber=yes
    punlearn dmstat
    INDEX_SRC=`dmstat "${TMP_SPC}[channel=${CH_BKG_LOW}:${CH_BKG_HI}][cols counts]" | \grep "sum:" | awk '{print $2}'`
    INDEX_BKG=`dmstat "${BKGSPC}[channel=${CH_BKG_LOW}:${CH_BKG_HI}][cols counts]" | \grep "sum:" | awk '{print $2}'`

    COUNT_SRC=`dmstat "${TMP_SPC}[channel=${CH_LOW}:${CH_HI}][cols counts]" | \grep "sum:" | awk '{print $2}'`
    COUNT_BKG=`dmstat "${BKGSPC}[channel=${CH_LOW}:${CH_HI}][cols counts]" | \grep "sum:" | awk '{print $2}'`

    #echo "CNT_SRC: ${COUNT_SRC}, IDX_SRC: ${INDEX_SRC}, CNT_BKG: ${COUNT_BKG}, IDX_BKG: ${INDEX_BKG}"

    # Add '1' to the denominators to avoid division by zero.
    SNR=`echo ${COUNT_SRC} ${INDEX_SRC} ${COUNT_BKG} ${INDEX_BKG} | awk '{ printf("%f", ($1 / ($2 + 1)) / ($3 / ($4 + 1))) }'`
    punlearn dmlist
    CNT=`dmlist "${EVT}[energy=${ERANGE}][sky=${TMP_REG}]" blocks | \grep 'EVENTS' | awk '{ print $8 }'`
    echo "CNT: ${CNT}"
    echo "CNT_MIN: ${CNT_MIN}"
    if [ `echo "${CNT} < ${CNT_MIN}" | bc -l` -eq 1 ]; then
        break
    fi
    echo "SNR: ${SNR}"
    echo "RIN: ${RIN}, ROUT: ${ROUT}"
    echo "SNR: ${SNR}" >> ${SNR_FILE}
    echo "${TMP_REG}" >> ${REG_OUT}
done

printf "check SBP regions ...\n"
ds9 ${EVT} -regions format ciao -regions system physical \
    -regions ${REG_OUT} -cmap he -bin factor 4
