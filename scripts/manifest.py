#!/usr/bin/env python3
#
# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license
#
# Weitian LI
# 2017-02-11

"""
Manage the observation manifest in YAML format.

NOTE
----
Use `ruamel.yaml`_ instead of `PyYAML`_ to preserve the comments
and other structures in the YAML file.

.. _`ruamel.yaml`: https://bitbucket.org/ruamel/yaml
.. _`PyYAML`: http://pyyaml.org/
"""

from context import acispy
from acispy import manifest


if __name__ == "__main__":
    manifest.main()
