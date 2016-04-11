#!/bin/sh
#
# Rotate the FITS image to be upright using 'dmregrid2',
# and crop the blank edges from the rotated image
# according to the CCDs sizes.
#
# NOTE:
# * rotation center is set to be the center of the input image
#   (in *image* coordinate and in pixel unit)
# * rotation angle is obtained from the "ROLL_PNT" keyword
# * cropped image size is set to '1010x1010' for ACIS-S, and
#   '2060x2060' for ACIS-I
#
#
# Aaron LI
# Created: 2015-08-23
# Updated: 2016-04-11
#

WIDTH_ACIS_S="1010"
HEIGHT_ACIS_S="1010"
WIDTH_ACIS_I="2060"
HEIGHT_ACIS_I="2060"


if [ $# -ne 2 ]; then
    printf "Usage:\n"
    printf "    `basename $0` <input_img> <output_img>\n"
    exit 1
fi

INIMG="$1"
OUTIMG="$2"

# Get the rotation angle from "ROLL_PNT" keyword
punlearn dmkeypar
ROTANGLE=`dmkeypar ${INIMG} ROLL_PNT echo=yes`
printf "## rotation angle (degree): ${ROTANGLE}\n"

# Determine the rotation center
ROTXCENTER=`dmlist ${INIMG} blocks | grep '^Block.*1:' | tr '(x)' ' ' | awk '{ print $(NF-1)/2 }'`
ROTYCENTER=`dmlist ${INIMG} blocks | grep '^Block.*1:' | tr '(x)' ' ' | awk '{ print $NF/2 }'`
printf "## rotation center (pixel): (${ROTXCENTER},${ROTYCENTER})\n"

# Rotate the image with "dmregrid2"
printf "# rotate image ...\n"
TMP_ROT_IMG="_rot_${INIMG}"
punlearn dmregrid2
dmregrid2 infile="${INIMG}" outfile="${TMP_ROT_IMG}" \
    theta=${ROTANGLE} rotxcenter=${ROTXCENTER} rotycenter=${ROTYCENTER} \
    clobber=yes

# Determine the central point in _physical_ coordinate of the rotated image
punlearn get_sky_limits
get_sky_limits ${TMP_ROT_IMG} verbose=0
XYGRID=`pget get_sky_limits xygrid`
XC=`echo "${XYGRID}" | awk -F'[:,]' '{ print 0.5*($1+$2) }'`
YC=`echo "${XYGRID}" | awk -F'[:,]' '{ print 0.5*($4+$5) }'`

# Determine the crop box size
## determine ACIS type {{{
punlearn dmkeypar
DETNAM=`dmkeypar ${TMP_ROT_IMG} DETNAM echo=yes`
if echo "${DETNAM}" | \grep -q 'ACIS-0123'; then
    printf "## \`DETNAM' (${DETNAM}) has chips 0123 => ACIS-I\n"
    WIDTH=${WIDTH_ACIS_S}
    HEIGHT=${HEIGHT_ACIS_S}
elif echo "${DETNAM}" | \grep -q 'ACIS-[0-6]*7'; then
    printf "## \`DETNAM' (${DETNAM}) has chip 7 => ACIS-S\n"
    WIDTH=${WIDTH_ACIS_I}
    HEIGHT=${HEIGHT_ACIS_I}
else
    printf "ERROR: unknown detector type: ${DETNAM}\n"
    exit 11
fi
printf "## set crop box size: ${WIDTH}x${HEIGHT}\n"
## ACIS type }}}
CROP_REG="rotbox(${XC},${YC},${WIDTH},${HEIGHT},0)"
printf "## crop region: ${CROP_REG}\n"

# Crop the rotated image to match CCD size
printf "# crop rotated image ...\n"
punlearn dmcopy
dmcopy "${TMP_ROT_IMG}[sky=${CROP_REG}]" ${OUTIMG} clobber=yes

# Clean temporary file
rm -f ${TMP_ROT_IMG}

