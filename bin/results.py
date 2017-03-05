#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license
#
# Weitian LI
# 2017-02-11

"""
Manage the analysis results in YAML format.
"""

import logging

from _context import acispy
from acispy import results


logging.basicConfig(level=logging.INFO)


if __name__ == "__main__":
    results.main()
