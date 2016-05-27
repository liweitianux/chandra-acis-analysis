#!/bin/bash

tmp_beta_cfg="_tmp_beta.cfg"
tmp_dbeta_cfg="_tmp_dbeta.cfg"
base_path=`dirname $0`
rm -f $tmp_beta_cfg
rm -f $tmp_dbeta_cfg



if [ $# -lt 1 ]
then
    for i in radius_file sbp_file cfunc_file T_file
    do
	file=`zenity --file-selection --title="$i"`
	echo $i $file >>$tmp_beta_cfg
    done

    for i in n0 rc beta bkg cm_per_pixel z
    do
	value=`zenity --entry --text="entry initial value for $i"`
	echo $i $value >>$tmp_beta_cfg
    done
else
    cp $1 $tmp_beta_cfg
fi

rfile=`grep radius_file $tmp_beta_cfg|awk '{print $2}'`
sfile=`grep sbp_file $tmp_beta_cfg|awk '{print $2}'`
cfile=`grep cfunc_file $tmp_beta_cfg|awk '{print $2}'`
tfile=`grep T_file $tmp_beta_cfg|awk '{print $2}'`

$base_path/fit_beta_sbp $tmp_beta_cfg
rm -f pgplot.gif
qdp sbp_fit.qdp<<EOF 
/null
log
plot
cpd pgplot.gif/gif
plot
quit
EOF

eog pgplot.gif&
sleep 3
kill $! >/dev/null

if zenity --question --text="single beta ok?"
then
    mv beta_param.txt sbp_param.txt
    exit
fi

if [ $# -lt 2 ]
then
    echo radius_file $rfile >>$tmp_dbeta_cfg
    echo sbp_file $sfile >>$tmp_dbeta_cfg
    echo cfunc_file $cfile >>$tmp_dbeta_cfg
    echo T_file $tfile >>$tmp_dbeta_cfg
    

    for i in cm_per_pixel z n01 rc1 beta1 n02 rc2 beta2 bkg
    do
        value=`zenity --entry --text="entry initial value for $i"`
        echo $i $value >>$tmp_dbeta_cfg
    done
else
    cp $2 $tmp_dbeta_cfg
fi


$base_path/fit_dbeta_sbp5 $tmp_dbeta_cfg
rm -f pgplot.gif
qdp sbp_fit.qdp<<EOF 
/null
log
plot
cpd pgplot.gif/gif
plot
quit
EOF
eog pgplot.gif&
sleep 3
kill $! >/dev/null

mv dbeta_param.txt sbp_param.txt
