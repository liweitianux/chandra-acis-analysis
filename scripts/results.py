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

import manifest


def main(description="Manage the analysis results (YAML format)",
         default_file="results.yaml"):
    manifest.main(description=description, default_file=default_file)


if __name__ == "__main__":
    main()
