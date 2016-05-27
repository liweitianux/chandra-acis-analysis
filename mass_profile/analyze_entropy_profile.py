#!/usr/bin/env python

import sys
import numpy
import scipy.interpolate

center_entropy_file=open('entropy_center.qdp')
entropy_file=open('summary_entropy.qdp')
confidence_level=.68
rout=float(sys.argv[1])

center_s=0
for i in center_entropy_file:
    r,s=i.split()
    r=float(r)
    s=float(s)
    if r>rout:
        center_s=s
        break

new_data=True


s_list=[]
for i in entropy_file:
    if i[0]=='n':
        new_data=True
        continue
    if new_data==False:
        continue
    r,s=i.split()
    r=float(r)
    s=float(s)
    if r>rout:
        new_data=False
        s_list.append(s)

s_idx=-1

s_list.sort()
for i in range(len(s_list)-1):
    if (center_s-s_list[i])*(center_s-s_list[i+1])<=0:
        m_idx=i
        break


slidx=int(s_idx*(1-confidence_level))
suidx=s_idx-1+int((len(s_list)-s_idx)*confidence_level)


serr1=s_list[slidx]-center_s
serr2=s_list[suidx]-center_s

print("S=\t%e\t %e/+%e keV cm^2 (1 sigma)"%(center_s,serr1,serr2))
