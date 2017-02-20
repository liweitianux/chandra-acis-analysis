# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Manipulate the FITS header keywords using CIAO tools
``dmkeypar`` and ``dmhedit``.
"""

import subprocess


def read_keyword(infile, keyword):
    """
    Read the specified header keyword, and return a dictionary
    with its value, unit, data type, and comment.
    """
    DATATYPES = {
        "real": float,
        "integer": int,
        "boolean": bool,
        "string": str
    }
    subprocess.check_call(["punlearn", "dmkeypar"])
    subprocess.check_call([
        "dmkeypar", "infile=%s" % infile, "keyword=%s" % keyword
    ])
    datatype = subprocess.check_output([
        "pget", "dmkeypar", "datatype"
    ]).decode("utf-8").strip()
    value = subprocess.check_output([
        "pget", "dmkeypar", "value"
    ]).decode("utf-8").strip()
    value = DATATYPES[datatype](value)
    unit = subprocess.check_output([
        "pget", "dmkeypar", "unit"
    ]).decode("utf-8").strip()
    comment = subprocess.check_output([
        "pget", "dmkeypar", "comment"
    ]).decode("utf-8").strip()
    return {"value": value, "datatype": datatype,
            "unit": unit, "comment": comment}


def write_keyword(infile, keyword, value, datatype=None,
                  unit=None, comment=None):
    """
    Write the specified keyword to the file header.
    """
    DATATYPES = {
        "real": "double",
        "integer": "long",
        "boolean": "boolean",
        "string": "string"
    }
    subprocess.check_call(["punlearn", "dmhedit"])
    cmd = [
        "dmhedit", "infile=%s" % infile, "filelist=none",
        "operation=add", "key=%s" % keyword, "value=%s" % value
    ]
    if datatype:
        cmd += ["datatype=%s" % DATATYPES[datatype]]
    if unit:
        cmd += ["unit=%s" % unit]
    if comment:
        cmd += ["comment=%s" % comment]
    subprocess.check_call(cmd)


def copy_keyword(infile1, infile2, keyword):
    """
    Copy the specified keyword(s) from infile1 to infile2.
    """
    if not isinstance(keyword, list):
        keyword = [keyword]
    for kw in keyword:
        data = read_keyword(infile1, kw)
        write_keyword(infile2, kw, **data)
