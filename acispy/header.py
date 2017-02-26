# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Manipulate the FITS header keywords using CIAO tools
``dmkeypar`` and ``dmhedit``, as well as ``astropy.io.fits``.
"""

import subprocess

from astropy.io import fits


def read_keyword(infile, keyword):
    """
    Read the specified header keyword using CIAO tool ``dmkeypar``,
    and return a dictionary with its value, unit, data type, and comment.

    NOTE
    ----
    The ``dmkeypar`` tool cannot read some raw/reserved keywords in FITS
    header, e.g., ``BUNIT``.  These raw header keywords can be obtained
    using ``dmlist <infile> opt=header,raw``, or using the following
    ``read_keyword2()``.
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


def read_keyword2(infile, keyword):
    """
    Read the specified header keyword using ``astropy.io.fits``
    and return a tuple of ``(value, comment)``.

    NOTE
    ----
    Header of all extensions (a.k.a. blocks) are combined to locate
    the keyword.
    """
    with fits.open(infile) as f:
        h = fits.header.Header()
        for hdu in f:
            h.extend(hdu.header)
        value = h[keyword]
        comment = h.comments[keyword]
    return (value, comment)


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
