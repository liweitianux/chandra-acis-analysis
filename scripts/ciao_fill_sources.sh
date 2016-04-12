#!/bin/sh
#
# Fill the detected source regions by sampling from their surrounding
# regions, using CIAO `roi' and `dmfilth'.
#
# NOTE:
# * The `dmfilth' only operates on the FITS image, NOT event table.
# * Make `dmfilth' operates on the ONLY DEFLARED image (WITHOUT point
#   sources excluded/removed) (see the CAVEAT of script `ciao_img_rotcrop.sh')
#
# References:
# [1] An Image of Diffuse Emission - CIAO
#     http://cxc.harvard.edu/ciao/threads/diffuse_emission/
#
#
# Aaron LI
# Created: 2016-04-11
UPDATED="2016-04-12"


usage() {
    echo "usage:"
    echo "    `basename $0` evt=<evt.fits> outfile=<filled_img> erange=<elow:ehigh> reg=<sources.reg> repro=<repro_dir_relapath>"
    echo ""
    echo "version: ${UPDATED}"
}

# process commandline arguments of format: `KEY=VALUE'
getopt_keyval() {
    until [ -z "$1" ]
    do
        _key=${1%%=*}                    # extract key
        _val=${1#*=}                     # extract value
        _keyval="${_key}=\"${_val}\""
        echo "## getopt: eval '${_keyval}'"
        eval ${_keyval}
        shift                           # shift, process next one
    done
    unset _key _val _keyval
}

# set CIAO pfiles
# syntax: set_pfiles tool1 tool2 ...
set_pfiles() {
    while [ ! -z "$1" ]; do
        _tool="$1"
        shift
        _pfile=`paccess ${_tool}`
        [ -n "${_pfile}" ] && punlearn ${_tool} && cp -Lvf ${_pfile} .
    done
    # Modify environment variable 'PFILES' to use local pfiles first
    export PFILES="./:${PFILES}"
    unset _tool _pfile
}

# set arguments/variables
# syntax: set_variable VAR_NAME default_value cmdline_value
set_variable() {
    _var="$1"
    _default="$2"
    _cmd="$3"
    if [ ! -z "${_cmd}" ]; then
        _value="${_cmd}"
    elif [ ! -z "${_default}" ]; then
        _value="${_default}"
    else
        echo "ERROR: variable '${_var}' get none value"
        exit 11
    fi
    eval "${_var}=${_value}"
    unset _var _default _cmd _value
}

# syntax: set_variable VAR_NAME default_ls_pattern cmdline_value
set_variable_pattern() {
    _default_pat="$2"
    if [ `\ls ${_default_pat} 2>/dev/null | wc -l` -eq 0 ]; then
        echo "ERROR: ls pattern '${_default_pat}' not found"
        exit 21
    elif [ `\ls ${_default_pat} 2>/dev/null | wc -l` -eq 1 ]; then
        _default="`\ls ${_default_pat} 2>/dev/null`"
        set_variable "$1" "${_default}" "$3"
    else
        echo "ERROR: ls pattern '${_default_pat}' found more than 1 values"
        exit 22
    fi
    unset _default_pat _default
}

# determine the ACIS type: whether "S" or "I"
get_acis_type() {
    punlearn dmkeypar
    _detnam=`dmkeypar "$1" DETNAM echo=yes`
    if echo "${_detnam}" | \grep -q 'ACIS-0123'; then
        echo "I"
    elif echo "${_detnam}" | \grep -q 'ACIS-[0-6]*7'; then
        echo "S"
    else
        printf "ERROR: unknown detector type: ${DETNAM}\n"
        exit 31
    fi
    unset _detnam
}


case "$1" in
    -[hH]*|--[hH]*)
        usage
        exit 1
        ;;
esac

# arguments
getopt_keyval "$@"
set_variable_pattern EVT "evt2_c7_deflare.fits evt2_c0-3_deflare.fits" ${evt}
set_variable ERANGE "700:7000" ${erange}
ROOTNAME="${EVT%_deflare.fits}_e`echo ${ERANGE} | tr ':' '-'`"
ROOTNAME="${ROOTNAME#evt2_}"
set_variable OUTFILE "img_${ROOTNAME}_fill.fits" ${outfile}
set_variable_pattern REG "celld_evt2_c7.reg celld_evt2_c0-3.reg" ${reg}
set_variable REPRO ".." ${repro}

set_pfiles skyfov dmcopy dmkeypar dmmakereg roi dmfilth

# Aspect/asol
ASOL_LIS=`\ls ${REPRO}/acisf*_asol1.lis`

# Generate FoV file, since some obs. do NOT provide the `fov1.fits' file
# NOTE: the parameter `aspec' should be provided for the correct FoV
echo "Make skyfov file ..."
FOV="skyfov.fits"
punlearn skyfov
skyfov infile=${EVT} outfile=${FOV} aspect="@${ASOL_LIS}" clobber=yes

# Filter energy
EVT_E="evt2_${ROOTNAME}_deflare.fits"
if [ ! -e "${EVT_E}" ]; then
    echo "Filter by energy range ..."
    punlearn dmcopy
    dmcopy infile="${EVT}[energy=${ERANGE}]" outfile=${EVT_E}
fi

# Make image
IMG="img_${ROOTNAME}_deflare.fits"
if [ ! -e "${IMG}" ]; then
    echo "Make FITS image ..."
    ACIS_TYPE=`get_acis_type ${EVT_E}`
    if [ "${ACIS_TYPE}" = "I" ]; then
        CCD=0:3
    else
        CCD=7
    fi
    punlearn dmcopy
    dmcopy infile="${EVT_E}[sky=region(${FOV}[ccd_id=${CCD}])][bin sky=1]" \
        outfile=${IMG}
fi

# Convert ASCII region to FITS format
echo "Convert region to FITS format ..."
REG_FITS="${REG%.reg}.fits"
punlearn dmmakereg
dmmakereg region="region(${REG})" outfile="${REG_FITS}" clobber=yes

# Determine the background regions for each source
echo "Determine the background regions for each source ..."
ROI_TMP_DIR="_tmp_roi"
[ -d "${ROI_TMP_DIR}" ] && rm -rf ${ROI_TMP_DIR}
mkdir ${ROI_TMP_DIR}
punlearn roi
roi infile="${REG_FITS}" outsrcfile="${ROI_TMP_DIR}/src_%d.fits" \
    fovregion="region(${FOV})" streakregion="" bkgfactor=0.5 \
    radiusmode=mul bkgradius=3 clobber=yes

# Combine all the background regions
echo "Combine all regions ..."
REG_FILL_ROOT="fill"
REG_FILL_SRC="${REG_FILL_ROOT}.src.reg"
REG_FILL_BKG="${REG_FILL_ROOT}.bg.reg"
REG_FILL_BKG2="${REG_FILL_ROOT}.bg.fits"
splitroi "${ROI_TMP_DIR}/src_*.fits" ${REG_FILL_ROOT}
punlearn dmmakereg
dmmakereg region="region(${REG_FILL_BKG})" \
    outfile=${REG_FILL_BKG2} clobber=yes

# Fill the source regions using `dmfilth'
echo "Fill the source regions ..."
punlearn dmfilth
dmfilth infile=${IMG} outfile=${OUTFILE} method=DIST \
    srclist="@${REG_FILL_SRC}" bkglist="@${REG_FILL_BKG}" clobber=yes

rm -rf ${ROI_TMP_DIR}

