#!/bin/bash
origin_point=$PWD
ZERO=`readlink -f $0`
basedir=`dirname $ZERO`

for i in `cat list.txt`
do
#    echo $i
    file_path=`dirname $i`
    cd $file_path
    mkdir -p center_results
    cp global.cfg center_results
    t_data_file=`grep ^t_data_file global.cfg|awk '{print $2}'`
    t_param_file=`grep ^t_param_file global.cfg|awk '{print $2}'`
    sbp_cfg=`grep ^sbp_cfg global.cfg|awk '{print $2}'`
    cm_per_pixel=`grep '^cm_per_pixel' $sbp_cfg|awk '{print $2}'`
    radius_sbp_file=`grep '^radius_sbp_file' global.cfg|awk '{print $2}'`
    radius_file=`grep '^radius_file' $sbp_cfg|awk '{print $2}'`
    sbp_file=`grep '^sbp_file' $sbp_cfg|awk '{print $2}'`
    cfunc_file=`grep '^cfunc_file' $sbp_cfg|awk '{print $2}'`
    T_file=`grep '^T_file' $sbp_cfg |awk  '{print $2}'`

    cp $t_data_file $t_param_file $sbp_cfg $radius_sbp_file $radius_file $sbp_file $cfunc_file center_results
    cd center_results
    nh=`grep '^nh' global.cfg |awk '{print $2}'`
    z=`grep  '^z' ${sbp_cfg}|awk '{print $2}'`
    abund=`grep '^abund' global.cfg |awk '{print $2}'`
    
    $basedir/fit_wang2012_model $t_data_file $t_param_file $cm_per_pixel
    #echo $t_param_file
    mv wang2012_dump.qdp wang2012_center_dump.qdp
    cp -f wang2012_center_dump.qdp t_profile_dump.qdp
    $basedir/coolfunc_calc.sh wang2012_center_dump.qdp $abund $nh $z cfunc.dat
    if grep '^beta2' ${sbp_cfg}
    then
	$basedir/fit_dbeta_sbp $sbp_cfg
	mv dbeta_param.txt sbp_param_center.txt
    else
	$basedir/fit_beta_sbp $sbp_cfg
	mv beta_param.txt sbp_param_center.txt
    fi

    $basedir/fit_nfw_mass mass_int.dat $z >nfw_param_center.txt
    
    cd $origin_point
done
