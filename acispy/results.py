# Copyright (c) 2017 Weitian LI <liweitianux@live.com>
# MIT license
#
# Weitian LI
# 2017-02-11

"""
Manage the analysis results in YAML format.
"""

from . import manifest


def get_results(filename="results.yaml"):
    """
    Find the results file and return the Manifest instance of it.

    Parameters
    ----------
    filename : str, optional
        Filename of the results file (default: ``results.yaml``)

    Returns
    -------
    results : `~Manifest`
        Manifest instance (i.e., results) of the found results file.
    """
    return manifest.get_manifest(filename)


def main(description="Manage the analysis results (YAML format)",
         default_file="results.yaml"):
    manifest.main(description=description, default_file=default_file)
