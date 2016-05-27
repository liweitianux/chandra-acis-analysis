#!/bin/sh
#

if [ $# -eq 1 ]; then
    :
elif [ $# -eq 2 ]; then
    CENTER_VALUE="YES"
else
    printf "usage: $0 <mass_conf> [c]\n"
    exit 1
fi
cfg_file=$1
if [ "$0" = `basename $0` ]; then
    script_path=`which $0`
    base_path=`dirname ${script_path}`
else
    base_path=`dirname $0`
fi

sbp_cfg=`grep '^sbp_cfg' $cfg_file | awk '{ print $2 }'`

if grep -q '^beta2' $sbp_cfg; then
    MODEL="double-beta"
    PROG=fit_nfwmass_dbeta.sh
else
    MODEL="single-beta"
    PROG=fit_nfwmass_beta.sh
fi

printf "## MODEL: ${MODEL}\n"
if [ "x${CENTER_VALUE}" = "xYES" ]; then
    $base_path/$PROG $cfg_file c
else
    $base_path/$PROG $cfg_file
fi

