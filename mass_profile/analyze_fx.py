#!/usr/bin/env python

import sys
import math
import numpy

fx1_array=[]
fx2_array=[]
fx3_array=[]
for i in open('summary_fx.dat'):
    x1,x2,x3=i.split()
    x1=float(x1)
    x2=float(x2)
    x3=float(x3)
    fx1_array.append(x1)
    fx2_array.append(x2)
    fx3_array.append(x3)


fx1_array=numpy.array(fx1_array)
fx2_array=numpy.array(fx2_array)
fx3_array=numpy.array(fx3_array)


f=open('fx_result.txt','w')
f.write("Fx(bolot)= %4.2E +/- %4.2E erg/s/cm^2\n"%(fx1_array[0],fx1_array.std()))
print("Fx(bolot)= %4.2E +/- %4.2E erg/s/cm^2"%(fx1_array[0],fx1_array.std()))
f.write("Fx(0.7-7)= %4.2E +/- %4.2E erg/s/cm^2\n"%(fx2_array[0],fx2_array.std()))
print("Fx(0.7-7)= %4.2E +/- %4.2E erg/s/cm^2"%(fx2_array[0],fx2_array.std()))
f.write("Fx(0.1-2.4)= %4.2E +/- %4.2E erg/s/cm^2\n"%(fx3_array[0],fx3_array.std()))
print("Fx(0.1-2.4)= %4.2E +/- %4.2E erg/s/cm^2"%(fx3_array[0],fx3_array.std()))

