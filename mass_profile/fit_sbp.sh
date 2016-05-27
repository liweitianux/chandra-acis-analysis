#!/bin/sh
#

if [ $# -ne 1 ]; then
    printf "usage: $0 <mass_conf>\n"
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
t_data_file=`grep '^t_data_file' $cfg_file | awk '{ print $2 }'`
t_param_file=`grep '^t_param_file' $cfg_file | awk '{ print $2 }'`
nh=`grep '^nh' $cfg_file | awk '{ print $2 }'`
abund=`grep '^abund' $cfg_file | awk '{ print $2 }'`
z=`grep '^z' $sbp_cfg | awk '{ print $2 }'`
cm_per_pixel=`${base_path}/calc_distance ${z} | grep 'cm_per_pixel' | awk '{ print $2 }'`
sed -i'' "s/^cm_per_pixel.*$/cm_per_pixel    ${cm_per_pixel}/" ${sbp_cfg}
cfunc_file=`grep '^cfunc_file' $sbp_cfg | awk '{ print $2 }'`
T_file=`grep '^T_file' $sbp_cfg | awk '{ print $2 }'`

if grep -q '^beta2' $sbp_cfg; then
    MODEL="double-beta"
    PROG=fit_dbeta_sbp
else
    MODEL="single-beta"
    PROG=fit_beta_sbp
fi

$base_path/fit_wang2012_model $t_data_file $t_param_file $cm_per_pixel 2> /dev/null
cp wang2012_dump.qdp $T_file
if [ ! -f ${cfunc_file} ]; then
    $base_path/coolfunc_calc2.sh $T_file $abund $nh $z $cfunc_file
fi
$base_path/$PROG $sbp_cfg
printf "## MODEL: ${MODEL}\n"
printf "## z: ${z}\n"

