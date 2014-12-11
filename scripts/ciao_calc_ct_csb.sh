#!/bin/sh
#
###########################################################
## Invoke 'ciao_calc_ct.sh' and 'ciao_calc_csb.sh'       ##
## to calculate cooling time and Csb value.              ##
##                                                       ##
## Weitian LI                                            ##
## 2014/06/18                                            ##
##                                                       ##
## ChangeLog:                                            ##
## 1.1, 2014/12/11, Weitian LI                           ##
##   test ${CT_RES} before read                          ##
###########################################################

BASE_PATH=`dirname $0`
SCRIPT_CT="${BASE_PATH}/ciao_calc_ct.sh"
SCRIPT_CSB="${BASE_PATH}/ciao_calc_csb.sh"

echo "### CALCULATE COOLING TIME ###"
echo "### ${SCRIPT_CT} ###"
#ciao_calc_ct.sh
${SCRIPT_CT}

echo "### CALCULATE CSB VALUE ###"
echo "### ${SCRIPT_CSB} ###"
#ciao_calc_csb.sh
${SCRIPT_CSB}

echo "### PROCESS RESULTS ###"
CT_RES="cooling_results.txt"
CSB_RES="csb_results.txt"

# cooling time
if [ -r "${CT_RES}" ]; then
    TITLE_CT=`grep -E '^#\s*[A-Z]+' ${CT_RES} | awk -F',' '{ print $3 }'`
    DATA_CT=`grep -E '^#\s*[0-9]+' ${CT_RES} | awk -F',' '{ print $3 }'`
else
    TITLE_CT=""
    DATA_CT=""
fi

# Csb
TITLE_CSB=`grep -E '^#\s*[A-Z]+' ${CSB_RES}`
DATA_CSB=`grep -E '^#\s*[0-9]+' ${CSB_RES}`

# output data
echo "${TITLE_CSB},${TITLE_CT}"
echo "${DATA_CSB},${DATA_CT}"

exit 0

