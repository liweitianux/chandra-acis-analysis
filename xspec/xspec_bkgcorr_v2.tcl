#####################################################################
## XSPEC Tcl script
##
## Task:
## analysis chandra acis background components
## output model fitting results, then generate
## fake spectra to correct the blanksky background
##
## LIweitiaNux <liweitianux@gmail.com>
## August 1, 2012
##
## NOTES: needs XSPEC v12.x
##
## ChangeLogs:
## v2, 2012/08/14, LIweitiaNux
##   skip calc `error' of params
##   change variable names
##   improve the final comparison graph
##   replace `trim' with `regexp'
#####################################################################

## about {{{
set NAME "xspec_bkgcorr_v2.tcl"
set VERSION "v2, 2012-08-14"
## about }}}

## set basic variables {{{
## tclout: create tcl var from current state
set tcl_date [ exec date ]
tclout filename 1
set spec_name [ exec basename $xspec_tclout ]
# `trim' is not reliable: `lbkg_grp.pi' --> `lbkg_gr'
# set spec_rootname "[ string trimright $spec_name {.pi} ]"
regexp -- {(.+)\.(pi)} $spec_name match spec_rootname fext
# get `rootname' from `spec_name'
regexp -- {(.+)_(bin|grp)([0-9]*)\.(pi|fits)} $spec_name match rootname grptype grpval fext
puts "## rootname: $rootname"
puts "## grptype: $grptype"
puts "## grpval: $grpval"
puts "## file extension: $fext"
# backgrnd name
tclout backgrnd 1
set back_name $xspec_tclout
# set back_rootname "[ string trimright $back_name {.pi} ]"
regexp -- {(.+)\.(pi)} $back_name match back_rootname fext
# regexp -- {(.+)\.(pi)} $spec_name match spec_rootname fext
# `specscal': scale factor to create fake spectrum,
# use a large factor (i.e. 10) to get a good statistic for final spectrum
set specscal 10.0
## basic variables }}}

## save current xspec fitting results {{{
set xspec_outroot "xspec_${rootname}_fit"
# `save all', to save a xcm script
if {[ file exists ${xspec_outroot}.xcm ]} {
    exec mv -fv ${xspec_outroot}.xcm ${xspec_outroot}.xcm_bak
}
save all "${xspec_outroot}.xcm"
# writefits: (tcl scripts, v12.x)
#if {[ file exists ${xspec_outroot}.fits ]} {
#    exec mv -fv ${xspec_outroot}.fits ${xspec_outroot}.fits_bak
#}
#writefits "${xspec_outroot}.fits"
## save & writefits }}}

## set output file {{{
set out_fn "bkgcorr_${rootname}.log"
if {[ file exists ${out_fn} ]} {
    exec mv -fv ${out_fn} ${out_fn}_bak
}
set out_fd [ open ${out_fn} w ]
## output file }}}

## header, output basic process info {{{
puts $out_fd "# process by script: ${NAME}"
puts $out_fd "# version: ${VERSION}"
puts $out_fd "#"
puts $out_fd "# process date: $tcl_date"
puts $out_fd "#"
puts $out_fd ""
## header }}}

## save basic info about current fitting {{{
# files in use
puts $out_fd "data $spec_name"
tclout response 1
set rmf $xspec_tclout
puts $out_fd "response $rmf"
tclout arf 1
set arf $xspec_tclout
puts $out_fd "arf $arf"
puts $out_fd "backgrnd $back_name"
puts $out_fd ""
# exposure time, backscale
tclout expos 1 s
scan $xspec_tclout "%f" expos_src
tclout expos 1 b
scan $xspec_tclout "%f" expos_bkg
puts $out_fd "# src/bkg exptime: $expos_src/$expos_bkg"
tclout backscal 1 s
scan $xspec_tclout "%f" backscal_src
tclout backscal 1 b
scan $xspec_tclout "%f" backscal_bkg
puts $out_fd "# src/bkg backscal: $backscal_src/$backscal_bkg"
puts $out_fd ""
# model, and basic fitting results
tclout model
puts $out_fd "model $xspec_tclout"
tclout weight
puts $out_fd "# weight: $xspec_tclout"
tclout stat
scan $xspec_tclout "%f" chisq
tclout dof
scan $xspec_tclout "%d" dof
set rechisq_cmd { format "%.5f" [ expr { $chisq / $dof } ] }
set rechisq [ eval $rechisq_cmd ]
puts $out_fd "# chisq/dof = $chisq/$dof = $rechisq"
tclout noticed 1
puts $out_fd "# noticed channel: $xspec_tclout"
tclout noticed energy 1
puts $out_fd "# noticed energy (keV): $xspec_tclout"
puts $out_fd ""
## basic fitting info }}}

## model fitting results {{{
puts $out_fd "# fitting results of each components"
puts $out_fd "# errors are emitted for simplicity"
puts $out_fd "#"
puts $out_fd "# name   value   sigma_err"
puts $out_fd ""
# apec_1, Galactic X-ray background, soft-soft
tclout param 1
scan $xspec_tclout "%f" temp_a1
puts $out_fd "temp_a1: $temp_a1"
tclout param 2
scan $xspec_tclout "%f" abund_a1
puts $out_fd "abund_a1: $abund_a1"
tclout param 3
scan $xspec_tclout "%f" redshift_a1
puts $out_fd "redshift_a1: $redshift_a1"
tclout param 4
scan $xspec_tclout "%f" norm_a1
tclout sigma 4
set norm_sigma_a1 $xspec_tclout
puts $out_fd "norm_a1: $norm_a1  $norm_sigma_a1"
puts $out_fd ""
# apec_2, Galactic X-ray Background, soft
tclout param 5
scan $xspec_tclout "%f" temp_a2
puts $out_fd "temp_a2: $temp_a2"
tclout param 6
scan $xspec_tclout "%f" abund_a2
puts $out_fd "abund_a2: $abund_a2"
tclout param 7
scan $xspec_tclout "%f" redshift_a2
puts $out_fd "redshift_a2: $redshift_a2"
tclout param 8
scan $xspec_tclout "%f" norm_a2
tclout sigma 8
set norm_sigma_a2 $xspec_tclout
puts $out_fd "norm_a2: $norm_a2  $norm_sigma_a2"
puts $out_fd ""
# wabs
tclout param 9
scan $xspec_tclout "%f" wabs
puts $out_fd "wabs: $wabs"
puts $out_fd ""
# powerlaw, Cosmological X-ray Background, hard
tclout param 10
scan $xspec_tclout "%f" gamma_po
puts $out_fd "gamma_po: $gamma_po"
tclout param 11
scan $xspec_tclout "%f" norm_po
tclout sigma 11
set norm_sigma_po $xspec_tclout
puts $out_fd "norm_po: $norm_po  $norm_sigma_po"
puts $out_fd ""
# apec_3, gas emission from object source
tclout param 12
scan $xspec_tclout "%f" temp_gas
tclout sigma 12
set temp_sigma_gas $xspec_tclout
puts $out_fd "temp_gas: $temp_gas $temp_sigma_gas"
tclout param 13
scan $xspec_tclout "%f" abund_gas
tclout sigma 13
set abund_sigma_gas $xspec_tclout
puts $out_fd "abund_gas: $abund_gas $abund_sigma_gas"
tclout param 14
scan $xspec_tclout "%f" redshift_gas
puts $out_fd "redshift_gas: $redshift_gas"
tclout param 15
scan $xspec_tclout "%f" norm_gas
tclout sigma 15
set norm_sigma_gas $xspec_tclout
puts $out_fd "norm_gas: $norm_gas  $norm_sigma_gas"
puts $out_fd ""
## fittins results }}}
# end output results
close $out_fd

## prepare data for fake spectrum {{{
# see `specscal' in top `basic variables' section
# apec_1
if {$norm_a1 < 0} {
    set pm_a1 "-"
} else {
    set pm_a1 "+"
}
set pars_a1 "$temp_a1 & $abund_a1 & $redshift_a1 & [ expr abs($norm_a1)*$specscal ]"
set model_a1 "apec"
# apec_2
if {$norm_a2 < 0} {
    set pm_a2 "-"
} else {
    set pm_a2 "+"
}
set pars_a2 "$temp_a2 & $abund_a2 & $redshift_a2 & [ expr abs($norm_a2)*$specscal ]"
set model_a2 "apec"
# powerlaw
if {$norm_po < 0} {
    set pm_po "-"
} else {
    set pm_po "+"
}
set pars_po "$wabs & $gamma_po & [ expr abs($norm_po)*$specscal ]"
set model_po "wabs*powerlaw"
# gas emssion
# norm of `gas component' cannot be negative
set pars_gas "$wabs & $temp_gas & $abund_gas & $redshift_gas & [ expr abs($norm_gas)*$specscal ]"
set model_gas "wabs*apec"
## prepare data }}}

## functions to load model, fake spectrum {{{
proc tcl_model {model_str pars args} {
    model none
    model $model_str & $pars & /*
}
proc tcl_fakeit {rmf arf fakedata exptime args} {
    data none
    fakeit none & $rmf & $arf & y & & $fakedata & $exptime & /*
}
## functions }}}

## set fake spectrum and check previous files {{{
set fake_a1 "fake_${rootname}_a1.pi"
set fake_a2 "fake_${rootname}_a2.pi"
set fake_po "fake_${rootname}_po.pi"
set fake_gas "fake_${rootname}_gas.pi"
if {[ file exists $fake_a1 ]} {
    exec mv -fv $fake_a1 ${fake_a1}_bak
}
if {[ file exists $fake_a2 ]} {
    exec mv -fv $fake_a2 ${fake_a2}_bak
}
if {[ file exists $fake_po ]} {
    exec mv -fv $fake_po ${fake_po}_bak
}
if {[ file exists $fake_gas ]} {
    exec mv -fv $fake_gas ${fake_gas}_bak
}
## fake spectrum }}}

## generate fake spectrum {{{
# blanksky, apec_1
tcl_model $model_a1 $pars_a1
tcl_fakeit $rmf $arf $fake_a1 $expos_bkg
# blanksky, apec_2
tcl_model $model_a2 $pars_a2
tcl_fakeit $rmf $arf $fake_a2 $expos_bkg
# blanksky, wabs*powerlaw
tcl_model $model_po $pars_po
tcl_fakeit $rmf $arf $fake_po $expos_bkg
# src gas, wabs*apec
tcl_model $model_gas $pars_gas
tcl_fakeit $rmf $arf $fake_gas $expos_src
## fake spectrum }}}

## background correction {{{
## blanksky {{{
set bbkg_expr "${specscal}*${back_name} ${pm_a1}${fake_a1} ${pm_a2}${fake_a2} ${pm_po}${fake_po}"
set bbkg_outf "bkgcorr_blanksky_${rootname}.pi"
set bbkg_back [ expr { $backscal_bkg * $specscal } ]
set bbkg_cmm1 "corrected background spectrum, blanksky based"
set bbkg_cmm2 "norm*${specscal}, backscal*${specscal}, properr=no"
set bbkg_mathpha "mathpha expr=\"${bbkg_expr}\" units=C outfil=${bbkg_outf} exposure=${expos_bkg} areascal=% ncomments=2 comment1=\"${bbkg_cmm1}\" comment2=\"${bbkg_cmm2}\" properr=no backscal=${bbkg_back}"
## blanksky }}}

## localbkg {{{
set lbkg_expr "${specscal}*${spec_name} -${fake_gas}"
set lbkg_outf "bkgcorr_localbkg_${rootname}.pi"
set lbkg_back [ expr { $backscal_src * $specscal } ]
set lbkg_cmm1 "corrected background spectrum, local background based"
set lbkg_cmm2 "norm*${specscal}, backscal*${specscal}, properr=no"
set lbkg_mathpha "mathpha expr=\"${lbkg_expr}\" units=C outfil=${lbkg_outf} exposure=${expos_src} areascal=% ncomments=2 comment1=\"${lbkg_cmm1}\" comment2=\"${lbkg_cmm2}\" properr=no backscal=${lbkg_back}"
## local }}}

## XXX: cannot figure out how to `eval' these cmd in Tcl. !!!
## generate a shell script to exec mathpha {{{
if {[ file exists ${bbkg_outf} ]} {
    exec mv -fv ${bbkg_outf} ${bbkg_outf}_bak
}
if {[ file exists ${lbkg_outf} ]} {
    exec mv -fv ${lbkg_outf} ${lbkg_outf}_bak
}
set mathpha_fn "_mathpha.sh"
if {[ file exists ${mathpha_fn} ]} {
    exec rm -fv ${mathpha_fn}
}
set mathpha_fd [ open ${mathpha_fn} w ]
puts $mathpha_fd $bbkg_mathpha
puts $mathpha_fd $lbkg_mathpha
close $mathpha_fd
# exec
exec sh ${mathpha_fn}
#exec rm -rf ${mathpha_sh}
## mathpha }}}
## background correction }}}

## load the corrected spectra, save a picture {{{
set bkgcorr_img "bkgcorr_${rootname}.ps"
if {[ file exists ${bkgcorr_img} ]} {
    exec mv -fv ${bkgcorr_img} ${bkgcorr_img}_bak
}

model none
data none

# corrected spectrum (blanksky based)
data 1:1 ${bbkg_outf}
resp 1:1 ${rmf}
arf 1:1 ${arf}
# corrected spectrum (local bkg based)
data 2:2 ${lbkg_outf}
resp 1:2 ${rmf}
arf 1:2 ${arf}
# original blanksky spectrum
data 3:3 ${back_name}
resp 1:3 ${rmf}
arf 1:3 ${arf}
# original local spectrum
data 4:4 ${spec_name}
resp 1:4 ${rmf}
arf 1:4 ${arf}

ignore bad
ignore **:0.0-0.3,11.0-**

setplot energy

# rebin for plot
setplot rebin 20 20 1
setplot rebin 20 20 2
setplot rebin 20 20 3
setplot rebin 10 20 4

# label
setplot command LABEL T "Corrected & Original Background Spectrum Comparison"
setplot command LABEL F "corr_blank(BLACK), corr_local(RED), orig_blank(GREEN), orig_local(BLUE)"

setplot device ${bkgcorr_img}/cps
plot ldata
setplot device /xw
plot
## bkgcorr picture }}}

## end analysis
# tclexit

# vim: set ts=8 sw=4 tw=0 fenc=utf-8 ft=tcl: #
