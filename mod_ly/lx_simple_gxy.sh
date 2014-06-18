#!/bin/sh
#
unalias -a
export LC_COLLATE=C
# fix path for python
export PATH="/usr/bin:$PATH"
###########################################################
## calc lx, based on `calc_lx', modified for gxy         ##
##                                                       ##
## LIweitiaNux <liweitianux@gmail.com>                   ##
## November 3, 2012                                      ##
###########################################################

## usage, `path_conffile' is the configuration file
## which contains the `path' to each `repro/mass' directory
if [ $# -eq 1 ]; then
    # process dir
    MDIR="$1"
elif [ $# -eq 2 ]; then
    # process dir
    MDIR="$1"
    # separate log file
    MAIN_LOG="`pwd -P`/`basename $2`"
else
    printf "usage:\n"
    printf "    `basename $0` <mass_dir> [ <logfile> ]\n"
    printf "\nNOTE:\n"
    printf "   script cannot handle \`~' in path\n"
    exit 1
fi

if [ ! -d "${MDIR}" ]; then
    printf "## ERROR: given \`${MDIR}' not a directory\n"
    exit 2
fi
if [ -d "${MAIN_LOG}" ]; then
    printf "## ERROR: given \`${MAIN_LOG}' IS a file\n"
    exit 3
fi

## set the path to the script {{{
if [ "$0" = `basename $0` ]; then
    script_path=`which $0`
    base_path=`dirname ${script_path}`
else
    base_path=`dirname $0`
fi
LX1_SCRIPT="$base_path/luminosity_0.1-2.4_lwt.sh"
LX2_SCRIPT="$base_path/luminosity_0.5-2_lwt.sh"
if [ ! -e "${LX1_SCRIPT}" ] || [ ! -e "${LX2_SCRIPT}" ]; then
    printf "ERROR: \`LX_SCRIPT' not exist\n"
    exit 250
fi
## script path }}}

# result lines
RES_LINE=100

# process
cd ${MDIR}
printf "Entered dir: \``pwd`'\n"
# mass fitting conf
MCONF="`ls fitting_mass.conf global.cfg 2> /dev/null | head -n 1`"
if [ ! -r "${MCONF}" ]; then
    printf "ERROR: main configuration file not accessiable\n"
    exit 10
else
    printf "## use main configuration file: \`${MCONF}'\n"
    LOGFILE="lx_gxy_`date '+%Y%m%d%H'`.log"
    [ -e "${LOGFILE}" ] && mv -fv ${LOGFILE} ${LOGFILE}_bak
    TOLOG="tee -a ${LOGFILE}"
    printf "## use logfile: \`${LOGFILE}'\n"
    if [ ! -z "${MAIN_LOG}" ]; then
        printf "## separate main logfile: \`${MAIN_LOG}'\n"
    fi
    printf "## working directory: \``pwd -P`'\n" | ${TOLOG}
    printf "## use configuration files: \`${MCONF}'\n" | ${TOLOG}
    # fitting_mass logfile, get R500 from it
    MLOG=`ls ${MCONF%.[confgCONFG]*}*.log | tail -n 1`
    if [ ! -r "${MLOG}" ]; then
        printf "## ERROR: mass log file not accessiable\n"
        exit 20
    fi
    R500_VAL=`tail -n ${RES_LINE} ${MLOG} | grep '^r500' | head -n 1 | awk '{ print $2 }'`
    R200_VAL=`tail -n ${RES_LINE} ${MLOG} | grep '^r200' | head -n 1 | awk '{ print $2 }'`
    if [ -z "${R500_VAL}" ] || [ -z "${R200_VAL}" ]; then
        printf "## ERROR: cannot get R500 or R200\n"
        exit 30
    fi
    printf "## R200 (kpc): \`${R200_VAL}'\n" | ${TOLOG}
    printf "## R500 (kpc): \`${R500_VAL}'\n" | ${TOLOG}
    printf "## CMD: ${LX1_SCRIPT} ${MCONF} ${R200_VAL} ${R500_VAL}\n" | ${TOLOG}
#    printf "## CMD: ${LX2_SCRIPT} ${MCONF} ${R200_VAL} ${R500_VAL}\n" | ${TOLOG}
    sh ${LX1_SCRIPT} ${MCONF} ${R200_VAL} ${R500_VAL} | ${TOLOG}
#    sh ${LX2_SCRIPT} ${MCONF} ${R200_VAL} ${R500_VAL} | ${TOLOG}
    ## append results to main log file
    if [ ! -z "${MAIN_LOG}" ]; then
        printf "\n" >> ${MAIN_LOG}
        printf "`pwd -P`\n" >> ${MAIN_LOG}
        grep '^L[25]00' ${LOGFILE} >> ${MAIN_LOG}
    fi
fi
printf "\n++++++++++++++++++++++++++++++++++++++\n"

