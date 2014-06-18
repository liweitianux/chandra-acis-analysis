#!/bin/sh

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <cfg_file> <R200> <R500>"
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
#printf "## PGPLOT_FONT: \`${PGPLOT_FONT}'\n"

if [ "$0" = `basename $0` ]; then
    script_path=`which $0`
    base_path=`dirname ${script_path}`
else
    base_path=`dirname $0`
fi
#printf "## base_path: \`${base_path}'\n"
cfg_file="$1"
#printf "## use configuration file: \`${cfg_file}'\n"
R200=$2
R500=$3

#read -p "R200:" R200
#read -p "R500:" R500

#initialize data file name
t_data_file=`grep '^t_data_file' $cfg_file | awk '{print $2}'`
#t_param_file=`grep '^t_param_file' $cfg_file | awk '{print $2}'`
#initialize sbp config file
sbp_cfg=`grep '^sbp_cfg' $cfg_file | awk '{print $2}'`
#initialize the temperature profile file
T_file=`grep '^T_file' $sbp_cfg | awk '{print $2}'`
cfunc_file=`grep '^cfunc_file' ${sbp_cfg} |awk '{print $2}'`
abund=`grep '^abund' ${cfg_file} |awk '{print $2}'`
nh=`grep '^nh' ${cfg_file} |awk '{print $2}'`
## calc `cm_per_pixel' instead {{{
cm_per_pixel=`grep '^cm_per_pixel' $sbp_cfg|awk '{print $2}'`
z=`grep '^z' $sbp_cfg | awk '{ print $2 }'`
cm_per_pixel=`${base_path}/calc_distance ${z} | grep 'cm_per_pixel' | awk '{ print $2 }'`
sed -i'' "s/^cm_per_pixel.*$/cm_per_pixel    ${cm_per_pixel}/" ${sbp_cfg}
#printf "## redshift: ${z}, cm_per_pixel: ${cm_per_pixel}\n"
## cm_per_pixel }}}
## sbp {{{
#sbp_data_file=`grep '^sbp_file' $sbp_cfg | awk '{print $2}'`
radius_sbp_file=`grep '^radius_sbp_file' ${cfg_file} | awk '{print $2}'`
if [ "x$radius_sbp_file" = "x" ]; then
    echo "ERROR, must have radius_sbp_file assigned, this file should be a 4-column file, which contains the radius, radius err, sbp, and sbp err"
    exit 200
fi

TMP_RSBP="_tmp_rsbp.txt"
[ -e "${TMP_RSBP}" ] && rm -f ${TMP_RSBP}
cat ${radius_sbp_file} | sed 's/#.*$//' | grep -Ev '^\s*$' > ${TMP_RSBP}
radius_sbp_file="${TMP_RSBP}"
## sbp }}}

[ -e "flux_cnt_ratio.txt" ] && mv -fv flux_cnt_ratio.txt flux_bolo_cnt_ratio.txt
[ -e "flux_cnt_ratio_center.txt" ] && mv -fv flux_cnt_ratio_center.txt flux_bolo_cnt_ratio_center.txt

$base_path/coolfunc_0.5-2_calc_rs.sh ${T_file} $abund $nh $z $cfunc_file
mv -fv flux_cnt_ratio.txt flux_0.5-2_cnt_ratio_center.txt

L200_flux0520=`$base_path/calc_lx $radius_sbp_file flux_0.5-2_cnt_ratio_center.txt $z ${R200} $t_data_file | grep '^Lx' | awk '{ print $2,$3,$4 }'`
L500_flux0520=`$base_path/calc_lx $radius_sbp_file flux_0.5-2_cnt_ratio_center.txt $z ${R500} $t_data_file | grep '^Lx' | awk '{ print $2,$3,$4 }'`
printf "L200_0.5-2= ${L200_flux0520} erg/s\n"
printf "L500_0.5-2= ${L500_flux0520} erg/s\n"

