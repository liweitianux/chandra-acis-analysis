#!/bin/sh
#
# Wrapper script used to calculate the luminosity (Lx) and flux (Fx) data,
# which invokes the programming 'calc_lx_beta' (single-beta SBP) or
# 'calc_lx_dbeta' (double-beta SBP).
#
# Output:
#   * lx_result.txt
#   * fx_result.txt
#   * summary_lx.dat
#   * summary_fx.dat
#   * lx_beta_param.txt / lx_dbeta_param.txt
#
# Author: Junhua GU
# Created: 2013-06-24
#
# Weitian LI
# 2016-06-07
#

if [ $# -eq 2 ] || [ $# -eq 3 ]; then
    :
else
    echo "usage:"
    echo "    `basename $0` <mass.conf> <rout_kpc> [c]"
    echo ""
    echo "arguments:"
    echo "    <mass.conf>: config file for mass profile calculation"
    echo "    <rout_kpc>: outer/cut radius within which to calculate Lx & Fx"
    echo "                e.g., r500, r200 (unit: kpc)"
    echo "    [c]: optional; if specified, do not calculate the errors"
    exit 1
fi
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

mass_cfg="$1"
rout="$2"
case "$3" in
    [cC])
        F_C="YES"
        ;;
    *)
        F_C="NO"
        ;;
esac

base_path=$(dirname $(realpath $0))

## Extract settings/values from the config file
nh=`grep            '^nh'            ${mass_cfg} | awk '{ print $2 }'`
abund=`grep         '^abund'         ${mass_cfg} | awk '{ print $2 }'`
tprofile_data=`grep '^tprofile_data' ${mass_cfg} | awk '{ print $2 }'`
tprofile_cfg=`grep  '^tprofile_cfg'  ${mass_cfg} | awk '{ print $2 }'`
sbp_cfg=`grep       '^sbp_cfg'       ${mass_cfg} | awk '{ print $2 }'`

sbp_data=`grep      '^sbp_data'      ${sbp_cfg} | awk '{ print $2 }'`
tprofile=`grep      '^tprofile'      ${sbp_cfg} | awk '{ print $2 }'`
z=`grep             '^z'             ${sbp_cfg} | awk '{ print $2 }'`
cm_per_pixel=`grep  '^cm_per_pixel'  ${sbp_cfg} | awk '{ print $2 }'`

if grep -q '^beta2' $sbp_cfg; then
    MODEL="dbeta"
else
    MODEL="beta"
fi

PROG_TPROFILE="fit_wang2012_model"
tprofile_dump="wang2012_dump.qdp"
${base_path}/${PROG_TPROFILE} ${tprofile_data} ${tprofile_cfg} \
            ${cm_per_pixel} 2> /dev/null
mv -fv ${tprofile_dump} ${tprofile}

# energy bands for which the cooling function data will be calculated
BLIST="blist.txt"
[ -e "${BLIST}" ] && mv -f ${BLIST} ${BLIST}_bak
cat > ${BLIST} << _EOF_
bolo
0.7 7
0.1 2.4
_EOF_

${base_path}/calc_coolfunc_bands.sh ${tprofile} ${abund} \
            ${nh} ${z} "cfunc_" ${BLIST}

PROG="calc_lx_${MODEL}"
LXF_RES="lx_${MODEL}_param.txt"
${base_path}/${PROG} ${sbp_cfg} ${rout} \
            cfunc_bolo.dat \
            cfunc_0.7-7.dat \
            cfunc_0.1-2.4.dat 2> /dev/null
LX1=`grep '^Lx1' ${LX_RES} | awk '{ print $2 }'`
LX2=`grep '^Lx2' ${LX_RES} | awk '{ print $2 }'`
LX3=`grep '^Lx3' ${LX_RES} | awk '{ print $2 }'`
FX1=`grep '^Fx1' ${LX_RES} | awk '{ print $2 }'`
FX2=`grep '^Fx2' ${LX_RES} | awk '{ print $2 }'`
FX3=`grep '^Fx3' ${LX_RES} | awk '{ print $2 }'`

echo "${LX1} ${LX2} ${LX3}" >summary_lx.dat
echo "${FX1} ${FX2} ${FX3}" >summary_fx.dat

# save the calculated central values
mv ${LX_RES} ${LX_RES%.txt}_center.txt
mv lx_sbp_fit.qdp lx_sbp_fit_center.qdp
mv lx_rho_fit.dat lx_rho_fit_center.dat

# only calculate the central values
if [ "${F_C}" = "YES" ]; then
    echo "Calculate the central values only ..."
    ${base_path}/analyze_lxfx.py "Lx" summary_lx.dat lx_result.txt ${BLIST}
    ${base_path}/analyze_lxfx.py "Fx" summary_fx.dat fx_result.txt ${BLIST}
    exit 0
fi


###########################################################
# Estimate the errors of Lx and Fx by Monte Carlo simulation
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

    echo "### `pwd -P`"
    echo "### ${i} / ${MC_TIMES} ###"
    ${base_path}/calc_coolfunc_bands.sh ${tprofile} ${abund} \
                ${nh} ${z} "cfunc_" ${BLIST}
    ${base_path}/${PROG} ${TMP_SBP_CFG} ${rout} \
                cfunc_bolo.dat \
                cfunc_0.7-7.dat \
                cfunc_0.1-2.4.dat 2> /dev/null
    LX1=`grep '^Lx1' ${LX_RES} | awk '{ print $2 }'`
    LX2=`grep '^Lx2' ${LX_RES} | awk '{ print $2 }'`
    LX3=`grep '^Lx3' ${LX_RES} | awk '{ print $2 }'`
    FX1=`grep '^Fx1' ${LX_RES} | awk '{ print $2 }'`
    FX2=`grep '^Fx2' ${LX_RES} | awk '{ print $2 }'`
    FX3=`grep '^Fx3' ${LX_RES} | awk '{ print $2 }'`

    echo "${LX1} ${LX2} ${LX3}" >>summary_lx.dat
    echo "${FX1} ${FX2} ${FX3}" >>summary_fx.dat
done # end of 'for'

# analyze Lx & Fx Monte Carlo results
${base_path}/analyze_lxfx.py "Lx" summary_lx.dat lx_result.txt ${BLIST}
${base_path}/analyze_lxfx.py "Fx" summary_fx.dat fx_result.txt ${BLIST}
