#!/bin/bash

echo $#
if [ $# -eq 2 ]
then
    :
else
    echo "Usage:$0 <cfg file> <radius in kpc>"
    exit
fi
export PGPLOT_FONT=`locate grfont.dat|head -1`

mkdir -p entropy_files

cfg_file=$1
base_path=`dirname $0`
echo $base_path
#initialize profile type name
t_profile_type=`grep t_profile $cfg_file|awk '{print $2}'`
#initialize data file name
t_data_file=`grep t_data_file $cfg_file|awk '{print $2}'`
#initialize sbp config file
sbp_cfg=`grep sbp_cfg $cfg_file|awk '{print $2}'`
#initialize the temperature profile file
T_file=`grep '^T_file' $sbp_cfg|awk '{print $2}'`
#echo $t_profile_type
cm_per_pixel=`grep '^cm_per_pixel' $sbp_cfg|awk '{print $2}'`

#determine which temperature profile to be used, and fit the T profile
if [ $t_profile_type == zyy ]
then
    t_param_file=`grep t_param_file $cfg_file|awk '{print $2}'`
    $base_path/fit_zyy_model $t_data_file $t_param_file $cm_per_pixel
    mv -f zyy_dump.qdp ${T_file}
elif [ $t_profile_type == m0603246 ]
then
    $base_path/fit_m0603246 $t_data_file $cm_per_pixel
    mv -f m0603246_dump.qdp ${T_file}
elif [ $t_profile_type == wang2012 ]
then
    t_param_file=`grep t_param_file $cfg_file|awk '{print $2}'`
    $base_path/fit_wang2012_model $t_data_file $t_param_file $cm_per_pixel
    mv -f wang2012_dump.qdp ${T_file}
elif [ $t_profile_type == allen ]
then
    $base_path/fit_allen_model $t_data_file $cm_per_pixel
    mv -f allen_dump.qdp ${T_file}
elif [ $t_profile_type == zzl ]
then
    t_param_file=`grep t_param_file $cfg_file|awk '{print $2}'`
    $base_path/fit_zzl_model $t_data_file $t_param_file
    mv -f zzl_dump.qdp ${T_file}
else
    echo temperature profile name invalid!
    exit
fi

cfunc_file=`grep '^cfunc_file' ${sbp_cfg} |awk '{print $2}'`
z=`grep  '^z' ${sbp_cfg}|awk '{print $2}'`
abund=`grep '^abund' ${cfg_file} |awk '{print $2}'`
nh=`grep '^nh' ${cfg_file} |awk '{print $2}'`
$base_path/coolfunc_calc.sh ${T_file} $abund $nh $z $cfunc_file
mv flux_cnt_ratio.txt flux_cnt_ratio_center_entropy.txt
#fit sbp
$base_path/fit_beta_sbp $sbp_cfg
echo $cfunc_file
#exit

#store central valu
mv sbp_fit.qdp sbp_fit_center_entropy.qdp
mv mass_int.qdp mass_int_center_entropy.qdp
mv overdensity.qdp overdensity_center_entropy.qdp
mv gas_mass_int.qdp gas_mass_int_center_entropy.qdp
mv entropy.qdp entropy_center.qdp
sbp_data_file=`grep sbp_file $sbp_cfg|awk '{print $2}'`
radius_sbp_file=`grep radius_sbp_file ${cfg_file}|awk '{print $2}'`

if [ x"$radius_sbp_file" == x ]
then
    echo "Error, must have radius_sbp_file assigned, this file should be a 4-column file, which contains the radius, radius err, sbp, and sbp err"
    exit
fi

cat ${radius_sbp_file} | sed 's/#.*$//' | grep -Ev '^\s*$' > .tmp.txt
mv .tmp.txt ${radius_sbp_file}

rm -f summary_entropy.qdp
#100 times of Monte-carlo simulation to determine error
#just repeat above steps
for i in `seq 1 100`
do
    echo $t_data_file
    $base_path/shuffle_T.py $t_data_file temp_shuffled_t.dat
    $base_path/shuffle_sbp.py $sbp_data_file temp_shuffled_sbp.dat
    
#exit
    if [ $t_profile_type == zyy ]
    then
	t_param_file=`grep t_param_file $cfg_file|awk '{print $2}'`
	$base_path/fit_zyy_model temp_shuffled_t.dat $t_param_file $cm_per_pixel
	mv -f zyy_dump.qdp ${T_file}
    elif [ $t_profile_type == m0603246 ]
    then
	$base_path/fit_m0603246 temp_shuffled_t.dat $cm_per_pixel
	mv -f m0603246_dump.qdp ${T_file}
    elif [ $t_profile_type == wang2012 ]
    then
	t_param_file=`grep t_param_file $cfg_file|awk '{print $2}'`
	$base_path/fit_wang2012_model temp_shuffled_t.dat $t_param_file $cm_per_pixel
    mv -f wang2012_dump.qdp ${T_file}
    elif [ $t_profile_type == allen ]
    then
	$base_path/fit_allen_model temp_shuffled_t.dat $cm_per_pixel
	mv -f allen_dump.qdp ${T_file}
    elif [ $t_profile_type == zzl ]
    then
	t_param_file=`grep t_param_file $cfg_file|awk '{print $2}'`
    $base_path/fit_zzl_model temp_shuffled_t.dat $t_param_file
    mv -f zzl_dump.qdp ${T_file}
    else
	echo temperature profile name invalid!
	exit
    fi
    
#exit
    echo >temp_sbp.cfg
    
    cat $sbp_cfg|while read l
do
    if echo $l|grep sbp_file >/dev/null
    then
	echo sbp_file temp_shuffled_sbp.dat >>temp_sbp.cfg
    elif echo $l|grep T_file >/dev/null
    then
	echo T_file ${T_file} >>temp_sbp.cfg
    else
	echo $l >>temp_sbp.cfg
    fi
    
done

#$base_path/coolfunc_calc.sh ${T_file} $abund $nh $z $cfunc_file

$base_path/fit_beta_sbp temp_sbp.cfg

cat entropy.qdp >>summary_entropy.qdp
echo no no no >>summary_entropy.qdp
done

$base_path/analyze_entropy_profile.py $2 |tee entropy_result.txt
