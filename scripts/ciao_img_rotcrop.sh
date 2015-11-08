#!/bin/sh
#
# Rotate the FITS image to be upright using 'dmregrid2',
# and crop the outside blank areas of the rotated image
# according to the CCD sizes.
#
# NOTE:
# * rotation angle is obtained from "ROLL_PNT" keyword
# * rotation center is the central point of the input image
#   (in _image_ coordinate and in pixel unit)
# * cropped image size is set to '1204x1204' for ACIS-S, and
#   '2066x2066' for ACIS-I
#
#
# Aaron LI
# 2015/08/23
#

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
    WIDTH="2066"
    HEIGHT="2066"
elif echo "${DETNAM}" | \grep -q 'ACIS-[0-6]*7'; then
    printf "## \`DETNAM' (${DETNAM}) has chip 7 => ACIS-S\n"
    WIDTH="1024"
    HEIGHT="1024"
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

