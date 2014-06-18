#!/bin/sh
#
# v2.0, 2013/03/06, LIweitiaNux
#   add param `-t' to test STN
#
###########################################################

# minimal counts
CNT_MIN=50
# energy: 700-7000eV -- channel 49:479
CH_LOW=49
CH_HI=479
# energy 9.5-12keV -- channel 651:822
CH_BKG_LOW=651
CH_BKG_HI=822

if [ $# -lt 6 ]; then
    printf "usage:\n"
    printf "    `basename $0` <evt> <evt_e> <x> <y> <bkg_pi> <reg_out>\n"
    printf "    `basename $0` -t <evt> <evt_e> <x> <y> <bkg_pi> <rin1> ...\n"
    exit 1
fi

if [ "x$1" = "x-t" ] && [ $# -ge 7 ]; then
    EVT=$2
    EVT_E=$3
    X=$4
    Y=$5
    BKGSPC=$6
    # process <rin> ...
    printf "REG -- STN\n"
    while [ ! -z "$7" ]; do
        RIN=$7
        shift
        ROUT=`echo "scale=2; $RIN * 1.2" | bc -l`
        TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
        TMP_SPC="_tmpspc.pi"
        punlearn dmextract
        dmextract infile="${EVT}[sky=${TMP_REG}][bin pi]" outfile=${TMP_SPC} wmap="[energy=300:12000][bin det=8]" clobber=yes
        INDEX_SRC=`dmstat "${TMP_SPC}[channel=${CH_BKG_LOW}:${CH_BKG_HI}][cols counts]" | grep "sum:" | awk '{print $2}'`
        INDEX_BKG=`dmstat "${BKGSPC}[channel=${CH_BKG_LOW}:${CH_BKG_HI}][cols counts]" | grep "sum:" | awk '{print $2}'`
        COUNT_SRC=`dmstat "${TMP_SPC}[channel=${CH_LOW}:${CH_HI}][cols counts]" | grep "sum:" | awk '{print $2}'`
        COUNT_BKG=`dmstat "${BKGSPC}[channel=${CH_LOW}:${CH_HI}][cols counts]" | grep "sum:" | awk '{print $2}'`
        # echo "CNT_SRC: ${COUNT_SRC}, IDX_SRC: ${INDEX_SRC}, CNT_BKG: ${COUNT_BKG}, IDX_BKG: ${INDEX_BKG}"
        # exit
        STN=`echo ${COUNT_SRC} ${INDEX_SRC} ${COUNT_BKG} ${INDEX_BKG} | awk '{ printf("%f",$1/$2/$3*$4) }'`
        printf "${TMP_REG} -- ${STN}\n"
        [ -e "${TMP_SPC}" ] && rm -f ${TMP_SPC}
    done
    # exit
    exit 0
fi

EVT=$1
EVT_E=$2
X=$3
Y=$4
BKGSPC=$5
REG_OUT=$6
[ -f "${REG_OUT}" ] && mv -fv ${REG_OUT} ${REG_OUT}_bak
echo "EVT:      ${EVT}"
echo "EVT_E:    ${EVT_E}"
echo "X:        ${X}"
echo "Y:        ${Y}"
echo "BKGSPC:   ${BKGSPC}"
echo ""

###
printf "## remove dmlist.par dmextract.par\n"
DMLIST_PAR="$HOME/cxcds_param4/dmlist.par"
DMEXTRACT_PAR="$HOME/cxcds_param4/dmextract.par"
[ -f "${DMLIST_PAR}" ] && rm -f ${DMLIST_PAR}
[ -f "${DMEXTRACT_PAR}" ] && rm -f ${DMEXTRACT_PAR}

RIN=0
ROUT=0
CNTS=0
for i in `seq 1 10`; do
    printf "gen reg #$i @ cnts:${CNT_MIN} ...\n"
    ROUT=`expr $RIN + 5`
    TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
    CNTS=`dmlist "${EVT_E}[sky=${TMP_REG}]" blocks | grep 'EVENTS' | awk '{ print $8 }'`
    while [ `echo "$CNTS < $CNT_MIN" | bc -l` -eq 1 ]; do
        ROUT=`expr $ROUT + 1`
        TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
        CNTS=`dmlist "${EVT_E}[sky=${TMP_REG}]" blocks | grep 'EVENTS' | awk '{ print $8 }'`
    done
    TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
    echo "${TMP_REG}" >> ${REG_OUT}
    RIN=$ROUT
done

# last reg width
#REG_W=`tail -n 1 ${REG_OUT} | tr -d '()' | awk -F',' '{ print $4-$3 }'`

RIN=$ROUT
ROUT=`echo "scale=2; $ROUT * 1.2" | bc -l`

STN=10
i=11
STN_FILE="sbp_stn.dat"
[ -e ${STN_FILE} ] && mv -fv ${STN_FILE} ${STN_FILE}_bak
while [ `echo "${STN} > 1.5" | bc -l` -eq 1 ]; do
    printf "gen reg #$i \n"
    i=`expr $i + 1`
    TMP_REG="pie($X,$Y,$RIN,$ROUT,0,360)"
   
    # next reg
    RIN=$ROUT
    ROUT=`echo "scale=2; $ROUT * 1.2" | bc -l`
    TMP_SPC=_tmpspc.pi
    punlearn dmextract
    dmextract infile="${EVT}[sky=${TMP_REG}][bin pi]" outfile=${TMP_SPC} wmap="[energy=300:12000][bin det=8]" clobber=yes
    INDEX_SRC=`dmstat "${TMP_SPC}[channel=${CH_BKG_LOW}:${CH_BKG_HI}][cols counts]" | grep "sum:" | awk '{print $2}'`
    INDEX_BKG=`dmstat "${BKGSPC}[channel=${CH_BKG_LOW}:${CH_BKG_HI}][cols counts]" | grep "sum:" | awk '{print $2}'`

    COUNT_SRC=`dmstat "${TMP_SPC}[channel=${CH_LOW}:${CH_HI}][cols counts]" | grep "sum:" | awk '{print $2}'`
    COUNT_BKG=`dmstat "${BKGSPC}[channel=${CH_LOW}:${CH_HI}][cols counts]" | grep "sum:" | awk '{print $2}'`

    # echo "CNT_SRC: ${COUNT_SRC}, IDX_SRC: ${INDEX_SRC}, CNT_BKG: ${COUNT_BKG}, IDX_BKG: ${INDEX_BKG}"
    # exit

    STN=`echo ${COUNT_SRC} ${INDEX_SRC} ${COUNT_BKG} ${INDEX_BKG} | awk '{ printf("%f",$1/$2/$3*$4) }'`
    CNT=`dmlist "${EVT_E}[sky=${TMP_REG}]" blocks | grep 'EVENTS' | awk '{ print $8 }'`
    echo "CNT: ${CNT}"
    echo "CNT_MIN: ${CNT_MIN}"
    if [ `echo "${CNT} < ${CNT_MIN}" | bc -l` -eq 1 ]; then 
        break
    fi
    echo "STN: ${STN}"
    echo "RIN: ${RIN}, ROUT: ${ROUT}" 
    echo "STN: ${STN}" >> ${STN_FILE}
    echo "${TMP_REG}" >> ${REG_OUT}
done

