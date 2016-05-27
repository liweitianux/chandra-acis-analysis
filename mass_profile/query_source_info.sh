#!/bin/bash

#-------------------------------------------#
#Program: script for querying source info   #
#Author: Junhua Gu                          #
#return codes:                              #
#    1: usage not correct                   #
#    2: source not found                    #
#    3: redshift not available              #
#    4: heasoft not initialized             #
#    5: item invalid                        #
#Created at 20120822                        #
#-------------------------------------------#


if [ $# -ge 1 ]
then
:
else
    echo "Usage: $0 <source name> [item]"
    echo "Item can either be nh, z, norm, cm_per_pixel"
    exit 1
fi

if which nh >/dev/null
then
    :
else
    echo "Should initialize heasoft before hand"
    exit 4
fi

src_name=$1
#convert some special characters in the name into standard coded string
src_url_name=`perl -MURI::Escape -e "print uri_escape(\"$src_name\");" "$2"`
#form the url string
ned_url="http://ned.ipac.caltech.edu/cgi-bin/objsearch?objname=${src_url_name}&extend=no&hconst=73&omegam=0.27&omegav=0.73&corr_z=1&out_csys=Equatorial&out_equinox=J2000.0&obj_sort=RA+or+Longitude&of=ascii_bar&zv_breaker=30000.0&list_limit=5&img_stamp=YES"

#echo $ned_url
#fetch the ned web page

#if the string is leaded by <html>
#the source name cannot be resolved
#print an error message and exit

if wget --quiet "$ned_url" -O - >/dev/null
then
    :
else
    echo "Source not found"
    echo "Maybe the source name is not in a standard form"
    echo "Please check it manually"
    exit 2
fi

content=`wget --quiet "$ned_url" -O -|tail -1`
#echo $content

#extract interested information
ra=`echo $content |awk -F '|' '{print $3}'`
dec=`echo $content |awk -F '|' '{print $4}'`
z=`echo $content |awk -F '|' '{print $7}'`
ned_name=`echo $content |awk -F '|' '{print $2}'`

#echo $ra $dec $z
#use heasoft tool nh to calculate the weighted nh
ra_hhmmss=`echo $ra|awk '{printf("%sh%sm%ss",int($1/360*24),int((($1/360*24)%1*60)),(($1/360*24*60)%1*60))}'`
dec_ddmmss=`echo $dec|awk '{printf("%sd%sm%ss",sqrt($1*$1)/$1*int(sqrt($1*$1)),int(((sqrt($1*$1))%1*60)),((sqrt($1*$1)*60)%1*60))}'`
#echo $ra_hhmms
nh=`nh 2000 $ra $dec|tail -1`
#and convert to standard xspec unit
nh=`python -c "print(float(\"$nh\".split()[-1])/1e22)"`

if [ $# -eq 1 ]
then
    echo ned_name: $ned_name
    echo nh: $nh
    echo z: $z
    echo ra: $ra_hhmmss
    echo dec: $dec_ddmmss
fi

#what if the redshift is not available...
if [ x"$z" == "x" ]
then
    echo "no redshift data available"
    exit 3
fi

base_dir=`dirname $0`

cm_per_pixel=`$base_dir/calc_distance $z|grep ^cm_per_pixel|awk '{print $2}'`
norm=`$base_dir/calc_distance $z|grep ^norm|awk '{print $2}'`
Ez=`$base_dir/calc_distance $z|grep '^E(z)'|awk '{print $2}'`
if [ $# -eq 1 ]
then
    echo cm_per_pixel: $cm_per_pixel
    echo norm: $norm
    echo "E(z):" $Ez
fi
#normally exit

if [ $# -gt 1 ]
then
    item=$2
    if [ $item == "nh" ]
    then
	echo $nh
    elif [ $item == "z" ]
    then
	echo $z
    elif [ $item == "ra" ]
    then
	echo $ra_hhmmss
    elif [ $item == "dec" ]
    then
	echo $dec_ddmmss
    elif [ $item == "norm" ]
    then
	echo $norm
    elif [ $item == "cm_per_pixel" ]
    then
	echo $cm_per_pixel
    else
	echo "item invalid"
	exit 5
    fi
fi

