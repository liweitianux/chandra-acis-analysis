#!/bin/bash

echo $#
if [ $# -gt 0 ]
then
    :
else
    echo "Usage:$0 <cfg file> [c]"
    echo "If central value only, append a \"c\""
    exit
fi
export PGPLOT_FONT=`locate grfont.dat|head -1`

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
#initialize the rmin_kpc for nfw mass profile fitting
nfw_rmin_kpc=`grep '^nfw_rmin_kpc' $cfg_file|awk '{print $2}'`
#echo $t_profile_type
cm_per_pixel=`grep '^cm_per_pixel' $sbp_cfg|awk '{print $2}'`
da=`python -c "print($cm_per_pixel/(.492/3600/180*3.1415926))"`
#determine which temperature profile to be used, and fit the T profile
if [ $t_profile_type == wang2012 ]
then
    t_param_file=`grep t_param_file $cfg_file|awk '{print $2}'`
    $base_path/fit_wang2012_model $t_data_file $t_param_file $cm_per_pixel
    mv -f wang2012_dump.qdp ${T_file}
else
    echo temperature profile name invalid!
    exit
fi

cfunc_file=`grep '^cfunc_file' ${sbp_cfg} |awk '{print $2}'`
z=`grep  '^z' ${sbp_cfg}|awk '{print $2}'`
dl=`python -c "print($da*(1+$z)**2)"`
abund=`grep '^abund' ${cfg_file} |awk '{print $2}'`
nh=`grep '^nh' ${cfg_file} |awk '{print $2}'`
$base_path/coolfunc_calc_bolo.sh ${T_file} $abund $nh $z cfunc_bolo.dat
$base_path/coolfunc_calc.sh ${T_file} $abund $nh $z $cfunc_file
mv flux_cnt_ratio.txt flux_cnt_ratio_center.txt
#fit sbp
$base_path/fit_beta_sbp $sbp_cfg
$base_path/fit_nfw_mass mass_int.dat $z $nfw_rmin_kpc
echo $cfunc_file
#exit


#store central valu
mv sbp_fit.qdp sbp_fit_center.qdp
mv nfw_dump.qdp mass_int_center.qdp
mv overdensity.qdp overdensity_center.qdp
mv gas_mass_int.qdp gas_mass_int_center.qdp
mv nfw_param.txt nfw_param_center.qdp
mv beta_param.txt beta_param_center.txt
mv rho_fit.dat rho_fit_center.dat


#calculate cooling time
echo $dl

$base_path/cooling_time rho_fit_center.dat $T_file cfunc_bolo.dat $dl $cm_per_pixel >cooling_time.dat

sbp_data_file=`grep sbp_file $sbp_cfg|awk '{print $2}'`
radius_sbp_file=`grep radius_sbp_file ${cfg_file}|awk '{print $2}'`

if [ x"$radius_sbp_file" == x ]
then
    echo "Error, must have radius_sbp_file assigned, this file should be a 4-column file, which contains the radius, radius err, sbp, and sbp err"
    exit
fi

cat ${radius_sbp_file} | sed 's/#.*$//' | grep -Ev '^\s*$' > .tmp.txt
mv .tmp.txt ${radius_sbp_file}


#radius to calculate tcool, not the cooling time!
rcool=`$base_path/analyze_mass_profile.py 500 c|grep ^r500|awk -F "=" '{print .048*$2}'`

if [ $# -eq 2 ]
then
    rm -f center_only_results.txt
    $base_path/analyze_mass_profile.py 200 c |tee -a center_only_results.txt
    $base_path/analyze_mass_profile.py 500 c |tee -a center_only_results.txt
    $base_path/analyze_mass_profile.py 1500 c |tee -a center_only_results.txt
    $base_path/analyze_mass_profile.py 2500 c |tee -a center_only_results.txt
    $base_path/extract_tcool.py $rcool |tee -a center_only_results.txt
    $base_path/fg_2500_500.py c |tee -a center_only_results.txt
    exit
fi



rm -f summary_shuffle_mass_profile.qdp
rm -f summary_overdensity.qdp
rm -f summary_mass_profile.qdp
rm -f summary_gas_mass_profile.qdp

#100 times of Monte-carlo simulation to determine error
#just repeat above steps
for i in `seq 1 100`
do
    echo $t_data_file
    $base_path/shuffle_T.py $t_data_file temp_shuffled_t.dat
    $base_path/shuffle_sbp.py $sbp_data_file temp_shuffled_sbp.dat
    #t_data_file=temp_shuffled_t.dat
#exit
    if [ $t_profile_type == wang2012 ]
    then
	t_param_file=`grep t_param_file $cfg_file|awk '{print $2}'`
	$base_path/fit_wang2012_model temp_shuffled_t.dat $t_param_file $cm_per_pixel
	mv -f wang2012_dump.qdp ${T_file}
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

$base_path/coolfunc_calc.sh ${T_file} $abund $nh $z $cfunc_file

$base_path/fit_beta_sbp temp_sbp.cfg
$base_path/fit_nfw_mass mass_int.dat $z $nfw_rmin_kpc
cat nfw_dump.qdp >>summary_mass_profile.qdp
echo no no no >>summary_mass_profile.qdp

cat overdensity.qdp >>summary_overdensity.qdp
echo no no no >>summary_overdensity.qdp

cat gas_mass_int.qdp >>summary_gas_mass_profile.qdp
echo no no no >>summary_gas_mass_profile.qdp
done
#analys the errors
$base_path/analyze_mass_profile.py 200
$base_path/analyze_mass_profile.py 500
$base_path/analyze_mass_profile.py 1500
$base_path/analyze_mass_profile.py 2500

r500=`$base_path/analyze_mass_profile.py 500|grep r500|awk '{print $2}'`
#$base_path/calc_lx $radius_sbp_file flux_cnt_ratio_center.txt $z $r500 $t_data_file
r200=`$base_path/analyze_mass_profile.py 200|grep r200|awk '{print $2}'`
r1500=`$base_path/analyze_mass_profile.py 1500|grep r1500|awk '{print $2}'`
r2500=`$base_path/analyze_mass_profile.py 2500|grep r2500|awk '{print $2}'`
#$base_path/calc_lx $radius_sbp_file flux_cnt_ratio_center.txt $z $r200 $t_data_file

r500e=`$base_path/analyze_mass_profile.py 500|grep '^r500' 2>/dev/null|awk '{print $2,$3}'`
m500e=`$base_path/analyze_mass_profile.py 500|grep '^m500' 2>/dev/null|awk '{print $2,$3}'`
L500=`$base_path/calc_lx $radius_sbp_file flux_cnt_ratio_center.txt $z $r500 Tprofile.dat 2>/dev/null|awk '{print $2,$3,$4}'`
mg500e=`$base_path/analyze_mass_profile.py 500|grep '^gas_m' 2>/dev/null|awk '{print $2,$3}'`
fg500e=`$base_path/analyze_mass_profile.py 500|grep '^gas_fraction' 2>/dev/null|awk '{print $2,$3}'`


r200e=`$base_path/analyze_mass_profile.py 200|grep '^r200' 2>/dev/null|awk '{print $2,$3}'`
m200e=`$base_path/analyze_mass_profile.py 200|grep '^m200' 2>/dev/null|awk '{print $2,$3}'`
L200=`$base_path/calc_lx $radius_sbp_file flux_cnt_ratio_center.txt $z $r200 Tprofile.dat 2>/dev/null|awk '{print $2,$3,$4}'`
mg200e=`$base_path/analyze_mass_profile.py 200|grep '^gas_m' 2>/dev/null|awk '{print $2,$3}'`
fg200e=`$base_path/analyze_mass_profile.py 200|grep '^gas_fraction' 2>/dev/null|awk '{print $2,$3}'`

r2500e=`$base_path/analyze_mass_profile.py 2500|grep '^r2500' 2>/dev/null|awk '{print $2,$3}'`
m2500e=`$base_path/analyze_mass_profile.py 2500|grep '^m2500' 2>/dev/null|awk '{print $2,$3}'`
L2500=`$base_path/calc_lx $radius_sbp_file flux_cnt_ratio_center.txt $z $r2500 Tprofile.dat 2>/dev/null|awk '{print $2,$3,$4}'`
mg2500e=`$base_path/analyze_mass_profile.py 2500|grep '^gas_m' 2>/dev/null|awk '{print $2,$3}'`
fg2500e=`$base_path/analyze_mass_profile.py 2500|grep '^gas_fraction' 2>/dev/null|awk '{print $2,$3}'`

r1500e=`$base_path/analyze_mass_profile.py 1500|grep '^r1500' 2>/dev/null|awk '{print $2,$3}'`
m1500e=`$base_path/analyze_mass_profile.py 1500|grep '^m1500' 2>/dev/null|awk '{print $2,$3}'`
L1500=`$base_path/calc_lx $radius_sbp_file flux_cnt_ratio_center.txt $z $r1500 Tprofile.dat 2>/dev/null|awk '{print $2,$3,$4}'`
mg1500e=`$base_path/analyze_mass_profile.py 1500|grep '^gas_m' 2>/dev/null|awk '{print $2,$3}'`
fg1500e=`$base_path/analyze_mass_profile.py 1500|grep '^gas_fraction' 2>/dev/null|awk '{print $2,$3}'`



echo "******************"
echo "Final results:"
echo "******************"
echo 
echo 

rm -f final_result.txt
echo r500= $r500e  kpc |tee -a final_result.txt
echo m500= $m500e M_sun |tee -a final_result.txt
echo L500= $L500 erg/s |tee -a final_result.txt
echo gas mass 500= $mg500e M_sun |tee -a final_result.txt
echo gas fractho 500= $fg500e x100% |tee -a final_result.txt

echo r200= $r200e kpc |tee -a final_result.txt
echo m200= $m200e M_sun |tee -a final_result.txt
echo L200= $L200 erg/s |tee -a final_result.txt
echo gas mass 200= $mg200e M_sun |tee -a final_result.txt
echo gas fractho 200= $fg200e x100% |tee -a final_result.txt

echo r1500= $r1500e kpc |tee -a final_result.txt
echo m1500= $m1500e M_sun |tee -a final_result.txt
echo L1500= $L1500 erg/s |tee -a final_result.txt
echo gas mass 1500= $mg1500e M_sun |tee -a final_result.txt
echo gas fractho 1500= $fg1500e x100% |tee -a final_result.txt

echo r2500= $r2500e kpc |tee -a final_result.txt
echo m2500= $m2500e M_sun |tee -a final_result.txt
echo L2500= $L2500 erg/s |tee -a final_result.txt
echo gas mass 2500= $mg2500e M_sun |tee -a final_result.txt
echo gas fractho 2500= $fg2500e x100% |tee -a final_result.txt

$base_path/extract_tcool.py $rcool |tee -a final_result.txt
$base_path/fg_2500_500.py |tee -a final_result.txt
