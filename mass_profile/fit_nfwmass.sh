#!/bin/sh
#
# Front-end script used to calculate the mass and related values.
#
# Output:
#   * final_result.txt / center_only_results.txt
#   * beta_param_center.txt / dbeta_param_center.txt
#   * gas_mass_int_center.qdp
#   * mass_int_center.qdp
#   * nfw_fit_center.qdp
#   * nfw_param_center.txt
#   * overdensity_center.qdp
#   * rho_fit_center.dat
#   * rho_fit_center.qdp
#   * sbp_fit_center.qdp
#   * entropy_center.qdp
#   * ${t_profile_type}_param_center.txt
#   * ${t_profile_type}_dump_center.qdp
#   * ${t_profile_type}_fit_center.qdp
#   * summary_mass_profile.qdp
#   * summary_overdensity.qdp
#   * summary_gas_mass_profile.qdp
#   * summary_entropy.qdp
#
# Junhua Gu
# Weitian LI
# 2016-06-07
#

if [ $# -eq 1 ] || [ $# -eq 2 ]; then
    :
else
    echo "usage:"
    echo "    `basename $0` <global.cfg> [c]"
    echo ""
    echo "arguments:"
    echo "    <global.cfg>: main config file used for mass calculation"
    echo "    [c]: optional; if specified, do not calculate the errors"
    exit 1
fi

if ! which xspec > /dev/null; then
    printf "*** ERROR: please initialize HEASOFT first\n"
    exit 2
fi

if [ -z "${HEADAS}" ]; then
    printf "*** ERROR: variable \`HEADAS' not properly set\n"
    exit 3
fi

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export PGPLOT_FONT="${HEADAS}/lib/grfont.dat"
printf "## PGPLOT_FONT: \`${PGPLOT_FONT}'\n"

base_path=$(dirname $(realpath $0))
printf "## base_path: \`${base_path}'\n"
cfg_file="$1"
printf "## use configuration file: \`${cfg_file}'\n"
case "$2" in
    [cC])
        F_C="YES"
        ;;
    *)
        F_C="NO"
        ;;
esac

# rmin for fit_nfw_mass
nfw_rmin_kpc=`grep '^nfw_rmin_kpc' ${cfg_file} | awk '{ print $2 }'`
# profile type name
t_profile_type=`grep '^t_profile' ${cfg_file} | awk '{ print $2 }'`
printf "## t_profile_type: \`$t_profile_type'\n"
# data file name
t_data_file=`grep '^t_data_file' ${cfg_file} | awk '{ print $2 }'`
t_param_file=`grep '^t_param_file' ${cfg_file} | awk '{ print $2 }'`
# sbp config file
sbp_cfg=`grep '^sbp_cfg' ${cfg_file} | awk '{ print $2 }'`
# temperature profile file
T_file=`grep '^T_file' ${sbp_cfg} | awk '{ print $2 }'`
cfunc_file=`grep '^cfunc_file' ${sbp_cfg} | awk '{ print $2 }'`
abund=`grep '^abund' ${cfg_file} | awk '{ print $2 }'`
nh=`grep '^nh' ${cfg_file} | awk '{ print $2 }'`
## calc `cm_per_pixel' instead {{{
z=`grep '^z' ${sbp_cfg} | awk '{ print $2 }'`
cm_per_pixel=`cosmo_calc ${z} | grep 'cm/pixel' | awk -F':' '{ print $2 }'`
sed -i'' "s/^cm_per_pixel.*$/cm_per_pixel   ${cm_per_pixel}/" ${sbp_cfg}
printf "## redshift: ${z}, cm_per_pixel: ${cm_per_pixel}\n"
## cm_per_pixel }}}
da=`python -c "print($cm_per_pixel/(.492/3600/180*3.1415926))"`
dl=`python -c "print($da*(1+$z)**2)"`
printf "da= ${da}\n"
printf "dl= ${dl}\n"
## sbp {{{
sbp_data_file=`grep '^sbp_file' ${sbp_cfg} | awk '{ print $2 }'`
radius_sbp_file=`grep '^radius_sbp_file' ${cfg_file} | awk '{ print $2 }'`

if [ "x${radius_sbp_file}" = "x" ]; then
    printf "*** ERROR: radius_sbp_file not found\n"
    exit 200
fi

TMP_RSBP="_tmp_rsbp.txt"
[ -e "${TMP_RSBP}" ] && rm -f ${TMP_RSBP}
cat ${radius_sbp_file} | sed 's/#.*$//' | grep -Ev '^\s*$' > ${TMP_RSBP}
# mv -f _tmp_rsbp.txt ${radius_sbp_file}
radius_sbp_file="${TMP_RSBP}"
## sbp }}}

## sbp model: beta/dbeta {{{
if grep -q '^beta2' $sbp_cfg; then
    MODEL="dbeta"
    MODEL_NAME="double-beta"
else
    MODEL="beta"
    MODEL_NAME="single-beta"
fi
# }}}

# only 'wang2012' model supported {{{
if [ "X${t_profile_type}" != "Xwang2012" ]; then
    printf "ERROR: invalid temperature profile model: \`${t_profile_type}'!\n"
    exit 10
fi
T_param_center="${t_profile_type}_param_center.txt"
T_fit_center="${t_profile_type}_fit_center.qdp"
T_file_center="${t_profile_type}_dump_center.qdp"
T_dump="${t_profile_type}_dump.qdp"
PROG_TPROFILE="fit_${t_profile_type}_model"
${base_path}/${PROG_TPROFILE} ${t_data_file} ${t_param_file} \
            ${cm_per_pixel} 2> /dev/null | tee ${T_param_center}
cp -fv ${T_dump} ${T_file}
mv -fv ${T_dump} ${T_file_center}
mv -fv fit_result.qdp ${T_file_center}
# temp profile }}}

$base_path/coolfunc_calc2.sh ${T_file_center} $abund $nh $z $cfunc_file cfunc_bolo.dat
cfunc_file_center="coolfunc_data_center.txt"
cp -f ${cfunc_file} ${cfunc_file_center}
mv -fv flux_cnt_ratio.txt flux_cnt_ratio_center.txt

PROG_SBPFIT="fit_${MODEL}_sbp"
RES_SBPFIT="${MODEL}_param.txt"
RES_SBPFIT_CENTER="${MODEL}_param_center.txt"
${base_path}/${PROG_SBPFIT} ${sbp_cfg} 2> /dev/null
mv -fv ${RES_SBPFIT} ${RES_SBPFIT_CENTER}
cat ${RES_SBPFIT_CENTER}
mv -fv sbp_fit.qdp sbp_fit_center.qdp
mv -fv rho_fit.qdp rho_fit_center.qdp
mv -fv rho_fit.dat rho_fit_center.dat
mv -fv entropy.qdp entropy_center.qdp
${base_path}/fit_nfw_mass mass_int.dat $z $nfw_rmin_kpc 2> /dev/null
mv -fv nfw_param.txt      nfw_param_center.txt
mv -fv nfw_fit_result.qdp nfw_fit_center.qdp
mv -fv nfw_dump.qdp       mass_int_center.qdp
mv -fv overdensity.qdp    overdensity_center.qdp
mv -fv gas_mass_int.qdp   gas_mass_int_center.qdp

#exit 233

## cooling time (-> use 'ciao_calc_ct.sh')
$base_path/cooling_time rho_fit_center.dat ${T_file_center} cfunc_bolo.dat $dl $cm_per_pixel > cooling_time.dat
## radius to calculate tcool, not the cooling time!
rcool=`$base_path/analyze_mass_profile.py 500 c | grep '^r500' | awk -F'=' '{ print .048*$2 }'`
printf "rcool= ${rcool}\n"

## only calculate central value {{{
if [ "${F_C}" = "YES" ]; then
    RES_CENTER="center_only_results.txt"
    [ -e "${RES_CENTER}" ] && mv -f ${RES_CENTER} ${RES_CENTER}_bak
    $base_path/analyze_mass_profile.py  200 c | tee -a ${RES_CENTER}
    $base_path/analyze_mass_profile.py  500 c | tee -a ${RES_CENTER}
    $base_path/analyze_mass_profile.py 1500 c | tee -a ${RES_CENTER}
    $base_path/analyze_mass_profile.py 2500 c | tee -a ${RES_CENTER}
    $base_path/extract_tcool.py $rcool        | tee -a ${RES_CENTER}
    $base_path/fg_2500_500.py c               | tee -a ${RES_CENTER}
    exit 0
fi
## central value }}}

# clean previous files
rm -f summary_overdensity.qdp
rm -f summary_mass_profile.qdp
rm -f summary_gas_mass_profile.qdp
rm -f summary_entropy.qdp


# Estimate the errors of Lx and Fx by Monte Carlo simulation
printf "\n+++++++++++++++++++ Monte Carlo +++++++++++++++++++++\n"
MC_TIMES=100
for i in `seq 1 ${MC_TIMES}`; do
    $base_path/shuffle_T.py $t_data_file temp_shuffled_t.dat
    $base_path/shuffle_sbp.py $sbp_data_file temp_shuffled_sbp.dat

    # temperature profile
    ${base_path}/${PROG_TPROFILE} temp_shuffled_t.dat ${t_param_file} \
                ${cm_per_pixel} 2> /dev/null
    mv -f ${T_dump} ${T_file}

    # clear ${TMP_SBP_CFG}
    TMP_SBP_CFG="temp_sbp.cfg"
    # : > ${TMP_SBP_CFG}
    [ -e "${TMP_SBP_CFG}" ] && rm -f ${TMP_SBP_CFG}
    cat ${sbp_cfg} | while read l; do
        if echo "${l}" | grep -q '^sbp_file' >/dev/null; then
            echo "sbp_file  temp_shuffled_sbp.dat" >> ${TMP_SBP_CFG}
        elif echo "${l}" | grep -q '^T_file' >/dev/null; then
            echo "T_file  ${T_file}" >> ${TMP_SBP_CFG}
        else
            echo "${l}" >> ${TMP_SBP_CFG}
        fi
    done

    printf "## ${i} / ${MC_TIMES} ##\n"
    printf "## `pwd -P` ##\n"
    ${base_path}/coolfunc_calc2.sh ${T_file} ${abund} ${nh} ${z} ${cfunc_file}
    ${base_path}/${SBP_PROG} ${TMP_SBP_CFG} 2> /dev/null
    cat ${RES_SBPFIT}
    $base_path/fit_nfw_mass mass_int.dat ${z} ${nfw_rmin_kpc} 2> /dev/null
    cat nfw_dump.qdp     >> summary_mass_profile.qdp
    echo "no no no"      >> summary_mass_profile.qdp
    cat overdensity.qdp  >> summary_overdensity.qdp
    echo "no no no"      >> summary_overdensity.qdp
    cat gas_mass_int.qdp >> summary_gas_mass_profile.qdp
    echo "no no no"      >> summary_gas_mass_profile.qdp
    cat entropy.qdp      >> summary_entropy.qdp
    echo "no no no"      >> summary_entropy.qdp

done  # end `while'
# recover `center_files'
cp -f ${cfunc_file_center} ${cfunc_file}
cp -f ${T_file_center} ${T_file}
printf "\n+++++++++++++++++ MONTE CARLO END +++++++++++++++++++\n"

## analyze results
RES_TMP="_tmp_result_mrl.txt"
RES_FINAL="final_result.txt"
[ -e "${RES_TMP}" ]   && mv -fv ${RES_TMP}   ${RES_TMP}_bak
[ -e "${RES_FINAL}" ] && mv -fv ${RES_FINAL} ${RES_FINAL}_bak

${base_path}/analyze_mass_profile.py  200 | tee -a ${RES_TMP}
${base_path}/analyze_mass_profile.py  500 | tee -a ${RES_TMP}
${base_path}/analyze_mass_profile.py 1500 | tee -a ${RES_TMP}
${base_path}/analyze_mass_profile.py 2500 | tee -a ${RES_TMP}

R200_VAL=`grep  '^r200'  ${RES_TMP} | awk '{ print $2 }'`
R500_VAL=`grep  '^r500'  ${RES_TMP} | awk '{ print $2 }'`
R1500_VAL=`grep '^r1500' ${RES_TMP} | awk '{ print $2 }'`
R2500_VAL=`grep '^r2500' ${RES_TMP} | awk '{ print $2 }'`
printf "## R200:  ${R200_VAL}\n"
printf "## R500:  ${R500_VAL}\n"
printf "## R1500: ${R1500_VAL}\n"
printf "## R2500: ${R2500_VAL}\n"
L200E=`$base_path/calc_lx  $radius_sbp_file flux_cnt_ratio_center.txt $z $R200_VAL  $t_data_file | grep '^Lx' | awk '{ print $2,$3,$4 }'`
L500E=`$base_path/calc_lx  $radius_sbp_file flux_cnt_ratio_center.txt $z $R500_VAL  $t_data_file | grep '^Lx' | awk '{ print $2,$3,$4 }'`
L1500E=`$base_path/calc_lx $radius_sbp_file flux_cnt_ratio_center.txt $z $R1500_VAL $t_data_file | grep '^Lx' | awk '{ print $2,$3,$4 }'`
L2500E=`$base_path/calc_lx $radius_sbp_file flux_cnt_ratio_center.txt $z $R2500_VAL $t_data_file | grep '^Lx' | awk '{ print $2,$3,$4 }'`
R200E=`grep   '^r200'             ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
R500E=`grep   '^r500'             ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
R1500E=`grep  '^r1500'            ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
R2500E=`grep  '^r2500'            ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
M200E=`grep   '^m200'             ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
M500E=`grep   '^m500'             ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
M1500E=`grep  '^m1500'            ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
M2500E=`grep  '^m2500'            ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
MG200E=`grep  '^gas_m200'         ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
MG500E=`grep  '^gas_m500'         ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
MG1500E=`grep '^gas_m1500'        ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
MG2500E=`grep '^gas_m2500'        ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
FG200E=`grep  '^gas_fraction200'  ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
FG500E=`grep  '^gas_fraction500'  ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
FG1500E=`grep '^gas_fraction1500' ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`
FG2500E=`grep '^gas_fraction2500' ${RES_TMP} | tail -n 1 | awk '{ print $2,$3 }'`

printf "\n+++++++++++++++ RESULTS (${MODEL_NAME}) +++++++++++++++\n"
printf "cfg: ${cfg_file}\n"                    | tee -a ${RES_FINAL}
printf "model: ${MODEL_NAME}\n"                | tee -a ${RES_FINAL}
printf "\n"                                    | tee -a ${RES_FINAL}
cat ${RES_SBPFIT_CENTER}                       | tee -a ${RES_FINAL}
printf "\n"                                    | tee -a ${RES_FINAL}
printf "r200= ${R200E} kpc\n"                  | tee -a ${RES_FINAL}
printf "m200= ${M200E} M_sun\n"                | tee -a ${RES_FINAL}
printf "L200= ${L200E} erg/s\n"                | tee -a ${RES_FINAL}
printf "gas_m200= ${MG200E} M_sun\n"           | tee -a ${RES_FINAL}
printf "gas_fraction200= ${FG200E} x100%%\n"   | tee -a ${RES_FINAL}
printf "r500= ${R500E} kpc\n"                  | tee -a ${RES_FINAL}
printf "m500= ${M500E} M_sun\n"                | tee -a ${RES_FINAL}
printf "L500= ${L500E} erg/s\n"                | tee -a ${RES_FINAL}
printf "gas_m500= ${MG500E} M_sun\n"           | tee -a ${RES_FINAL}
printf "gas_fraction500= ${FG500E} x100%%\n"   | tee -a ${RES_FINAL}
printf "r1500= ${R1500E} kpc\n"                | tee -a ${RES_FINAL}
printf "m1500= ${M1500E} M_sun\n"              | tee -a ${RES_FINAL}
printf "L1500= ${L1500E} erg/s\n"              | tee -a ${RES_FINAL}
printf "gas_m1500= ${MG1500E} M_sun\n"         | tee -a ${RES_FINAL}
printf "gas_fraction1500= ${FG1500E} x100%%\n" | tee -a ${RES_FINAL}
printf "r2500= ${R2500E} kpc\n"                | tee -a ${RES_FINAL}
printf "m2500= ${M2500E} M_sun\n"              | tee -a ${RES_FINAL}
printf "L2500= ${L2500E} erg/s\n"              | tee -a ${RES_FINAL}
printf "gas_m2500= ${MG2500E} M_sun\n"         | tee -a ${RES_FINAL}
printf "gas_fraction2500= ${FG2500E} x100%%\n" | tee -a ${RES_FINAL}
printf "\n"                                    | tee -a ${RES_FINAL}
printf "gas mass 200= ${MG200E} M_sun\n"       | tee -a ${RES_FINAL}
printf "gas fractho 200= ${FG200E} x100%%\n"   | tee -a ${RES_FINAL}
printf "gas mass 500= ${MG500E} M_sun\n"       | tee -a ${RES_FINAL}
printf "gas fractho 500= ${FG500E} x100%%\n"   | tee -a ${RES_FINAL}
printf "gas mass 1500= ${MG1500E} M_sun\n"     | tee -a ${RES_FINAL}
printf "gas fractho 1500= ${FG1500E} x100%%\n" | tee -a ${RES_FINAL}
printf "gas mass 2500= ${MG2500E} M_sun\n"     | tee -a ${RES_FINAL}
printf "gas fractho 2500= ${FG2500E} x100%%\n" | tee -a ${RES_FINAL}
printf "\n"                                    | tee -a ${RES_FINAL}
$base_path/extract_tcool.py $rcool             | tee -a ${RES_FINAL}
$base_path/fg_2500_500.py                      | tee -a ${RES_FINAL}
printf "\n+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
