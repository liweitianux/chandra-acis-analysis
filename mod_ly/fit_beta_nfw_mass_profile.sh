#!/bin/sh

# modified by LIweitaNux, 2012/09/06
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

if [ $# -eq 1 ]; then
    cfg_file="$1"
elif [ $# -eq 2 ]; then
    cfg_file="$1"
    CENTER_VAL="YES"
else
    echo "Usage: $0 <cfg_file> [c]"
    exit 1
fi

if ! which xspec > /dev/null; then
    printf "ERROR: please initialize HEASOFT first\n"
    exit 2
fi

if [ -z "${HEADAS}" ]; then
    printf "ERROR: variable \`HEADAS' not properly set\n"
    exit 3
fi

export PGPLOT_FONT="${HEADAS}/lib/grfont.dat"
printf "## PGPLOT_FONT: \`${PGPLOT_FONT}'\n"

if [ "$0" = `basename $0` ]; then
    script_path=`which $0`
    base_path=`dirname ${script_path}`
else
    base_path=`dirname $0`
fi
printf "## base_path: \`${base_path}'\n"
printf "## use configuration file: \`${cfg_file}'\n"

#initialize profile type name
t_profile_type=`grep '^t_profile' $cfg_file | awk '{print $2}'`
printf "## t_profile_type: \`$t_profile_type'\n"
#initialize data file name
t_data_file=`grep '^t_data_file' $cfg_file | awk '{print $2}'`
t_param_file=`grep '^t_param_file' $cfg_file | awk '{print $2}'`
#initialize sbp config file
sbp_cfg=`grep '^sbp_cfg' $cfg_file | awk '{print $2}'`
#initialize the temperature profile file
T_file=`grep '^T_file' $sbp_cfg | awk '{print $2}'`
cfunc_file=`grep '^cfunc_file' ${sbp_cfg} |awk '{print $2}'`
abund=`grep '^abund' ${cfg_file} |awk '{print $2}'`
nh=`grep '^nh' ${cfg_file} |awk '{print $2}'`
## calc `cm_per_pixel' instead {{{
# cm_per_pixel=`grep '^cm_per_pixel' $sbp_cfg|awk '{print $2}'`
z=`grep '^z' $sbp_cfg | awk '{ print $2 }'`
cm_per_pixel=`${base_path}/calc_distance ${z} | grep 'cm_per_pixel' | awk '{ print $2 }'`
sed -i'' "s/^cm_per_pixel.*$/cm_per_pixel    ${cm_per_pixel}/" ${sbp_cfg}
printf "## redshift: ${z}, cm_per_pixel: ${cm_per_pixel}\n"
## cm_per_pixel }}}
da=`python -c "print($cm_per_pixel/(.492/3600/180*3.1415926))"`
dl=`python -c "print($da*(1+$z)**2)"`
printf "da= ${da}\n"
printf "dl= ${dl}\n"
## sbp {{{
sbp_data_file=`grep '^sbp_file' $sbp_cfg | awk '{print $2}'`
radius_sbp_file=`grep '^radius_sbp_file' ${cfg_file} | awk '{print $2}'`

if [ "x$radius_sbp_file" = "x" ]; then
    echo "ERROR, must have radius_sbp_file assigned, this file should be a 4-column file, which contains the radius, radius err, sbp, and sbp err"
    exit 200
fi

TMP_RSBP="_tmp_rsbp.txt"
[ -e "${TMP_RSBP}" ] && rm -f ${TMP_RSBP}
cat ${radius_sbp_file} | sed 's/#.*$//' | grep -Ev '^\s*$' > ${TMP_RSBP}
# mv -f _tmp_rsbp.txt ${radius_sbp_file}
radius_sbp_file="${TMP_RSBP}"
## sbp }}}

# determine which temperature profile to be used, and fit the T profile {{{
if [ "$t_profile_type" = "zyy" ]; then
    $base_path/fit_zyy_model $t_data_file $t_param_file $cm_per_pixel
    # mv -f zyy_dump.qdp ${T_file}
    mv -f zyy_dump.qdp zyy_dump_center.qdp
elif [ "$t_profile_type" = "m0603246" ]; then
    $base_path/fit_m0603246 $t_data_file $cm_per_pixel
    # mv -f m0603246_dump.qdp ${T_file}
    mv -f m0603246_dump.qdp m0603246_dump_center.qdp
elif [ "$t_profile_type" = "wang2012" ]; then
    $base_path/fit_wang2012_model $t_data_file $t_param_file $cm_per_pixel 2> /dev/null | tee wang2012_center_param.txt
    # mv -f wang2012_dump.qdp ${T_file}
    cp -fv wang2012_dump.qdp ${T_file}
    T_file_center="wang2012_dump_center.qdp"
    mv -fv wang2012_dump.qdp ${T_file_center}
    mv -fv fit_result.qdp wang2012_fit_center.qdp
elif [ "$t_profile_type" = "allen" ]; then
    $base_path/fit_allen_model $t_data_file $cm_per_pixel
    # mv -f allen_dump.qdp ${T_file}
    mv -f allen_dump.qdp allen_dump_center.qdp
elif [ "$t_profile_type" = "zzl" ]; then
    $base_path/fit_zzl_model $t_data_file $t_param_file
    # mv -f zzl_dump.qdp ${T_file}
    mv -f zzl_dump.qdp zzl_dump_center.qdp
else
    printf "ERROR: temperature profile name \`${t_profile_type}' invalid!\n"
    exit 10
fi
# temp profile }}}

$base_path/coolfunc_calc_bolo.sh ${T_file_center} $abund $nh $z cfunc_bolo.dat
$base_path/coolfunc_calc.sh ${T_file_center} $abund $nh $z $cfunc_file
mv -fv flux_cnt_ratio.txt flux_cnt_ratio_center.txt
# fit sbp
$base_path/fit_beta_sbp $sbp_cfg 2> /dev/null
mv -fv beta_param.txt beta_param_center.txt
cat beta_param_center.txt
mv -fv sbp_fit.qdp sbp_fit_center.qdp
mv -fv rho_fit.qdp rho_fit_center.qdp
mv -fv rho_fit.dat rho_fit_center.dat
$base_path/fit_nfw_mass mass_int.dat $z 2> /dev/null
mv -fv nfw_param.txt nfw_param_center.txt
mv -fv nfw_fit_result.qdp nfw_fit_center.qdp
mv -fv nfw_dump.qdp mass_int_center.qdp
mv -fv overdensity.qdp overdensity_center.qdp
mv -fv gas_mass_int.qdp gas_mass_int_center.qdp

#exit 233

## cooling time
$base_path/cooling_time rho_fit_center.dat ${T_file_center} cfunc_bolo.dat $dl $cm_per_pixel > cooling_time.dat
## radius to calculate tcool, not the cooling time!
rcool=`$base_path/analyze_mass_profile.py 500 c | grep '^r500' | awk -F "=" '{print .048*$2}'`
printf "rcool= ${rcool}\n"

## center value {{{
if [ "${CENTER_VAL}" = "YES" ]; then
    $base_path/analyze_mass_profile.py 200 c
    $base_path/analyze_mass_profile.py 500 c
    $base_path/extract_tcool.py $rcool | tee cooling_time_result.txt
    exit 0
fi
## center value }}}

# clean previous files
rm -f summary_shuffle_mass_profile.qdp
rm -f summary_overdensity.qdp
rm -f summary_mass_profile.qdp
rm -f summary_gas_mass_profile.qdp

## count
COUNT=1

#100 times of Monte-carlo simulation to determine error
#just repeat above steps
printf "\n+++++++++++++++++++ Monte Carlo +++++++++++++++++++++\n"
for i in `seq 1 100`; do
    # echo $t_data_file
    $base_path/shuffle_T.py $t_data_file temp_shuffled_t.dat
    $base_path/shuffle_sbp.py $sbp_data_file temp_shuffled_sbp.dat
    # t_data_file=temp_shuffled_t.dat
#exit

    if [ "$t_profile_type" = "zyy" ]; then
	$base_path/fit_zyy_model temp_shuffled_t.dat $t_param_file $cm_per_pixel
	mv -f zyy_dump.qdp ${T_file}
    elif [ "$t_profile_type" = "m0603246" ]; then
	$base_path/fit_m0603246 temp_shuffled_t.dat $cm_per_pixel
	mv -f m0603246_dump.qdp ${T_file}
    elif [ "$t_profile_type" = "wang2012" ]; then
	$base_path/fit_wang2012_model temp_shuffled_t.dat $t_param_file $cm_per_pixel 2> /dev/null
        mv -f wang2012_dump.qdp ${T_file}
    elif [ "$t_profile_type" = "allen" ]; then
	$base_path/fit_allen_model temp_shuffled_t.dat $cm_per_pixel
	mv -f allen_dump.qdp ${T_file}
    elif [ "$t_profile_type" = "zzl" ]; then
        $base_path/fit_zzl_model temp_shuffled_t.dat $t_param_file
        mv -f zzl_dump.qdp ${T_file}
    else
        printf "ERROR: temperature profile name \`${t_profile_type}' invalid!\n"
        exit 10
    fi

#exit
    : > temp_sbp.cfg
    
    cat $sbp_cfg | while read l; do
        if echo $l | grep -q 'sbp_file'; then
            echo "sbp_file temp_shuffled_sbp.dat" >> temp_sbp.cfg
        elif echo $l | grep -q 'T_file'; then
            echo "T_file ${T_file}" >> temp_sbp.cfg
        else
            echo $l >> temp_sbp.cfg
        fi
    done

    ## count
    printf "## ${COUNT} ##\n"
    COUNT=`expr ${COUNT} + 1`
    printf "## `pwd` ##\n"
    $base_path/coolfunc_calc.sh ${T_file} ${abund} ${nh} ${z} ${cfunc_file}

    # single-beta model
    $base_path/fit_beta_sbp temp_sbp.cfg 2> /dev/null
    [ -r "beta_param.txt" ] && cat beta_param.txt
    $base_path/fit_nfw_mass mass_int.dat $z 2> /dev/null
    cat nfw_dump.qdp >> summary_mass_profile.qdp
    echo "no no no" >> summary_mass_profile.qdp

    cat overdensity.qdp >> summary_overdensity.qdp
    echo "no no no" >> summary_overdensity.qdp

    cat gas_mass_int.qdp >> summary_gas_mass_profile.qdp
    echo "no no no" >> summary_gas_mass_profile.qdp

done        # end `while'
printf "\n+++++++++++++++++++ Monte Carlo +++++++++++++++++++++\n"

#analys the errors
printf "\n+++++++++++++++ RESULTS (single-beta) +++++++++++++++\n"
RESULT="results_mrl.txt"
[ -e "${RESULT}" ] && mv -fv ${RESULT} ${RESULT}_bak

$base_path/analyze_mass_profile.py 200 | tee -a ${RESULT}
$base_path/analyze_mass_profile.py 500 | tee -a ${RESULT}
$base_path/analyze_mass_profile.py 1500 | tee -a ${RESULT}
$base_path/analyze_mass_profile.py 2500 | tee -a ${RESULT}

R200_VAL=`grep '^r200' ${RESULT} | awk '{ print $2 }'`
R500_VAL=`grep '^r500' ${RESULT} | awk '{ print $2 }'`
printf "\n## R200: ${R200_VAL}, R500: ${R500_VAL}\n"
L200=`$base_path/calc_lx $radius_sbp_file flux_cnt_ratio_center.txt $z ${R200_VAL} $t_data_file | grep '^Lx' | awk '{ print $2,$3,$4 }'`
L500=`$base_path/calc_lx $radius_sbp_file flux_cnt_ratio_center.txt $z ${R500_VAL} $t_data_file | grep '^Lx' | awk '{ print $2,$3,$4 }'`
printf "L200= ${L200} erg/s\n" | tee -a ${RESULT}
printf "L500= ${L500} erg/s\n" | tee -a ${RESULT}
$base_path/extract_tcool.py $rcool | tee cooling_time_result.txt
printf "\n+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"

