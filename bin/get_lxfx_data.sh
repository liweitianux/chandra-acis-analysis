#!/bin/sh
#
# collect data for 'loop_lx.sh' & 'calc_lxfx_simple.sh'
#

if [ $# -lt 2 ]; then
    printf "usage:\n"
    printf "    `basename $0` <dir> [c] <delta ...>\n"
    exit 1
fi

DIR="$1"
shift
case "$1" in
    [cC]*)
        F_C="YES"
        shift
        ;;
    *)
        F_C="NO"
        ;;
esac
printf "CENTER_MODE: $F_C\n"
echo "DELTA: $@"

cd $DIR
pwd -P

INFO=`ls ../*_INFO.json 2> /dev/null`
if [ ! -z "$INFO" ]; then
    OI=`grep '"Obs\.\ ID' ${INFO} | sed 's/.*"Obs.*":\ //' | sed 's/\ *,$//'`
    NAME=`grep '"Source\ Name' ${INFO} | sed 's/.*"Source.*":\ //' | sed 's/^"//' | sed 's/"\ *,$//'`
    UNAME=`grep '"Unified\ Name' ${INFO} | sed 's/.*"Unified.*":\ //' | sed 's/^"//' | sed 's/"\ *,$//'`
    Z=`grep '"redshift' ${INFO} | sed 's/.*"redshift.*":\ //' | sed 's/\ *,$//'`
fi

printf "# OI,NAME,UNAME,Z"
if [ "${F_C}" = "YES" ]; then
    for DELTA in $@; do
        printf ",L${DELTA}(bolo),L${DELTA}(0.7-7),L${DELTA}(0.1-2.4),F${DELTA}(bolo),F${DELTA}(0.7-7),F${DELTA}(0.1-2.4)"
    done
    printf "\n"
else
    for DELTA in $@; do
        printf ",L${DELTA}(bolo),L${DELTA}ERR(bolo),L${DELTA}(0.7-7),L${DELTA}ERR(0.7-7),L${DELTA}(0.1-2.4),L${DELTA}ERR(0.1-2.4),F${DELTA}(bolo),F${DELTA}ERR(bolo),F${DELTA}(0.7-7),F${DELTA}ERR(0.7-7),F${DELTA}(0.1-2.4),F${DELTA}ERR(0.1-2.4)"
    done
    printf "\n"
fi

printf "# $OI,$NAME,$UNAME,$Z"

if [ "${F_C}" = "YES" ]; then
    for DELTA in $@; do
        LX_RES="lx_result_${DELTA}_c.txt"
        FX_RES="fx_result_${DELTA}_c.txt"
        if [ -r ${LX_RES} ] && [ -r ${FX_RES} ]; then
            Lbolo=`grep '^Lx(bolo' ${LX_RES} | awk '{ print $2 }'`
            L077=`grep '^Lx(0\.7-7' ${LX_RES} | awk '{ print $2 }'`
            L0124=`grep '^Lx(0\.1-2\.4' ${LX_RES} | awk '{ print $2 }'`
            Fbolo=`grep '^Fx(bolo' ${FX_RES} | awk '{ print $2 }'`
            F077=`grep '^Fx(0\.7-7' ${FX_RES} | awk '{ print $2 }'`
            F0124=`grep '^Fx(0\.1-2\.4' ${FX_RES} | awk '{ print $2 }'`
            printf ",$Lbolo,$L077,$L0124,$Fbolo,$F077,$F0124"
        fi
    done
    printf "\n"
else
    for DELTA in $@; do
        LX_RES="lx_result_${DELTA}.txt"
        FX_RES="fx_result_${DELTA}.txt"
        if [ -r ${LX_RES} ] && [ -r ${FX_RES} ]; then
            Lbolo=`grep '^Lx(bolo' ${LX_RES} | awk '{ print $2 }'`
            LboloERR=`grep '^Lx(bolo' ${LX_RES} | awk '{ print $4 }'`
            L077=`grep '^Lx(0\.7-7' ${LX_RES} | awk '{ print $2 }'`
            L077ERR=`grep '^Lx(0\.7-7' ${LX_RES} | awk '{ print $4 }'`
            L0124=`grep '^Lx(0\.1-2\.4' ${LX_RES} | awk '{ print $2 }'`
            L0124ERR=`grep '^Lx(0\.1-2\.4' ${LX_RES} | awk '{ print $4 }'`
            Fbolo=`grep '^Fx(bolo' ${FX_RES} | awk '{ print $2 }'`
            FboloERR=`grep '^Fx(bolo' ${FX_RES} | awk '{ print $4 }'`
            F077=`grep '^Fx(0\.7-7' ${FX_RES} | awk '{ print $2 }'`
            F077ERR=`grep '^Fx(0\.7-7' ${FX_RES} | awk '{ print $4 }'`
            F0124=`grep '^Fx(0\.1-2\.4' ${FX_RES} | awk '{ print $2 }'`
            F0124ERR=`grep '^Fx(0\.1-2\.4' ${FX_RES} | awk '{ print $4 }'`
            printf ",$Lbolo,$LboloERR,$L077,$L077ERR,$L0124,$L0124ERR,$Fbolo,$FboloERR,$F077,$F077ERR,$F0124,$F0124ERR"
        fi
    done
    printf "\n"
fi

