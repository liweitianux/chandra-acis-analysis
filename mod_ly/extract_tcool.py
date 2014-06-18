#!/usr/bin/env python

import sys
rcool=float(sys.argv[1])

for l in open('cooling_time.dat'):
    r,t=l.split()
    r=float(r)
    t=float(t)
    if r>rcool:
        print("cooling time at %f kpc=%f Gyr"%(rcool,t))
        print("rcool= %f kpc" % rcool)
        print("cooling_time= %f Gyr @ %f kpc" % (t,rcool))
        sys.exit(0)
