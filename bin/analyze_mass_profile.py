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

center_m,center_r,center_gm,center_gf,mlist,rlist,gmlist,gflist=read_file(sys.argv[1:])
delta=float(sys.argv[1])

if len(sys.argv)>2 and sys.argv[2]=='c':
    print("%s(<r%d)=%E solar mass"%("mass",delta,center_m))
    print("%s%d=%E kpc"%("r",delta,center_r))
    print("%s(<r%d)=%E solar mass"%("gas mass",delta,center_gm))
    print("%s(<r%d)=%E"%("gas fraction",delta,center_gf))
    sys.exit(0)


mlist.sort()
rlist.sort()
gflist.sort()
gmlist.sort()

m_idx=-1
r_idx=-1
gm_idx=-1
gf_idx=-1
delta=float(sys.argv[1])
for i in range(len(mlist)-1):
    if (center_m-mlist[i])*(center_m-mlist[i+1])<=0:
        m_idx=i
        break

for i in range(len(rlist)-1):
    if (center_r-rlist[i])*(center_r-rlist[i+1])<=0:
        r_idx=i
        break

for i in range(len(gmlist)-1):
    if (center_gm-gmlist[i])*(center_gm-gmlist[i+1])<=0:
        gm_idx=i
        break

for i in range(len(gflist)-1):
    if (center_gf-gflist[i])*(center_gf-gflist[i+1])<=0:
        gf_idx=i
        break


if m_idx==-1 or r_idx==-1 or gf_idx==-1 or gm_idx==-1:
    print("Error, the center value is not enclosed by the Monte-Carlo realizations, please check the result!")
    print("m:%E %E %E"%(center_m,mlist[0],mlist[-1]))
    print("gm:%E %E %E"%(center_gm,gmlist[0],gmlist[-1]))
    print("gf:%E %E %E"%(center_gf,gflist[0],gflist[-1]))
    print("r:%E %E %E"%(center_r,rlist[0],rlist[-1]))
    sys.exit(1)


mlidx=int(m_idx*(1-confidence_level))
muidx=m_idx-1+int((len(mlist)-m_idx)*confidence_level)


rlidx=int(r_idx*(1-confidence_level))
ruidx=r_idx-1+int((len(rlist)-r_idx)*confidence_level)

gmlidx=int(gm_idx*(1-confidence_level))
gmuidx=gm_idx-1+int((len(gmlist)-gm_idx)*confidence_level)

gflidx=int(gf_idx*(1-confidence_level))
gfuidx=gf_idx-1+int((len(gflist)-gf_idx)*confidence_level)


merr1=mlist[mlidx]-center_m
merr2=mlist[muidx]-center_m

rerr1=rlist[rlidx]-center_r
rerr2=rlist[ruidx]-center_r

gmerr1=gmlist[gmlidx]-center_gm
gmerr2=gmlist[gmuidx]-center_gm

gferr1=gflist[gflidx]-center_gf
gferr2=gflist[gfuidx]-center_gf

#print("%d %d %d"%(mlidx,m_idx,muidx))
#print("%d %d %d"%(rlidx,r_idx,ruidx))

print("m%d=\t%e\t %e/+%e solar mass (1 sigma)"%(delta,center_m,merr1,merr2))
print("gas_m%d=\t%e\t %e/+%e solar mass (1 sigma)"%(delta,center_gm,gmerr1,gmerr2))
print("gas_fraction%d=\t%e\t %e/+%e (1 sigma)"%(delta,center_gf,gferr1,gferr2))
print("r%d=\t%d\t %d/+%d kpc (1 sigma)"%(delta,center_r,rerr1,rerr2))
