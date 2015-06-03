#!/usr/bin/python

import sys
import math
import re
ccd_size=1024

def find_intersection(v1,v2):
    x1=v1[0][0]
    y1=v1[0][1]
    x2=v1[1][0]
    y2=v1[1][1]
    x3=v2[0][0]
    y3=v2[0][1]
    x4=v2[1][0]
    y4=v2[1][1]

    k=((x3-x1)*(y3-y4)-(y3-y1)*(x3-x4))/((x2-x1)*(y3-y4)-(y2-y1)*(x3-x4))
    return (x1+k*(x2-x1),y1+k*(y2-y1))

def parse_poly(s):
    p=s.split('(')[1].split(')')[0]
    p=p.split(',')
    vertex=[]
    for i in range(0,int(len(p)/2)):
        x,y=float(p[i*2]),float(p[i*2+1])
        vertex.append((x,y))

    vlist=[]
    for i in range(0,len(vertex)):
        n=i%(len(vertex))
        n1=(i+1)%(len(vertex))
        v=(vertex[n1][0]-vertex[n][0],
           vertex[n1][1]-vertex[n][1])
        l=(math.sqrt(v[0]**2+v[1]**2))
        if l>ccd_size*.66:
            vlist.append((vertex[n],vertex[n1]))
    result=[]
    for i in range(0,len(vlist)):
        n=i%len(vlist)
        n1=(i+1)%len(vlist)
        v1=vlist[n]
        v2=vlist[n1]
        point=find_intersection(v1,v2)
        result.append(point)
    return result

def form_poly(plist):
    result="Polygon("
    for i in range(0,len(plist)-1):
        result+="%f,%f,"%(plist[i][0],plist[i][1])
    result+="%f,%f)"%(plist[-1][0],plist[-1][1])
    return result

def poly2rect(plist):
    c=[0,0]
    if len(plist)!=4:
        raise Exception("Error, the length of poly point list should be 4!")
    for i in range(0,4):
        c[0]+=plist[i][0]/4.
        c[1]+=plist[i][1]/4.
    w=0
    for i in range(0,4):
        n=i%4
        n1=(i+1)%4
        l=math.sqrt((plist[n][0]-plist[n1][0])**2+(plist[n][1]-plist[n1][1])**2)
        w+=l/4
    a=math.degrees(math.atan2(plist[1][1]-plist[0][1],plist[1][0]-plist[0][0]))
    return "rotbox(%f,%f,%f,%f,%f)"%(c[0],c[1],w,w,a)

if __name__=='__main__':
    if len(sys.argv)!=2:
        print("Usage:")
        print("    %s <input regfile (only polygens)>" % sys.argv[0])
        sys.exit()
    for i in open(sys.argv[1]):
        if re.match('.*olygon',i):
            reg=poly2rect(parse_poly(i))
            print(reg)

