#!/bin/sh
#
# clean files in `mass' dir
#
# v2, 2013/05/04, LIweitiaNux
#   available for `empty mass dir'
#

IMG_DIR=${1:-../img}
SPC_DIR=${2:-../spc/profile}

if [ ! -f fitting_mass.conf ] || [ ! -f fitting_dbeta_mass.conf ]; then
    # empty mass dir
    printf "## EMPTY mass dir ...\n"
    rm -rf *.*

    # expcorr_conf
    EXPCORR_CONF=`ls ${IMG_DIR}/*_expcorr.conf 2> /dev/null`
    if [ ! -z "${EXPCORR_CONF}" ]; then
        Z=`grep '^z' ${EXPCORR_CONF} | awk '{ print $2 }'`
        N_H=`grep '^nh' ${EXPCORR_CONF} | awk '{ print $2 }'`
        ABUND=`grep '^abund' ${EXPCORR_CONF} | awk '{ print $2 }'`
        printf "# redshift: ${Z}\n"
        printf "# nh: ${N_H}\n"
        printf "# abund: ${ABUND}\n"
    fi

    # cosmo_calc
    COSMO_CALC=`which cosmo_calc 2> /dev/null`
    if [ ! -z "${COSMO_CALC}" ]; then
        CM_PER_PIXEL=`${COSMO_CALC} ${Z} | grep 'cm/pixel' | awk -F':' '{ print $2 }' | tr -d ' '`
        printf "# cm_per_pixel: ${CM_PER_PIXEL}\n"
    fi

    cat > wang2012_param.txt << _EOF_
A       5.0         1.0     500     T
n       5.0         0.1     10      T
xi      0.3         0.1     1.0     T
a2      2000        1000    1e+05   T
a3      1000        600     3000    T
beta    0.5         0.1     0.5     T
T0      1.0         1.0     2.0     T
_EOF_

    cat > fitting_mass.conf << _EOF_
t_profile           wang2012
t_data_file         tcl_temp_profile.txt
t_param_file        wang2012_param.txt
sbp_cfg             fitting_sbp.conf
nh                  ${N_H}
abund               ${ABUND}
radius_sbp_file     sbprofile.txt
# nfw_rmin_kpc        1
_EOF_

    cat > fitting_dbeta_mass.conf << _EOF_
t_profile           wang2012
t_data_file         tcl_temp_profile.txt
t_param_file        wang2012_param.txt
sbp_cfg             fitting_dbeta_sbp.conf
nh                  ${N_H}
abund               ${ABUND}
radius_sbp_file     sbprofile.txt
# nfw_rmin_kpc        1
_EOF_

    cat > fitting_sbp.conf << _EOF_
radius_file     radius_sbp.txt
sbp_file        flux_sbp.txt

cfunc_file      coolfunc_calc_data.txt
T_file          t_profile_dump.qdp

n0              0.005
rc              30
beta            0.7
bkg             0

cm_per_pixel    ${CM_PER_PIXEL}
z               ${Z}
_EOF_

    cat > fitting_dbeta_sbp.conf << _EOF_
radius_file     radius_sbp.txt
sbp_file        flux_sbp.txt

cfunc_file      coolfunc_calc_data.txt
T_file          t_profile_dump.qdp

n01             0.05
rc1             30
beta1           0.7
n02             0.005
rc2             300
beta2           0.7
bkg             0

cm_per_pixel    ${CM_PER_PIXEL}
z               ${Z}
_EOF_

    # link files
    [ -f ${IMG_DIR}/flux_sbp.txt ]         && ln -svf ${IMG_DIR}/flux_sbp.txt .
    [ -f ${IMG_DIR}/radius_sbp.txt ]       && ln -svf ${IMG_DIR}/radius_sbp.txt .
    [ -f ${IMG_DIR}/sbprofile.txt ]        && ln -svf ${IMG_DIR}/sbprofile.txt .
    [ -f ${SPC_DIR}/tcl_temp_profile.txt ] && ln -svf ${SPC_DIR}/tcl_temp_profile.txt .
    exit 0
fi

########################################################################
rm -rf _*
rm -rf *?backup*
rm -rf *backup?*
rm *_bak *.log
rm global.cfg flux_sbp.txt radius_sbp.txt sbprofile.txt
rm tcl_temp_profile.qdp tcl_temp_profile.txt

mkdir backup
cp fitting_mass.conf fitting_sbp.conf backup/
cp fitting_dbeta_mass.conf fitting_dbeta_sbp.conf backup/
cp beta_param_center.txt dbeta_param_center.txt backup/
cp wang2012_param.txt backup/
cp results_mrl.txt final_result.txt backup/

rm *.*

[ -f backup/fitting_sbp.conf ] && cp backup/fitting_sbp.conf .
[ -f backup/wang2012_param.txt ] && cp backup/wang2012_param.txt .
[ -f fitting_mass.conf ] && cp fitting_mass.conf fitting_dbeta_mass.conf
[ -f fitting_sbp.conf ] && cp fitting_sbp.conf fitting_dbeta_sbp.conf

SBP_CONF=`ls backup/fitting_sbp.conf backup/fitting_dbeta_sbp.conf 2>/dev/null | head -n 1`
EXPCORR_CONF=`ls ${IMG_DIR}/*_expcorr.conf`
N_H=`grep '^nh' ${EXPCORR_CONF} | awk '{ print $2 }'`

sed -i'' "s/^beta.*$/beta    0.5         0.1     0.7     T/" wang2012_param.txt

if [ -f backup/fitting_mass.conf ]; then
    # mass_conf
    cp backup/fitting_mass.conf .
    sed -i'' "s/^t_data_file.*$/t_data_file         tcl_temp_profile.txt/" fitting_mass.conf
    sed -i'' "s/^nh.*$/nh                  ${N_H}/" fitting_mass.conf
    cp fitting_mass.conf fitting_dbeta_mass.conf
    sed -i'' "s/fitting_sbp/fitting_dbeta_sbp/" fitting_dbeta_mass.conf
    # sbp_conf
    cp backup/fitting_sbp.conf .
    SBP_CONF="fitting_sbp.conf"
    SBP2_CONF="fitting_dbeta_sbp.conf"
elif [ -f backup/fitting_dbeta_mass.conf ]; then
    # mass_conf
    cp backup/fitting_mass.conf .
    cp backup/fitting_dbeta_mass.conf .
    sed -i'' "s/^t_data_file.*$/t_data_file         tcl_temp_profile.txt/" fitting_dbeta_mass.conf
    sed -i'' "s/^nh.*$/nh                  ${N_H}/" fitting_dbeta_mass.conf
    cp fitting_dbeta_mass.conf fitting_mass.conf
    sed -i'' "s/fitting_dbeta_sbp/fitting_sbp/" fitting_mass.conf
    # sbp_conf
    cp backup/fitting_dbeta_sbp.conf .
    SBP_CONF="fitting_dbeta_sbp.conf"
    SBP2_CONF="fitting_sbp.conf"
else
    #
    printf "*** ERROR: fitting_mass.conf & fitting_dbeta_mass.conf not exists ***\n"
fi

radius_file=`grep '^radius_file' $SBP_CONF | awk '{ print $2 }'`
sbp_file=`grep '^sbp_file' $SBP_CONF | awk '{ print $2 }'`
cfunc_file=`grep '^cfunc_file' $SBP_CONF | awk '{ print $2 }'`
T_file=`grep '^T_file' $SBP_CONF | awk '{ print $2 }'`
cm_per_pixel=`grep '^cm_per_pixel' $SBP_CONF | awk '{ print $2 }'`
z=`grep '^z' $SBP_CONF | awk '{ print $2 }'`

if [ "x${SBP2_CONF}" = "xfitting_sbp.conf" ]; then
    rm -f ${SBP2_CONF}
    cat > ${SBP2_CONF} << _EOF_
radius_file     $radius_file
sbp_file        $sbp_file

cfunc_file      $cfunc_file
T_file          $T_file

n0              0.005
rc              30
beta            0.7
bkg             0

cm_per_pixel    $cm_per_pixel
z               $z
_EOF_
elif [ "x${SBP2_CONF}" = "xfitting_dbeta_sbp.conf" ]; then
    rm -f ${SBP2_CONF}
    cat > ${SBP2_CONF} << _EOF_
radius_file     $radius_file
sbp_file        $sbp_file

cfunc_file      $cfunc_file
T_file          $T_file

n01             0.05
rc1             30
beta1           0.7
n02             0.005
rc2             300
beta2           0.7
bkg             0

cm_per_pixel    $cm_per_pixel
z               $z
_EOF_
else
    #
    printf "*** ERROR ***\n"
fi

[ -f ${IMG_DIR}/flux_sbp.txt ]         && ln -sf ${IMG_DIR}/flux_sbp.txt .
[ -f ${IMG_DIR}/radius_sbp.txt ]       && ln -sf ${IMG_DIR}/radius_sbp.txt .
[ -f ${IMG_DIR}/sbprofile.txt ]        && ln -sf ${IMG_DIR}/sbprofile.txt .
[ -f ${SPC_DIR}/tcl_temp_profile.txt ] && ln -sf ${SPC_DIR}/tcl_temp_profile.txt .

