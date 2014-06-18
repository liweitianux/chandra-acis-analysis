#!/bin/sh

if [ $# -ne 6 ] ; then
   printf "usage:\n"
   printf " `basename $0` <evt> <evt_e> <bkg_pi> <x> <y>  <reg_out>\n"
   exit 1
fi

EVT=$1
EVT_E=$2
BKGSPC=$3
X=$4
Y=$5
REG_OUT=$6
[ -f "${REG_OUT}" ] && mv -fv ${REG_OUT} ${REG_OUT}_bak

echo "EVT:      ${EVT}"
echo "EVT_E:    ${EVT_E}"
echo "BKGSPC:   ${BKGSPC}"
echo "X:        ${X}"
echo "Y:        ${Y}"
echo ""

###
printf "## remove dmlist.par dmextract.par\n"
DMLIST_PAR="$HOME/cxcds_param4/dmlist.par"
DMEXTRACT_PAR="$HOME/cxcds_param4/dmextract.par"
[ -f "${DMLIST_PAR}" ] && rm -fv ${DMLIST_PAR}
[ -f "${DMEXTRACT_PAR}" ] && rm -fv ${DMEXTRACT_PAR}

#min counts
CNT_MIN=2500
#singal to noise
STN=10

#energy700:7000 -- channel 49:479
CH_LOW=49
CH_HI=479
#energy 9,5kev-12kev -- channel 651:822
CH_BKG_LOW=651
CH_BKG_HI=822

RIN=0
ROUT=0
CNTS=0
ROUT_MAX=1500

STN_FILE="spc_stn.dat"
[ -e ${STN_FILE} ] && mv -fv ${STN_FILE} ${STN_FILE}_bak
i=0
while [ `echo "$STN > 2 "| bc -l` -eq 1 ]  ; do
    ## LIweitiaNux
    if [ `echo "$ROUT > $ROUT_MAX" | bc -l` -eq 1 ]; then
        break
    fi
    RIN=${ROUT}
    if [ $i -gt 0 ]; then
        printf "  #$i: ${TMP_REG}\n"
        echo "${TMP_REG}" >> ${REG_OUT}
    fi
    i=`expr $i + 1`
    printf "gen reg#$i ...\n"
    if [ ${ROUT} -eq 0 ] ; then 
        ROUT=5
    fi
    TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
    CNTS=`dmlist "${EVT_E}[sky=${TMP_REG}]" blocks | grep 'EVENTS' | awk '{print $8}'`
    while [ ${CNTS} -lt ${CNT_MIN} ]; do
        ROUT=`expr $ROUT + 1 `
        if [ `echo "$ROUT > $ROUT_MAX" | bc -l` -eq 1 ]; then
            break
        fi
        TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
        CNTS=`dmlist "${EVT_E}[sky=${TMP_REG}]" blocks | grep 'EVENTS' | awk '{print $8}'`
    done
    TMP_SPC=_tmpspc.pi
    punlearn dmextract
    dmextract infile="${EVT}[sky=${TMP_REG}][bin pi]" outfile=${TMP_SPC} wmap="[energy=300:12000][bin tdet=8]" clobber=yes
    INDEX_SRC=`dmstat "${TMP_SPC}[channel=${CH_BKG_LOW}:${CH_BKG_HI}][cols counts]"  | grep "sum:" | awk '{print $2}' `
    INDEX_BKG=`dmstat "${BKGSPC}[channel=${CH_BKG_LOW}:${CH_BKG_HI}][cols counts]" | grep "sum:" | awk '{print $2}' `

    COUNT_SRC=`dmstat "${TMP_SPC}[channel=${CH_LOW}:${CH_HI}][cols counts]" | grep "sum:" | awk '{print $2}' `
    COUNT_BKG=`dmstat "${BKGSPC}[channel=${CH_LOW}:${CH_HI}][cols counts]" | grep "sum:" | awk '{print $2}' `
    if [ ${INDEX_SRC} -eq 0 ] ;then 
        STN=10000
    else
        STN=`echo ${COUNT_SRC} ${INDEX_SRC} ${COUNT_BKG} ${INDEX_BKG} | awk '{ printf("%f",$1/$2/$3*$4) }' `
    fi
    echo "  STN: ${STN}"
    echo "${STN}" >> "${STN_FILE}"
done
## LIweitiaNux
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
    CNTS_TOTAL=`dmlist "${EVT_E}[sky=pie($X,$Y,0,$RIN,0,360)]" blocks | grep 'EVENTS' | awk '{print $8}'`
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
           CNTS=`dmlist "${EVT_E}[sky=${TMP_REG}]" blocks | grep 'EVENTS' | awk '{print $8}'`
       done
       j=`expr $j + 1 `
       echo "${TMP_REG}" >> ${REG_OUT}
       RIN=$ROUT
       CNTS=0
    done
fi

