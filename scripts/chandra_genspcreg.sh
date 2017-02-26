#!/bin/sh
#
# This script generate a series of regions for the extraction of
# radial surface brightness profile (SBP).
#
# Regions geneartion algorithm:
# (TODO)
#
# Author: Zhenghao ZHU
# Created: ???
#
# Change logs:
# 2017-02-26, Weitian LI
#   * Further simplify arguments handling
#   * Remove test support (-t) for simplification
#   * Rename 'stn' to 'SNR'
#   * Add ds9 view
# v2.0, 2015/06/03, Weitian LI
#   * Copy needed pfiles to current working directory, and
#     set environment variable $PFILES to use these first.
#   * Added missing punlearn
#   * Removed the section of dmlist.par & dmextract.par deletion

# minimal counts
CNT_MIN=2500

# energy: 700-7000eV -- channel 49:479
ERANGE=700:7000
CH_LOW=49
CH_HI=479

# energy 9.5-12keV -- channel 651:822
CH_BKG_LOW=651
CH_BKG_HI=822

if [ $# -ne 4 ] ; then
    printf "usage:\n"
    printf " `basename $0` <evt> <bkg_pi> <reg_in> <reg_out>\n"
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
ROUT_MAX=1500
SNR=10

SNR_FILE="spc_snr.dat"
[ -e ${SNR_FILE} ] && mv -fv ${SNR_FILE} ${SNR_FILE}_bak
i=0
while [ `echo "$SNR > 2 "| bc -l` -eq 1 ]  ; do
    if [ `echo "$ROUT > $ROUT_MAX" | bc -l` -eq 1 ]; then
        break
    fi
    RIN=${ROUT}
    if [ $i -gt 0 ]; then
        printf "  #$i: ${TMP_REG}\n"
        echo "${TMP_REG}" >> ${REG_OUT}
    fi
    i=`expr $i + 1`
    printf "Generate region #$i ...\n"
    if [ ${ROUT} -eq 0 ] ; then
        ROUT=5
    fi
    TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
    punlearn dmlist
    CNTS=`dmlist "${EVT}[energy=${ERANGE}][sky=${TMP_REG}]" blocks | \grep 'EVENTS' | awk '{print $8}'`
    while [ ${CNTS} -lt ${CNT_MIN} ]; do
        ROUT=`expr $ROUT + 1 `
        if [ `echo "$ROUT > $ROUT_MAX" | bc -l` -eq 1 ]; then
            break
        fi
        TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
        punlearn dmlist
        CNTS=`dmlist "${EVT}[energy=${ERANGE}][sky=${TMP_REG}]" blocks | \grep 'EVENTS' | awk '{print $8}'`
    done
    TMP_SPC=_tmpspc.pi
    punlearn dmextract
    dmextract infile="${EVT}[sky=${TMP_REG}][bin pi]" outfile=${TMP_SPC} wmap="[energy=300:12000][bin tdet=8]" clobber=yes
    punlearn dmstat
    INDEX_SRC=`dmstat "${TMP_SPC}[channel=${CH_BKG_LOW}:${CH_BKG_HI}][cols counts]"  | \grep "sum:" | awk '{print $2}' `
    INDEX_BKG=`dmstat "${BKGSPC}[channel=${CH_BKG_LOW}:${CH_BKG_HI}][cols counts]" | \grep "sum:" | awk '{print $2}' `

    COUNT_SRC=`dmstat "${TMP_SPC}[channel=${CH_LOW}:${CH_HI}][cols counts]" | \grep "sum:" | awk '{print $2}' `
    COUNT_BKG=`dmstat "${BKGSPC}[channel=${CH_LOW}:${CH_HI}][cols counts]" | \grep "sum:" | awk '{print $2}' `
    if [ ${INDEX_SRC} -eq 0 ] ;then
        SNR=10000
    else
        SNR=`echo ${COUNT_SRC} ${INDEX_SRC} ${COUNT_BKG} ${INDEX_BKG} | awk '{ printf("%f",$1/$2/$3*$4) }' `
    fi
    echo "  SNR: ${SNR}"
    echo "${SNR}" >> "${SNR_FILE}"
done

## fix 'i', to consistent with the actual annuluses
i=`expr $i - 1`

if [ $i -lt 3 ]; then
    printf "*** WARNING: NOT ENOUGH PHOTONS ***\n"
    printf "*** TOTAL $i regions ***\n\n"
    if [ ! -f ${REG_OUT} ] || [ `wc -l ${REG_OUT} | awk '{ print $1 }'` -eq 0 ]; then
        printf "*** ONLY 1 REGION: ${TMP_REG}\n"
        rm -f ${REG_OUT}
        echo "${TMP_REG}" >> ${REG_OUT}
    fi
elif [ $i -gt 6 ]; then
    mv -fv ${REG_OUT} ${REG_OUT}_2500bak
    CNTS=0
    punlearn dmlist
    CNTS_TOTAL=`dmlist "${EVT}[energy=${ERANGE}][sky=pie($X,$Y,0,$RIN,0,360)]" blocks | \grep 'EVENTS' | awk '{print $8}'`
    CNTS_USE=`echo "${CNTS_TOTAL} 6" | awk '{printf("%d", $1/$2)}'`
    echo "CNT_USE: ${CNT_USE}"
    printf "*** too many annulus ***\n"
    printf "*** using ${CNTS_USE} per region ***\n"
    RIN=0
    ROUT=5
    j=1
    while [ $j -le 6 ] ; do
       while [ ${CNTS} -lt ${CNTS_USE} ] ; do
           ROUT=`expr ${ROUT} + 1 `
           if [ ${ROUT} -gt ${ROUT_MAX} ]; then
               break
           fi
           TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
           punlearn dmlist
           CNTS=`dmlist "${EVT}[energy=${ERANGE}][sky=${TMP_REG}]" blocks | \grep 'EVENTS' | awk '{print $8}'`
       done
       j=`expr $j + 1 `
       echo "${TMP_REG}" >> ${REG_OUT}
       RIN=$ROUT
       CNTS=0
    done
fi

printf "check SBP regions ...\n"
ds9 ${EVT} -regions format ciao -regions system physical \
    -regions ${REG_OUT} -cmap he -bin factor 4
