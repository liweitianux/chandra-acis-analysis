#!/bin/sh
#
# Front-end script used to calculate the mass and related values.
#
# Output:
#   * final_result.txt / center_only_results.txt
#   * beta_param.txt / dbeta_param_center.txt
#   * gas_mass_int_center.qdp
#   * mass_int_center.qdp
#   * nfw_fit_center.qdp
#   * nfw_param_center.txt
#   * overdensity_center.qdp
#   * rho_fit_center.dat
#   * rho_fit_center.qdp
#   * sbp_fit_center.qdp
#   * entropy_center.qdp
#   * wang2012_param_center.txt
#   * tprofile_dump_center.qdp
#   * tprofile_fit_center.qdp
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
    echo "    `basename $0` <mass.conf> [c]"
    echo ""
    echo "arguments:"
    echo "    <mass.conf>: config file for mass profile calculation"
    echo "    [c]: optional; if specified, do not calculate the errors"
    exit 1
fi

if ! which xspec > /dev/null 2>&1; then
    printf "*** ERROR: please initialize HEASOFT first\n"
    exit 2
fi

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

base_path=$(dirname $(realpath $0))
printf "## base_path: \`${base_path}'\n"
mass_cfg="$1"
printf "## use configuration file: \`${mass_cfg}'\n"
case "$2" in
    [cC])
        F_C="YES"
        ;;
    *)
        F_C="NO"
        ;;
esac

nh=`grep            '^nh'            ${mass_cfg} | awk '{ print $2 }'`
abund=`grep         '^abund'         ${mass_cfg} | awk '{ print $2 }'`
nfw_rmin_kpc=`grep  '^nfw_rmin_kpc'  ${mass_cfg} | awk '{ print $2 }'`
tprofile_data=`grep '^tprofile_data' ${mass_cfg} | awk '{ print $2 }'`
tprofile_cfg=`grep  '^tprofile_cfg'  ${mass_cfg} | awk '{ print $2 }'`
sbp_cfg=`grep       '^sbp_cfg'       ${mass_cfg} | awk '{ print $2 }'`

# sbp config file
sbp_data=`grep      '^sbp_data'      ${sbp_cfg} | awk '{ print $2 }'`
tprofile=`grep      '^tprofile'      ${sbp_cfg} | awk '{ print $2 }'`
cfunc_profile=`grep '^cfunc_profile' ${sbp_cfg} | awk '{ print $2 }'`
z=`grep             '^z'             ${sbp_cfg} | awk '{ print $2 }'`
cm_per_pixel=`cosmo_calc.py -b --cm-per-pixel ${z}`
sed -i'' "s/^cm_per_pixel.*$/cm_per_pixel   ${cm_per_pixel}/" ${sbp_cfg}

if grep -q '^beta2' $sbp_cfg; then
    MODEL="dbeta"
    MODEL_NAME="double-beta"
else
    MODEL="beta"
    MODEL_NAME="single-beta"
fi

PROG_TPROFILE="fit_wang2012_model"
tprofile_dump="wang2012_dump.qdp"
tprofile_param_center="wang2012_param_center.txt"
tprofile_fit_center="tprofile_fit_center.qdp"
tprofile_center="tprofile_dump_center.qdp"

${base_path}/${PROG_TPROFILE} ${tprofile_data} ${tprofile_cfg} \
            ${cm_per_pixel} 2> /dev/null | tee ${tprofile_param_center}
cp -fv ${tprofile_dump} ${tprofile}
mv -fv ${tprofile_dump} ${tprofile_center}
mv -fv fit_result.qdp ${tprofile_fit_center}

${base_path}/calc_coolfunc.sh ${tprofile_center} \
            ${abund} ${nh} ${z} ${cfunc_profile}
cfunc_profile_center="coolfunc_profile_center.txt"
cp -f ${cfunc_profile} ${cfunc_profile_center}

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
${base_path}/fit_nfw_mass mass_int.dat ${z} ${nfw_rmin_kpc} 2> /dev/null
mv -fv nfw_param.txt      nfw_param_center.txt
mv -fv nfw_fit_result.qdp nfw_fit_center.qdp
mv -fv nfw_dump.qdp       mass_int_center.qdp
mv -fv overdensity.qdp    overdensity_center.qdp
mv -fv gas_mass_int.qdp   gas_mass_int_center.qdp

## only calculate central value {{{
if [ "${F_C}" = "YES" ]; then
    RES_CENTER="center_only_results.txt"
    [ -e "${RES_CENTER}" ] && mv -f ${RES_CENTER} ${RES_CENTER}_bak
    ${base_path}/analyze_mass_profile.py  200 c | tee -a ${RES_CENTER}
    ${base_path}/analyze_mass_profile.py  500 c | tee -a ${RES_CENTER}
    ${base_path}/analyze_mass_profile.py 1500 c | tee -a ${RES_CENTER}
    ${base_path}/analyze_mass_profile.py 2500 c | tee -a ${RES_CENTER}
    ${base_path}/fg_2500_500.py c               | tee -a ${RES_CENTER}
    exit 0
fi
## central value }}}

## ------------------------------------------------------------------

# clean previous files
rm -f summary_overdensity.qdp
rm -f summary_mass_profile.qdp
rm -f summary_gas_mass_profile.qdp
rm -f summary_entropy.qdp

# Estimate the errors of Lx and Fx by Monte Carlo simulation
printf "\n+++++++++++++++++++ Monte Carlo +++++++++++++++++++++\n"
MC_TIMES=100
for i in `seq 1 ${MC_TIMES}`; do
    ${base_path}/shuffle_profile.py ${tprofile_data} tmp_tprofile.txt
    ${base_path}/shuffle_profile.py ${sbp_data} tmp_sbprofile.txt

    # temperature profile
    ${base_path}/${PROG_TPROFILE} tmp_tprofile.txt ${tprofile_cfg} \
                ${cm_per_pixel} 2> /dev/null
    mv -f ${tprofile_dump} ${tprofile}

    TMP_SBP_CFG="tmp_sbp.cfg"
    [ -e "${TMP_SBP_CFG}" ] && rm -f ${TMP_SBP_CFG}
    cat ${sbp_cfg} | while read l; do
        if echo "${l}" | grep -q '^sbp_data' >/dev/null; then
            echo "sbp_data  tmp_sbprofile.txt" >> ${TMP_SBP_CFG}
        elif echo "${l}" | grep -q '^tprofile' >/dev/null; then
            echo "tprofile  ${tprofile}" >> ${TMP_SBP_CFG}
        else
            echo "${l}" >> ${TMP_SBP_CFG}
        fi
    done

    printf "## ${i} / ${MC_TIMES} ##\n"
    printf "## `pwd -P` ##\n"
    ${base_path}/calc_coolfunc.sh ${tprofile} ${abund} ${nh} ${z} ${cfunc_profile}
    ${base_path}/${PROG_SBPFIT} ${TMP_SBP_CFG} 2> /dev/null
    cat ${RES_SBPFIT}
    ${base_path}/fit_nfw_mass mass_int.dat ${z} ${nfw_rmin_kpc} 2> /dev/null
    cat nfw_dump.qdp     >> summary_mass_profile.qdp
    echo "no no no"      >> summary_mass_profile.qdp
    cat overdensity.qdp  >> summary_overdensity.qdp
    echo "no no no"      >> summary_overdensity.qdp
    cat gas_mass_int.qdp >> summary_gas_mass_profile.qdp
    echo "no no no"      >> summary_gas_mass_profile.qdp
    cat entropy.qdp      >> summary_entropy.qdp
    echo "no no no"      >> summary_entropy.qdp
done  # end of `for'

# recover the files of original center values
cp -f ${cfunc_profile_center} ${cfunc_profile}
cp -f ${tprofile_center} ${tprofile}
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
printf "model: ${MODEL_NAME}\n"                | tee -a ${RES_FINAL}
cat ${RES_SBPFIT_CENTER}                       | tee -a ${RES_FINAL}
printf "\n"                                    | tee -a ${RES_FINAL}
printf "r200= ${R200E} kpc\n"                  | tee -a ${RES_FINAL}
printf "m200= ${M200E} Msun\n"                 | tee -a ${RES_FINAL}
printf "gas_m200= ${MG200E} Msun\n"            | tee -a ${RES_FINAL}
printf "gas_fraction200= ${FG200E} x100%%\n"   | tee -a ${RES_FINAL}
printf "r500= ${R500E} kpc\n"                  | tee -a ${RES_FINAL}
printf "m500= ${M500E} Msun\n"                 | tee -a ${RES_FINAL}
printf "gas_m500= ${MG500E} Msun\n"            | tee -a ${RES_FINAL}
printf "gas_fraction500= ${FG500E} x100%%\n"   | tee -a ${RES_FINAL}
printf "r1500= ${R1500E} kpc\n"                | tee -a ${RES_FINAL}
printf "m1500= ${M1500E} Msun\n"               | tee -a ${RES_FINAL}
printf "gas_m1500= ${MG1500E} Msun\n"          | tee -a ${RES_FINAL}
printf "gas_fraction1500= ${FG1500E} x100%%\n" | tee -a ${RES_FINAL}
printf "r2500= ${R2500E} kpc\n"                | tee -a ${RES_FINAL}
printf "m2500= ${M2500E} Msun\n"               | tee -a ${RES_FINAL}
printf "gas_m2500= ${MG2500E} Msun\n"          | tee -a ${RES_FINAL}
printf "gas_fraction2500= ${FG2500E} x100%%\n" | tee -a ${RES_FINAL}
printf "\n"                                    | tee -a ${RES_FINAL}
${base_path}/fg_2500_500.py                    | tee -a ${RES_FINAL}
printf "\n+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
