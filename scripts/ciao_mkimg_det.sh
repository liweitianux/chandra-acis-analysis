#!/bin/sh
#
# Make an image from evt2 file by binning the 'TDET' coordinates.
# If the 'TDET' coordinate information is not available (e.g., blanksky),
# the 'DET' coordinate is used for binning.
#
# Aaron LI
# 2015/08/21
#

if [ $# -ne 2 ]; then
    printf "Usage:\n"
    printf "    `basename $0` <input:evt2> <output:img>\n"
    exit 1
fi

EVT2="$1"
OUTIMG="$2"

# Test whether 'TEDT' coordinate exists?
if dmlist ${EVT2} cols | grep -q tdet; then
    COORDX="tdetx"
    COORDY="tdety"
else
    printf "WARNING: tdet coordinate NOT exist! use det instead.\n"
    COORDX="detx"
    COORDY="dety"
fi

# Get TDET/DET coordinate min & max values
# COORDX:
punlearn dmstat
dmstat "${EVT2}[cols ${COORDX}]" >/dev/null 2>&1
XMIN=`pget dmstat out_min`
XMAX=`pget dmstat out_max`
dmstat "${EVT2}[cols ${COORDY}]" >/dev/null 2>&1
YMIN=`pget dmstat out_min`
YMAX=`pget dmstat out_max`

BINSPEC="[bin ${COORDX}=${XMIN}:${XMAX}:1,${COORDY}=${YMIN}:${YMAX}:1]"

punlearn dmcopy
CMD="dmcopy \"${EVT2}${BINSPEC}\" ${OUTIMG}"
printf "CMD: ${CMD}\n"
eval ${CMD}

