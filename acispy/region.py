# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Region utilities.

NOTE:
Only support the commonly used region shapes in CIAO format.
While more complex shapes and DS9 format are not considered
at the moment.
"""

import os
import re


class Point:
    """
    Point region: point(xc,yc)
    """
    shape = "point"

    def __init__(self, xc=None, yc=None):
        if isinstance(xc, str):
            self.parse(regstr=xc)
        else:
            self.xc = xc
            self.yc = yc

    def parse(self, regstr):
        g = re.split(r"[(),]", regstr)
        self.xc = float(g[1])
        self.yc = float(g[2])

    def __str__(self):
        return "%s(%.4f,%.4f)" % (self.shape, self.xc, self.yc)


class Circle:
    """
    Circle region: circle(xc,yc,radius)
    """
    shape = "circle"

    def __init__(self, xc=None, yc=None, radius=None):
        if isinstance(xc, str):
            self.parse(regstr=xc)
        else:
            self.xc = xc
            self.yc = yc
            self.radius = radius

    def parse(self, regstr):
        g = re.split(r"[(),]", regstr)
        self.xc = float(g[1])
        self.yc = float(g[2])
        self.radius = float(g[3])

    def __str__(self):
        return "%s(%.4f,%.4f,%.4f)" % (self.shape, self.xc, self.yc,
                                       self.radius)


class Annulus:
    """
    Annulus region:
        annulus(xc,yc,radius,radius2)
        + xc, yc : center
        + radius, radius2 : inner, outer radius
    """
    shape = "annulus"

    def __init__(self, xc=None, yc=None, radius=None, radius2=None):
        if isinstance(xc, str):
            self.parse(regstr=xc)
        else:
            self.xc = xc
            self.yc = yc
            self.radius = radius
            self.radius2 = radius2

    def parse(self, regstr):
        g = re.split(r"[(),]", regstr)
        self.xc = float(g[1])
        self.yc = float(g[2])
        self.radius = float(g[3])
        self.radius2 = float(g[4])

    def __str__(self):
        return "%s(%.4f,%.4f,%.4f,%.4f)" % (self.shape, self.xc, self.yc,
                                            self.radius, self.radius2)


class Pie:
    """
    Pie region:
        pie(xc,yc,radius,radius2,angle1,angle2)
        + xc, yc : center
        + radius, radius2 : inner, outer radius
        + angle1, angle2: start, end angle [0, 360)
    """
    shape = "pie"

    def __init__(self, xc=None, yc=None, radius=None, radius2=None,
                 angle1=0.0, angle2=360.0):
        if isinstance(xc, str):
            self.parse(regstr=xc)
        else:
            self.xc = xc
            self.yc = yc
            self.radius = radius
            self.radius2 = radius2
            self.angle1 = angle1
            self.angle2 = angle2

    def parse(self, regstr):
        g = re.split(r"[(),]", regstr)
        self.xc = float(g[1])
        self.yc = float(g[2])
        self.radius = float(g[3])
        self.radius2 = float(g[4])
        self.angle1 = float(g[5])
        self.angle2 = float(g[6])

    def __str__(self):
        return "%s(%.4f,%.4f,%.4f,%.4f,%.4f,%.4f)" % (
            self.shape, self.xc, self.yc, self.radius, self.radius2,
            self.angle1, self.angle2)


class Ellipse:
    """
    Ellipse region:
        ellipse(xc,yc,radius,radius2,rotation)
        + xc, yc : center
        + radius, radius2 : semi-major / semi-minor axis
        + rotation: rotation angle [0, 360)
    """
    shape = "ellipse"

    def __init__(self, xc=None, yc=None, radius=None, radius2=None,
                 rotation=0.0):
        if isinstance(xc, str):
            self.parse(regstr=xc)
        else:
            self.xc = xc
            self.yc = yc
            self.radius = radius
            self.radius2 = radius2
            self.rotation = rotation

    def parse(self, regstr):
        g = re.split(r"[(),]", regstr)
        self.xc = float(g[1])
        self.yc = float(g[2])
        self.radius = float(g[3])
        self.radius2 = float(g[4])
        self.rotation = float(g[5])

    def __str__(self):
        return "%s(%.4f,%.4f,%.4f,%.4f,%.4f)" % (
            self.shape, self.xc, self.yc, self.radius,
            self.radius2, self.rotation)


class Box:
    """
    Box region: box(xc,yc,width,height,rotation)
    """
    shape = "box"

    def __init__(self, xc=None, yc=None, width=None, height=None,
                 rotation=0.0):
        if isinstance(xc, str):
            self.parse(regstr=xc)
        else:
            self.xc = xc
            self.yc = yc
            self.width = width
            self.height = height
            self.rotation = rotation

    def parse(self, regstr):
        g = re.split(r"[(),]", regstr)
        self.xc = float(g[1])
        self.yc = float(g[2])
        self.width = float(g[3])
        self.height = float(g[4])
        self.rotation = float(g[5])

    def __str__(self):
        return "%s(%.4f,%.4f,%.4f,%.4f,%.4f)" % (
            self.shape, self.xc, self.yc, self.width,
            self.height, self.rotation)


class Regions:
    """
    Manipulate the region files (CIAO format), as well as parse regions
    from strings.
    """
    REGION_SHAPES = {
        "point": Point,
        "circle": Circle,
        "annulus": Annulus,
        "pie": Pie,
        "ellipse": Ellipse,
        "box": Box,
    }

    def __init__(self, regfile=None):
        if regfile:
            self.load(regfile)
        else:
            self.regions = []

    def load(self, infile):
        regstr = []
        for line in open(infile):
            if not (re.match(r"^\s*#.*$", line) or re.match(r"^\s*$", line)):
                regstr.append(line.strip())
        self.regions = self.parse(regstr)

    def save(self, outfile, clobber=False):
        if (not clobber) and os.path.exists(outfile):
            raise OSError("output file already exists: %s" % outfile)
        regstr = [str(reg) for reg in self.regions]
        open(outfile, "w").write("\n".join(regstr) + "\n")

    @classmethod
    def parse(self, regstr):
        """
        Parse the given (list of) region string(s), and return the
        corresponding parsed region objects.
        """
        if isinstance(regstr, list):
            return [self.parse_single(reg) for reg in regstr]
        else:
            return self.parse_single(regstr)

    @classmethod
    def parse_single(self, regstr):
        """
        Parse the given single region string to its corresponding
        region object.
        """
        shape = regstr.strip().split('(')[0].lower()
        if shape in self.REGION_SHAPES:
            return self.REGION_SHAPES[shape](regstr)
        else:
            raise ValueError("unknown region shape: %s" % shape)
