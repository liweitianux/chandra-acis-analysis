#!/bin/sh

full_path=`readlink -f $0`
base_dir=`dirname $full_path`

if [ $# -lt 2 ]; then
    printf "usage:\n"
    printf "    `basename $0` <cfg.list> [c] < 500 | 200 > ...\n"
    exit 1
fi

file_list="$1"
init_dir=`pwd -P`
pre_results="final_result.txt"

case "$2" in
    [cC]*)
        F_C="YES"
        shift
        ;;
    *)
        F_C="NO"
        ;;
esac

shift
echo "delta: $@"    # 'printf' not work

if [ "${F_C}" = "YES" ]; then
    printf "MODE: center\n"
fi

# exit

cat $file_list | while read line; do
    cd $init_dir
    obj_dir=`dirname $line`
    obj_cfg=`basename $line`
    cd $obj_dir
    pwd -P
    ##
    if [ ! -r "${obj_cfg}" ]; then
        printf "ERROR: global cfg not accessible\n"
    elif [ ! -r "${pre_results}" ]; then
        printf "ERROR: previous '${pre_results}' not accessible\n"
    else
        sbp_cfg=`grep '^sbp_cfg' $obj_cfg | awk '{ print $2 }'`
        ##
        for delta in $@; do
            if grep -q '^beta2' $sbp_cfg; then
                MODEL="dbeta"
            else
                MODEL="beta"
            fi
            rout=`grep "^r${delta}" ${pre_results} | sed -e 's/=/ /' | awk '{ print $2 }'`
            if [ "${F_C}" = "YES" ]; then
                lx_res="lx_result_${delta}_c.txt"
                fx_res="fx_result_${delta}_c.txt"
                CMD="$base_dir/calc_lx_${MODEL}.sh $obj_cfg $rout c"
            else
                lx_res="lx_result_${delta}.txt"
                fx_res="fx_result_${delta}.txt"
                CMD="$base_dir/calc_lx_${MODEL}.sh $obj_cfg $rout"
            fi
            [ -e "${lx_res}" ] && mv -f ${lx_res} ${lx_res}_bak
            [ -e "${fx_res}" ] && mv -f ${fx_res} ${fx_res}_bak
            ${CMD}
            mv -f lx_result.txt ${lx_res}
            mv -f fx_result.txt ${fx_res}
        done
    fi
done
