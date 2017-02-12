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

import os
import argparse
import ruamel.yaml


class Manifest:
    """
    Manage the observational products manifest.
    """
    def __init__(self, filepath):
        self.filepath = filepath
        self.manifest = ruamel.yaml.load(
            open(filepath), Loader=ruamel.yaml.RoundTripLoader)
        if self.manifest is None:
            self.manifest = ruamel.yaml.comments.CommentedMap()

    def dump(self):
        return ruamel.yaml.dump(self.manifest,
                                Dumper=ruamel.yaml.RoundTripDumper)

    def save(self):
        with open(self.filepath, "w") as f:
            f.write(self.dump())

    def show(self):
        print(self.dump())

    def get(self, key):
        """
        Get the value of the specified item in the manifest.

        If the specified item doesn't exist, raise a ``KeyError``.
        """
        if key in self.manifest:
            return self.manifest[key]
        else:
            raise KeyError("manifest doesn't have item: '%s'" % key)

    def set(self, key, value):
        """
        Set the value of the specified item in the manifest.
        (Will add a new item or update an existing item.)
        """
        self.manifest[key] = self.parse_value(value)
        self.save()

    def add(self, key, value):
        """
        Add the specified new item in the manifest.

        If the specified item already exists, raise a ``KeyError``.
        """
        if key in self.manifest:
            raise KeyError("manifest already has item: '%s'" % key)
        else:
            self.manifest[key] = self.parse_value(value)
            self.save()

    def update(self, key, value):
        """
        Update the specified existing item in the manifest.

        If the specified item doesn't exist, raise a ``KeyError``.
        """
        if key in self.manifest:
            self.manifest[key] = self.parse_value(value)
            self.save()
        else:
            raise KeyError("manifest doesn't have item: '%s'" % key)

    def delete(self, key):
        """
        Delete the specified item from the manifest.
        """
        del self.manifest[key]
        self.save()

    @staticmethod
    def parse_value(value):
        """
        Try to parse the value from string to integer or float.
        """
        try:
            v = int(value)
        except ValueError:
            try:
                v = float(value)
            except ValueError:
                v = value
        return v


def find_manifest(filename="manifest.yaml"):
    """
    Find the specified manifest file in current directory and
    the upper-level directories.

    Parameters
    ----------
    filename : str, optional
        Filename of the manifest file (default: ``manifest.yaml``)

    Returns
    -------
    filepath : str
        Absolute path to the manifest file if found.

    Raises
    ------
    FileNotFoundError :
        The specified manifest
    """
    dirname = os.getcwd()
    filepath = os.path.join(dirname, filename)
    while dirname != "/":
        if os.path.exists(filepath):
            return filepath
        # go upper by one level
        dirname = os.path.dirname(dirname)
        filepath = os.path.join(dirname, filename)
    # not found
    raise FileNotFoundError("cannot found manifest file: %s" % filename)


def cmd_show(args, manifest):
    """
    Default sub-command "show": Show manifest contents.
    """
    manifest.show()


def cmd_get(args, manifest):
    """
    Sub-command "get": Get the value of an item in the manifest.
    """
    if not args.brief:
        print("%s:" % args.key, end=" ")
    print(manifest.get(args.key))


def cmd_set(args, manifest):
    """
    Sub-command "set": Set the value of an item in the manifest.
    (Will add a new item or update an existing item.)
    """
    manifest.set(args.key, args.value)
    if not args.brief:
        print("Set item '%s': '%s'" % (args.key, args.value))


def cmd_add(args, manifest):
    """
    Sub-command "add": Add a new item to the manifest.
    """
    manifest.add(args.key, args.value)
    if not args.brief:
        print("Added item '%s': '%s'" % (args.key, args.value))


def cmd_update(args, manifest):
    """
    Sub-command "update": Update the value of an existing item in the
    manifest.
    """
    value_old = manifest.get(args.key)
    manifest.update(args.key, args.value)
    if not args.brief:
        print("Updated item '%s': '%s' -> '%s'" %
              (args.key, value_old, args.value))


def cmd_delete(args, manifest):
    """
    Sub-command "delete": Delete an item from the manifest.
    """
    manifest.delete(args.key)
    if not args.brief:
        print("Deleted item: %s" % args.key)


def main(description="Manage the observation manifest (YAML format)",
         default_file="manifest.yaml"):
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("-f", "--file", dest="file", default=default_file,
                        help="Manifest file (default: %s)" % default_file)
    parser.add_argument("-b", "--brief", dest="brief",
                        action="store_true", help="Be brief")
    subparsers = parser.add_subparsers(dest="cmd_name",
                                       title="sub-commands",
                                       help="additional help")
    # sub-command: show
    parser_show = subparsers.add_parser("show", help="Show manifest contents")
    parser_show.set_defaults(func=cmd_show)
    # sub-command: get
    parser_get = subparsers.add_parser("get", help="Get an item from manifest")
    parser_get.add_argument("key", help="key of the item")
    parser_get.set_defaults(func=cmd_get)
    # sub-command: set
    parser_set = subparsers.add_parser(
        "set", help="Set (add/update) an item in manifest")
    parser_set.add_argument("key", help="key of the item")
    parser_set.add_argument("value", help="value of the item")
    parser_set.set_defaults(func=cmd_set)
    # sub-command: add
    parser_add = subparsers.add_parser(
        "add", help="Add a new item to manifest")
    parser_add.add_argument("key", help="key of the item")
    parser_add.add_argument("value", help="value of the item")
    parser_add.set_defaults(func=cmd_add)
    # sub-command: update
    parser_update = subparsers.add_parser(
        "update", help="Update an existing item in manifest")
    parser_update.add_argument("key", help="key of the item")
    parser_update.add_argument("value", help="new value of the item")
    parser_update.set_defaults(func=cmd_update)
    # sub-command: delete
    parser_delete = subparsers.add_parser(
        "delete", help="Delete item from manifest")
    parser_delete.add_argument("key", help="key of the item")
    parser_delete.set_defaults(func=cmd_delete)
    #
    args = parser.parse_args()

    if os.path.exists(args.file):
        manifest_file = args.file
    else:
        manifest_file = find_manifest(args.file)

    manifest = Manifest(manifest_file)

    if args.cmd_name:
        # Dispatch sub-commands to call its specified function
        args.func(args, manifest)
    else:
        cmd_show(None, manifest)


if __name__ == "__main__":
    main()
