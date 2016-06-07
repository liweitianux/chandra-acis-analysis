#!/usr/bin/env python

import sys
import math
import numpy

lx1_array=[]
lx2_array=[]
lx3_array=[]
for i in open('summary_lx.dat'):
    x1,x2,x3=i.split()
    x1=float(x1)
    x2=float(x2)
    x3=float(x3)
    lx1_array.append(x1)
    lx2_array.append(x2)
    lx3_array.append(x3)


lx1_array=numpy.array(lx1_array)
lx2_array=numpy.array(lx2_array)
lx3_array=numpy.array(lx3_array)


f=open('lx_result.txt','w')
f.write("Lx(bolo)= %4.2E +/- %4.2E erg/s\n"%(lx1_array[0],lx1_array.std()))
print("Lx(bolo)= %4.2E +/- %4.2E erg/s"%(lx1_array[0],lx1_array.std()))
f.write("Lx(0.7-7)= %4.2E +/- %4.2E erg/s\n"%(lx2_array[0],lx2_array.std()))
print("Lx(0.7-7)= %4.2E +/- %4.2E erg/s"%(lx2_array[0],lx2_array.std()))
f.write("Lx(0.1-2.4)= %4.2E +/- %4.2E erg/s\n"%(lx3_array[0],lx3_array.std()))
print("Lx(0.1-2.4)= %4.2E +/- %4.2E erg/s"%(lx3_array[0],lx3_array.std()))

