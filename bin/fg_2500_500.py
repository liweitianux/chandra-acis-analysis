#!/usr/bin/env python

import sys
import numpy
import scipy.interpolate

confidence_level=.68
def read_file(param):
    delta=float(param[0])

    file_mass_center=open("mass_int_center.qdp").readlines();
    file_delta_center=open("overdensity_center.qdp").readlines();
    
    center_r=0
    center_m=0
    center_gm=0
    center_gf=0

    
    for i in range(0,len(file_mass_center)):
        lm=file_mass_center[i].strip();
        ld=file_delta_center[i].strip();
        r,m=lm.split()
        r,d=ld.split()
        r=float(r)
        d=float(d)
        m=float(m)
        if m<1e11:
            continue
        if d<delta:
            center_r=r
            center_m=m
            for j in open("gas_mass_int_center.qdp"):
                rgm,gm=j.strip().split()
                rgm=float(rgm)
                gm=float(gm)
                if rgm>r:

                    center_gm=gm
                    center_gf=gm/m
                    break
            break
    if len(param)>1 and param[1]=='c':
        #print("%s(<r%d)=%E solar mass"%("mass",delta,center_m))
        #print("%s%d=%E kpc"%("r",delta,center_r))
        #print("%s(<r%d)=%E solar mass"%("gas mass",delta,center_gm))
        #print("%s(<r%d)=%E"%("gas fraction",delta,center_gf))
        return center_m,center_r,center_gm,center_gf,None,None,None,None
    

#print(center_gm,center_gf)
    file_mass=open('summary_mass_profile.qdp').readlines()
    file_delta=open('summary_overdensity.qdp').readlines()
    file_gm=open('summary_gas_mass_profile.qdp')


    flag=True
    rlist=[]
    mlist=[]
    gmlist=[]
    gflist=[]
    old_m=0
    invalid_count=0
    for i in range(0,len(file_mass)):
        lm=file_mass[i].strip()
        ld=file_delta[i].strip()
        if lm[0]=='n':
            flag=True
            old_m=0
            continue
        if not flag:
            continue
        r,m=lm.split()
        m=float(m)
        if m<1e12:
            continue
        if m<old_m:
            invalid_count+=1
            flag=False
            continue
        r,d=ld.split()
        d=float(d)
        r=float(r)

        if d<delta:
            #print("%s %e"%(d,m))
            mlist.append(m)
            rlist.append(r)
            flag1=True
            while True:
                lgm=file_gm.readline().strip()
                if lgm[0]=='n':
                    break
                rgm,gm=lgm.split()
                rgm=float(rgm)
                gm=float(gm)
                if rgm>r and flag1:
                    gmlist.append(gm)

                    flag1=False
                    gflist.append(gm/mlist[-1])
                #print(gm,gflist[-1])
            flag=False
        old_m=m
    print("%d abnormal data dropped"%(invalid_count))


    return center_m,center_r,center_gm,center_gf,mlist,rlist,gmlist,gflist
#center_m=numpy.mean(mlist)
#center_r=numpy.mean(rlist)

if len(sys.argv)>1:
    center_m2500,center_r2500,center_gm2500,center_gf2500,mlist2500,rlist2500,gmlist2500,gflist2500=read_file([2500,sys.argv[1]])
    center_m500,center_r500,center_gm500,center_gf500,mlist500,rlist500,gmlist500,gflist500=read_file([500,sys.argv[1]])
else:
    center_m2500,center_r2500,center_gm2500,center_gf2500,mlist2500,rlist2500,gmlist2500,gflist2500=read_file([2500])
    center_m500,center_r500,center_gm500,center_gf500,mlist500,rlist500,gmlist500,gflist500=read_file([500])

if mlist2500!=None and len(mlist2500)!=len(mlist500):
    raise Exception("Something wrong, the number of 2500 and 500 data are different")


if mlist2500==None:
    print("gas fraction between r2500 and r500 is %E"%((center_gm500-center_gm2500)/(center_m500-center_m2500)))
    sys.exit(0)

gf_2500_500=[]

for i in range(0,len(mlist500)):
    if mlist500[i]-mlist2500[i]<=0:
        continue
    gf_2500_500.append((gmlist500[i]-gmlist2500[i])/(mlist500[i]-mlist2500[i]))

gf_2500_500.sort();


center_gf_2500_500=(center_gm500-center_gm2500)/(center_m500-center_m2500)
gf_idx=-1

for i in range(len(gf_2500_500)-1):
    if (center_gf_2500_500-gf_2500_500[i])*(center_gf_2500_500-gf_2500_500[i+1])<=0:
        gf_idx=i
        break
if gf_idx==-1:
    raise Exception("Something wrong!")
    
gflidx=int(gf_idx*(1-confidence_level))
gfuidx=gf_idx-1+int((len(gf_2500_500)-gf_idx)*confidence_level)

gferr1=gf_2500_500[gflidx]-center_gf_2500_500
gferr2=gf_2500_500[gfuidx]-center_gf_2500_500

print("gas_fraction between r2500 and r500=\t%e\t %e/+%e (1 sigma)"%(center_gf_2500_500,gferr1,gferr2))
