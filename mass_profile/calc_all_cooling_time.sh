#!/usr/bin/env bash

if [ $# -eq 1 ]
then
    :
else
    echo "Usage: <global.cfg list file>"
    exit
fi

bdir=`pwd`
base_path=`dirname $0`
for i in `cat $1`
do
    dname=`dirname $i`
    #dname=`dirname $dname`
    echo $dname
    cd $dname ||continue
    sbp_cfg=`grep sbp_cfg global.cfg|awk '{print $2}'`
    if  grep n01 $sbp_cfg  >/dev/null
    then
	echo "dbeta"
	$base_path/fit_dbeta_nfw_mass_profile.sh global.cfg c
    else
	echo "beta"
	$base_path/fit_beta_nfw_mass_profile.sh global.cfg c
    fi
    
    cd $bdir
done
