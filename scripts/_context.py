# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license

"""
Portal to 'acispy' module/package
"""

import os
import sys

sys.path.insert(
    0,
    os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
)

import acispy
