#!/bin/sh
#
unalias -a
export LC_COLLATE=C
# fix path for python
export PATH="/usr/bin:$PATH"
###########################################################
## calc_lx in BATCH mode                                 ##
##                                                       ##
## LIweitiaNux <liweitianux@gmail.com>                   ##
## August 31, 2012                                       ##
##                                                       ##
## ChangeLog:                                            ##
##  2014/06/18: use env variable 'MASS_PROFILE_DIR'      ##
###########################################################

## usage, `path_conffile' is the configuration file
## which contains the `path' to each `repro/mass' directory
if [ $# -ne 1 ]; then
    printf "usage:\n"
    printf "    `basename $0` <mass_dir>\n"
    printf "\nNOTE:\n"
    printf "   script cannot handle \`~' in path\n"
    exit 1
fi

## set the path to the script {{{
if [ -n "${MASS_PROFILE_DIR}" ]; then
    CALCLX_SCRIPT="${MASS_PROFILE_DIR}/calc_lx"
    CFCALC_SCRIPT="${MASS_PROFILE_DIR}/coolfunc_calc.sh"
    FIT_TPRO="${MASS_PROFILE_DIR}/fit_wang2012_model"
else
    printf "ERROR: environment variable 'MASS_PROFILE_DIR' not set.\n"
    exit 2
fi

if [ -z "${CALCLX_SCRIPT}" ]; then
    printf "ERROR: \`CALCLX_SCRIPT' not set\n"
    exit 250
elif [ ! -r ${CALCLX_SCRIPT} ]; then
    printf "ERROR: CANNOT access script \`${CALCLX_SCRIPT}'\n"
    exit 251
fi
## script path }}}

# result lines
RES_LINE=100
# process dir
MDIR="$1"
# mass fitting conf
MCONF="fitting_mass.conf"

# process
cd ${MDIR}
printf "Entered dir: \``pwd`'\n"
# conf file
if [ ! -r "${MCONF}" ]; then
    printf "ERROR: configuration file \`${MCONF}' not accessiable\n"
else
    LOGFILE="calclx_`date '+%Y%m%d%H'`.log"
    [ -e "${LOGFILE}" ] && mv -fv ${LOGFILE} ${LOGFILE}_bak
    TOLOG="tee -a ${LOGFILE}"
    # fitting_mass logfile, get R500 from it
    MLOG=`ls ${MCONF%.[confgCONFG]*}*.log | tail -n 1`
    R500_VAL=`tail -n ${RES_LINE} ${MLOG} | grep '^r500' | awk '{ print $2 }'`
    R200_VAL=`tail -n ${RES_LINE} ${MLOG} | grep '^r200' | awk '{ print $2 }'`
    # radius_sbp_file {{{
    RSBP=`grep '^radius_sbp_file' ${MCONF} | awk '{ print $2 }'`
    TMP_RSBP="_tmp_rsbp.txt"
    [ -e "${TMP_RSBP}" ] && rm -f ${TMP_RSBP}
    cat ${RSBP} | sed 's/#.*$//' | grep -Ev '^\s*$' > ${TMP_RSBP}
    RSBP="${TMP_RSBP}"
    # rsbp }}}
    TPRO_TYPE=`grep '^t_profile' ${MCONF} | awk '{ print $2 }'`
    TPRO_DATA=`grep '^t_data_file' ${MCONF} | awk '{ print $2 }'`
    TPRO_PARA=`grep '^t_param_file' ${MCONF} | awk '{ print $2 }'`
    SBP_CONF=`grep '^sbp_cfg' ${MCONF} | awk '{ print $2 }'`
    ABUND=`grep '^abund' ${MCONF} | awk '{ print $2 }'`
    NH=`grep '^nh' ${MCONF} | awk '{ print $2 }'`
    Z=`grep '^z' ${SBP_CONF} | awk '{ print $2 }'`
    cm_per_pixel=`grep '^cm_per_pixel' ${SBP_CONF} | awk '{ print $2 }'`
    CF_FILE=`grep '^cfunc_file' ${SBP_CONF} | awk '{ print $2 }'`
    printf "## use logfile: \`${LOGFILE}'\n"
    printf "## working directory: \``pwd -P`'\n" | ${TOLOG}
    printf "## use configuration files: \`${MCONF}, ${SBP_CONF}'\n" | ${TOLOG}
    printf "## use radius_sbp_file: \`${RSBP}'\n" | ${TOLOG}
    printf "## R500 (kpc): \`${R500_VAL}'\n" | ${TOLOG}
    printf "## R200 (kpc): \`${R200_VAL}'\n" | ${TOLOG}
    printf "## redshift: \`${Z}'\n" | ${TOLOG}
    printf "## abund: \`${ABUND}'\n" | ${TOLOG}
    printf "## nh: \`${NH}'\n" | ${TOLOG}
    printf "## T_profile type: \`${TPRO_TYPE}'\n" | ${TOLOG}
    printf "## cfunc_file: \`${CF_FILE}'\n" | ${TOLOG}
    ## fit temperature profile {{{
    T_FILE="_tpro_dump.qdp"
    if [ "${TPRO_TYPE}" = "wang2012" ]; then
        printf "fitting temperature profile (wang2012) ...\n"
        [ -e "wang2012_dump.qdp" ] && mv -fv wang2012_dump.qdp wang2012_dump.qdp_bak
        [ -e "fit_result.qdp" ] && mv -fv fit_result.qdp fit_result.qdp_bak
        ${FIT_TPRO} ${TPRO_DATA} ${TPRO_PARA} ${cm_per_pixel} 2> /dev/null
        mv -fv wang2012_dump.qdp ${T_FILE}
        [ -e "wang2012_dump.qdp_bak" ] && mv -fv wang2012_dump.qdp_bak wang2012_dump.qdp
        [ -e "fit_result.qdp_bak" ] && mv -fv fit_result.qdp_bak fit_result.qdp
    else
        printf "ERROR: invalid tprofile type: \`${TPRO_TYPE}'\n"
        exit 10
    fi
    ## tprofile }}}
    ## calc `flux_ratio' {{{
    printf "calc flux_ratio ...\n"
    CF_FILE="_cf_data.txt"
    FLUX_RATIO="__flux_cnt_ratio.txt"
    [ -e "flux_cnt_ratio.txt" ] && mv -fv flux_cnt_ratio.txt flux_cnt_ratio.txt_bak
    printf "## CMD: sh ${CFCALC_SCRIPT} ${T_FILE} ${ABUND} ${NH} ${Z} ${CF_FILE}\n" | ${TOLOG}
    sh ${CFCALC_SCRIPT} ${T_FILE} ${ABUND} ${NH} ${Z} ${CF_FILE}
    mv -fv flux_cnt_ratio.txt ${FLUX_RATIO}
    [ -e "flux_cnt_ratio.txt_bak" ] && mv -fv flux_cnt_ratio.txt_bak flux_cnt_ratio.txt
    ## flux_ratio }}}
    printf "## CMD: ${CALCLX_SCRIPT} ${RSBP} ${FLUX_RATIO} ${Z} ${R500_VAL} ${TPRO_DATA}\n" | ${TOLOG}
    printf "## CMD: ${CALCLX_SCRIPT} ${RSBP} ${FLUX_RATIO} ${Z} ${R200_VAL} ${TPRO_DATA}\n" | ${TOLOG}
    L500=`${CALCLX_SCRIPT} ${RSBP} ${FLUX_RATIO} ${Z} ${R500_VAL} ${TPRO_DATA} | grep '^Lx' | awk '{ print $2,$3,$4 }'`
    L200=`${CALCLX_SCRIPT} ${RSBP} ${FLUX_RATIO} ${Z} ${R200_VAL} ${TPRO_DATA} | grep '^Lx' | awk '{ print $2,$3,$4 }'`
    printf "L500= ${L500} erg/s\n" | ${TOLOG}
    printf "L200= ${L200} erg/s\n" | ${TOLOG}
fi
printf "\n++++++++++++++++++++++++++++++++++++++\n"

