#!/usr/bin/python

import sys
import scipy

output_file=open(sys.argv[2],'w')
for i in open(sys.argv[1]):
    c,s=i.strip().split()
    c=float(c)
    s=float(s)

    if c>0 and s>0:
        c1=-1
        while c1<=0:
            c1=scipy.random.normal(0,1)*s+c

        output_file.write("%s\t%s\n"%(c1,s))

