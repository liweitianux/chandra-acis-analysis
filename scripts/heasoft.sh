#!/bin/sh
#
# A wrapper script for the HEASoft tools, to avoid the annoying
# conflicts between system libraries and the HEASoft bundled
# libraries due to the '$LD_LIBRARY_PATH' settings.
#
# This wrapper is inspired by CIAO.
#
# Weitian LI <liweitianux@live.com>
# Created: 2013-05-18
# Updated: 2018-05-16
#
#
# Setup:
# ------------------------------------------------------------------------
# 1. Copy this wrapper to '~/.heasoft/heasoft.sh'.
# 2. Add the following shell function to your shell config file.
#    NOTE: edit 'HEADAS' to match your case.
#
# Shell configuration:
# ------------------------------------------------------------------------
# heainit() {
#     local ld_lib_bak i tool
#     local wrapper="${HOME}/.heasoft/heasoft.sh"
#     local wrapper_dir=$(dirname ${wrapper})
#     local wrapper_name=$(basename ${wrapper})
#     if [ -z "${HEADAS}" ]; then
#         ld_lib_bak=${LD_LIBRARY_PATH}
#         export HEADAS="${HOME}/local/heasoft/default/PORTAL"
#         source ${HEADAS}/headas-init.sh
#         export LD_LIBRARY_PATH=${ld_lib_bak}
#         export PATH="${wrapper_dir}:${PATH}"
#
#         if [ ! -f "${wrapper}" ]; then
#             echo "ERROR: wrapper '${wrapper}' not found!"
#             return
#         fi
#         chmod u=rwx ${wrapper}
#
#         echo "Initializing HEASoft from ${HEADAS} ..."
#         for i in ${HEADAS}/bin/*; do
#             tool=$(basename $i)
#             ln -sf ${wrapper_name} ${wrapper_dir}/${tool}
#         done
#
#         echo "HEASoft initialized."
#     else
#         echo "HEASoft already initialized from: ${HEADAS}"
#     fi
# }
# ------------------------------------------------------------------------

TOOL="${0##*/}"
BIN_PATH="${HEADAS}/bin"
LD_LIBRARY_PATH="${HEADAS}/lib"

if [ -z "${HEADAS}" ]; then
    echo "ERROR: environment variable 'HEADAS' not set!" >&2
    exit 1
elif [ -x "${BIN_PATH}/${TOOL}" ]; then
    export LD_LIBRARY_PATH
    exec ${BIN_PATH}/${TOOL} "$@"
else
    echo "ERROR: tool '${TOOL}' not found in ${BIN_PATH}!" >&2
    exit 2
fi

