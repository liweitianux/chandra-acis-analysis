#!/usr/bin/env bash

if [ $# -eq 1 ]
then
    :
else
    echo "Usage: <global.cfg list file>"
    exit
fi

bdir=`pwd`

for i in `cat $1`
do
    dname=`dirname $i`
    #dname=`dirname $dname`
    echo $dname
    cd $dname ||continue
#    mkdir -p profile_entropy
#    cp -rf profile/* profile_entropy/
#    cd profile/
    
    [ -e result ] && r200file=result
    [ -e result ] || r200file=result_checked
    
    r200=`grep r200 $r200file|awk -F = '{print $2}' |awk -F '-' '{print $1}'`
    rout=`python -c "print($r200*.1)"`
    echo $rout
    if  grep n01 source.cfg  >/dev/null
    then
	echo "dbeta"
	fit_dbeta_entropy.sh global.cfg $rout
    else
	echo "beta"
	fit_beta_entropy.sh global.cfg $rout
    fi
    
    cd $bdir
done
