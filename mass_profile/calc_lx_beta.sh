#!/bin/sh

echo "### \$#: $#"
echo "### `pwd -P`"
if [ $# -gt 1 ]
then
    :
else
    echo "Usage:$0 <cfg file> <rout in kpc> [c]"
    echo "If central value only, append a \"c\""
    exit
fi
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export PGPLOT_FONT="${HEADAS}/lib/grfont.dat"

# blist file
# (energy bands to calc cooling function data)
BLIST="blist.txt"
[ -e "${BLIST}" ] && mv -f ${BLIST} ${BLIST}_bak
cat > ${BLIST} << _EOF_
bolo
0.7 7
0.1 2.4
_EOF_

cfg_file=$1
rout=$2
base_path=`dirname $0`
echo $base_path
#initialize sbp config file
sbp_cfg=`grep '^sbp_cfg' $cfg_file|awk '{print $2}'`
#initialize profile type name
t_profile_type=`grep '^t_profile' $cfg_file|awk '{print $2}'`
#initialize data file name
t_data_file=`grep '^t_data_file' $cfg_file|awk '{print $2}'`
#initialize sbp data file
sbp_data_file=`grep '^sbp_file' $sbp_cfg | awk '{ print $2 }'`
#initialize the temperature profile file
T_file=`grep '^T_file' $sbp_cfg|awk '{print $2}'`
#initialize the rmin_kpc for nfw mass profile fitting
nfw_rmin_kpc=`grep '^nfw_rmin_kpc' $cfg_file|awk '{print $2}'`
#echo $t_profile_type
cm_per_pixel=`grep '^cm_per_pixel' $sbp_cfg|awk '{print $2}'`
da=`python -c "print($cm_per_pixel/(.492/3600/180*3.1415926))"`

#determine which temperature profile to be used, and fit the T profile
if [ "$t_profile_type" = "wang2012" ]; then
    t_param_file=`grep t_param_file $cfg_file|awk '{print $2}'`
    $base_path/fit_wang2012_model $t_data_file $t_param_file $cm_per_pixel 2> /dev/null
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
$base_path/coolfunc_calc.sh ${T_file} $abund $nh $z $cfunc_file
#$base_path/coolfunc_calc_bolo.sh ${T_file} $abund $nh $z cfunc_bolo.dat
#$base_path/coolfunc_calc_0.7-7.sh ${T_file} $abund $nh $z cfunc_0.7-7.dat
#$base_path/coolfunc_calc_0.1-2.4.sh ${T_file} $abund $nh $z cfunc_0.1-2.4.dat
$base_path/coolfunc_calc_erg.sh ${T_file} $abund $nh $z "cfunc_" ${BLIST}
mv flux_cnt_ratio.txt flux_cnt_ratio_center.txt
#fit sbp
prog="calc_lx_beta"
lx_res="lx_beta_param.txt"
$base_path/${prog} $sbp_cfg  $rout cfunc_bolo.dat cfunc_0.7-7.dat cfunc_0.1-2.4.dat 2> /dev/null
LX1=`grep 'Lx1' $lx_res |awk '{print $2}'` 
LX2=`grep 'Lx2' $lx_res |awk '{print $2}'` 
LX3=`grep 'Lx3' $lx_res |awk '{print $2}'` 
FX1=`grep 'Fx1' $lx_res |awk '{print $2}'` 
FX2=`grep 'Fx2' $lx_res |awk '{print $2}'` 
FX3=`grep 'Fx3' $lx_res |awk '{print $2}'` 

echo $LX1 $LX2 $LX3 >summary_lx.dat
echo $FX1 $FX2 $FX3 >summary_fx.dat
echo $cfunc_file
#exit

#store central value
mv ${lx_res} ${lx_res%.txt}_center.txt
mv lx_sbp_fit.qdp lx_sbp_fit_center.qdp
mv lx_rho_fit.dat lx_rho_fit_center.dat

#rm -f summary_lx.dat
#calculate cooling time
#echo $dl

## calculate center values
if [ $# -eq 3 ]; then
    $base_path/analyze_lx.py
    $base_path/analyze_fx.py
    exit 0
fi


###########################################################
#100 times of Monte-carlo simulation to determine error
#just repeat above steps
for i in `seq 1 100`; do
    echo $t_data_file
    $base_path/shuffle_T.py $t_data_file temp_shuffled_t.dat
    $base_path/shuffle_sbp.py $sbp_data_file temp_shuffled_sbp.dat
    #t_data_file=temp_shuffled_t.dat
    #exit

    if [ "$t_profile_type" = "wang2012" ]; then
	t_param_file=`grep t_param_file $cfg_file|awk '{print $2}'`
	$base_path/fit_wang2012_model temp_shuffled_t.dat $t_param_file $cm_per_pixel 2> /dev/null
	mv -f wang2012_dump.qdp ${T_file}
    else
	echo temperature profile name invalid!
	exit
    fi

    echo >temp_sbp.cfg
    
    cat $sbp_cfg | while read l; do
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

    #exit

    echo "### `pwd -P`"
    echo "### $i ###"

    $base_path/coolfunc_calc.sh ${T_file} $abund $nh $z $cfunc_file
    #$base_path/coolfunc_calc_bolo.sh ${T_file} $abund $nh $z cfunc_bolo.dat
    #$base_path/coolfunc_calc_0.7-7.sh ${T_file} $abund $nh $z cfunc_0.7-7.dat
    #$base_path/coolfunc_calc_0.1-2.4.sh ${T_file} $abund $nh $z cfunc_0.1-2.4.dat
    $base_path/coolfunc_calc_erg.sh ${T_file} $abund $nh $z "cfunc_" ${BLIST}
    $base_path/$prog temp_sbp.cfg $rout cfunc_bolo.dat cfunc_0.7-7.dat cfunc_0.1-2.4.dat 2> /dev/null
    #grep Lx $lx_res |awk '{print $2}' >>summary_lx.dat
    LX1=`grep 'Lx1' $lx_res |awk '{print $2}'` 
    LX2=`grep 'Lx2' $lx_res |awk '{print $2}'` 
    LX3=`grep 'Lx3' $lx_res |awk '{print $2}'` 
    FX1=`grep 'Fx1' $lx_res |awk '{print $2}'` 
    FX2=`grep 'Fx2' $lx_res |awk '{print $2}'` 
    FX3=`grep 'Fx3' $lx_res |awk '{print $2}'` 

    echo $LX1 $LX2 $LX3 >>summary_lx.dat
    echo $FX1 $FX2 $FX3 >>summary_fx.dat
done # end of 'for'

# analyze lx & fx
$base_path/analyze_lx.py
$base_path/analyze_fx.py

exit 0

