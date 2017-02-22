#!/bin/sh
#
# Handy script for SBP fitting.
# This script wraps the 'fit_beta_sbp' and 'fit_dbeta_sbp',
# and automatically determine the sbp model according to the config file.
#
# Weitian LI
# 2013-02-20
#
# Change logs:
# 2017-02-07, Weitian LI
#   * Use `sbp_cfg` from command line argument, instead of the one specified
#     in the `mass.conf`
#   * Update the variable names according to the updated config files
#   * Some cleanups
#

if [ $# -ne 2 ]; then
    echo "usage: $0 <sbp.conf> <mass.conf>"
    exit 1
fi

sbp_cfg="$1"
mass_cfg="$2"

if [ "$0" = `basename $0` ]; then
    script_path=`which $0`
    base_path=`dirname ${script_path}`
else
    base_path=`dirname $0`
fi

nh=`grep '^nh' ${mass_cfg} | awk '{ print $2 }'`
abund=`grep '^abund' ${mass_cfg} | awk '{ print $2 }'`
tprofile_data=`grep '^tprofile_data' ${mass_cfg} | awk '{ print $2 }'`
tprofile_cfg=`grep '^tprofile_cfg' ${mass_cfg} | awk '{ print $2 }'`

z=`grep '^z' ${sbp_cfg} | awk '{ print $2 }'`
cm_per_pixel=`cosmo_calc.py -b --cm-per-pix ${z}`
sed -i'' "s/^cm_per_pixel.*$/cm_per_pixel   ${cm_per_pixel}/" ${sbp_cfg}
cfunc_profile=`grep '^cfunc_profile' ${sbp_cfg} | awk '{ print $2 }'`
tprofile=`grep '^tprofile' ${sbp_cfg} | awk '{ print $2 }'`

cfunc_table="coolfunc_table_photon.txt"

if grep -q '^beta2' ${sbp_cfg}; then
    MODEL="double-beta"
    PROG=fit_dbeta_sbp
else
    MODEL="single-beta"
    PROG=fit_beta_sbp
fi

${base_path}/fit_wang2012_model ${tprofile_data} ${tprofile_cfg} \
            ${cm_per_pixel} 2> /dev/null
cp wang2012_dump.qdp ${tprofile}
if [ ! -f ${cfunc_table} ]; then
    ${base_path}/calc_coolfunc_table.py -Z ${abund} -n ${nh} -z ${z} \
                -u photon -o ${cfunc_table}
fi
${base_path}/calc_coolfunc_profile.py -C -t ${cfunc_table} -T ${tprofile} \
            -o ${cfunc_profile}
${base_path}/${PROG} ${sbp_cfg}
echo "## MODEL: ${MODEL}"
echo "## z: ${z}"
