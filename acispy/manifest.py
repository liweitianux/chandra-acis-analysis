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
from collections import OrderedDict
import argparse

import ruamel.yaml


class Manifest:
    """
    Manage the observational products manifest.
    """
    def __init__(self, filepath):
        self.filepath = os.path.abspath(filepath)
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

    def has(self, key):
        return True if key in self.manifest else False

    def get(self, key):
        """
        Get the value of the specified item in the manifest.

        Parameters
        ----------
        key : str
            The key of the item to be requested.

        Raises
        ------
        KeyError :
            If the specified item doesn't exist.
        """
        if self.has(key):
            return self.manifest[key]
        else:
            raise KeyError("manifest doesn't have item: '%s'" % key)

    def gets(self, keys, default=None, splitlist=False):
        """
        Get the value of the specified item in the manifest.

        Parameters
        ----------
        keys : list[str]
            A list of keys specifying the items to be requested.
        default : optional
            The default value to return if the item not exists.
        splitlist : bool, optional
            Split the item value if it is a list, making it is easier
            to export as CSV format.

        Returns
        -------
        data : `~OrderedDict`
            Ordered dictionary containing the requested items.

        Returns
        -------
        """
        data = OrderedDict([
            (key, self.manifest.get(key, default)) for key in keys
        ])
        if splitlist:
            ds = OrderedDict()
            for k, v in data.items():
                if isinstance(v, list):
                    for i, vi in enumerate(v):
                        ki = "{0}[{1}]".format(k, i)
                        ds[ki] = vi
                else:
                    ds[k] = v
            data = ds
        return data

    def getpath(self, key, relative=False, sep=None):
        """
        Get the absolute path to the specified item by joining
        with the location of this manifest file.

        Parameters
        ----------
        key : str
            Key of the file item
        relative : bool, optional
            Whether return the file path(s) as relative path w.r.t.
            the current working directory?
        sep : str, optional
            If not ``None``, join the multiple file paths with the
            specified separator, instead of returning a list of paths.
        """
        value = self.get(key)
        cwd = os.getcwd()
        if isinstance(value, list):
            path = [os.path.join(os.path.dirname(self.filepath), f)
                    for f in value]
            if relative:
                path = [os.path.relpath(p, start=cwd) for p in path]
            if sep is not None:
                path = sep.join(path)
        else:
            path = os.path.join(os.path.dirname(self.filepath), value)
            if relative:
                path = os.path.relpath(path, start=cwd)
        return path

    def set(self, key, value):
        """
        Set the value of the specified item in the manifest.
        (Will add a new item or update an existing item.)
        """
        self.manifest[key] = self.parse_value(value)
        self.save()

    def setpath(self, key, path):
        """
        Get the relative path of the given file w.r.t. this manifest file,
        and set it to be the value of the specified item.
        (Will add a new item or update an existing item.)
        """
        dirname = os.path.dirname(self.filepath)
        if isinstance(path, list):
            abspath = [os.path.abspath(p) for p in path]
            relpath = [os.path.relpath(p, start=dirname) for p in abspath]
            if len(relpath) == 1:
                relpath = relpath[0]
        else:
            abspath = os.path.abspath(path)
            relpath = os.path.relpath(abspath, start=dirname)
        self.manifest[key] = relpath
        self.save()

    def add(self, key, value):
        """
        Add the specified new item in the manifest.

        If the specified item already exists, raise a ``KeyError``.
        """
        if key in self.manifest:
            raise KeyError("manifest already has item: '%s'" % key)
        else:
            self.set(key, value)

    def update(self, key, value):
        """
        Update the specified existing item in the manifest.

        If the specified item doesn't exist, raise a ``KeyError``.
        """
        if key in self.manifest:
            self.set(key, value)
        else:
            raise KeyError("manifest doesn't have item: '%s'" % key)

    def delete(self, key):
        """
        Delete the specified item from the manifest.
        """
        del self.manifest[key]
        self.save()

    @classmethod
    def parse_value(self, value):
        """
        Parse the given (list of) value(s) from string.

        If the value list only has length of 1, then just return
        the only element without list enclosure.
        """
        if isinstance(value, list):
            pv = [self.parse_value_single(v) for v in value]
            if len(pv) == 1:
                return pv[0]
            else:
                return pv
        else:
            return self.parse_value_single(value)

    @staticmethod
    def parse_value_single(value):
        """
        Try to parse the given value from string to integer, float, boolean
        or string.

        If the input value is not string, then just ignore the parse.
        """
        if not isinstance(value, str):
            return value

        try:
            v = int(value)
        except ValueError:
            try:
                v = float(value)
            except ValueError:
                # string/boolean
                if value.lower() in ["true", "yes"]:
                    v = True
                elif value.lower() in ["false", "no"]:
                    v = False
                else:
                    v = value  # string
        return v


def find_manifest(filename="manifest.yaml", startdir=os.getcwd()):
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
        Cannot found the specified manifest
    """
    dirname = startdir
    filepath = os.path.join(dirname, filename)
    while dirname != "/":
        if os.path.exists(filepath):
            return filepath
        # go upper by one level
        dirname = os.path.dirname(dirname)
        filepath = os.path.join(dirname, filename)
    # not found
    raise FileNotFoundError("cannot found manifest file: %s" % filename)


def get_manifest(filename="manifest.yaml"):
    """
    Find the manifest file and return the Manifest instance of it.

    Parameters
    ----------
    filename : str, optional
        Filename of the manifest file (default: ``manifest.yaml``)

    Returns
    -------
    manifest : `~Manifest`
        Manifest instance of the found manifest file.
    """
    return Manifest(find_manifest(filename))


# COMMAND-LINE INTERFACE ----------------------------------------------------

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
    value = manifest.get(args.key)
    if isinstance(value, list):
        if args.field:
            print(value[args.field-1])
        else:
            vs = [str(v) for v in value]
            print(args.separator.join(vs))
    else:
        print(value)


def cmd_getpath(args, manifest):
    """
    Sub-command "getpath": Get the absolute path to the specified file
    item in the manifest.
    """
    if not args.brief:
        print("%s:" % args.key, end=" ")
    path = manifest.getpath(args.key, relative=args.relative,
                            sep=args.separator)
    print(path)


def cmd_set(args, manifest):
    """
    Sub-command "set": Set the value of an item in the manifest.
    (Will add a new item or update an existing item.)
    """
    manifest.set(args.key, args.value)
    if not args.brief:
        print("Set item '{0}': {1}".format(args.key, manifest.get(args.key)))


def cmd_setpath(args, manifest):
    """
    Sub-command "setpath": Set the specified file item in the manifest
    to be the relative path of the given file w.r.t. the manifest file.
    """
    manifest.setpath(args.key, args.value)
    if not args.brief:
        print("Set file item '{0}': {1}".format(args.key,
                                                manifest.get(args.key)))


def cmd_add(args, manifest):
    """
    Sub-command "add": Add a new item to the manifest.
    """
    manifest.add(args.key, args.value)
    if not args.brief:
        print("Added item '{0}': {1}".format(args.key, manifest.get(args.key)))


def cmd_update(args, manifest):
    """
    Sub-command "update": Update the value of an existing item in the
    manifest.
    """
    value_old = manifest.get(args.key)
    manifest.update(args.key, args.value)
    if not args.brief:
        print("Updated item '{0}': {1} -> {2}".format(
              args.key, value_old, manifest.get(args.key)))


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
    parser.add_argument("-F", "--file", dest="file", default=default_file,
                        help="Manifest file (default: %s)" % default_file)
    parser.add_argument("-b", "--brief", dest="brief",
                        action="store_true", help="Be brief")
    parser.add_argument("-C", "--directory", dest="directory", default=".",
                        help="From where to find the manifest file")
    parser.add_argument("-s", "--separator", dest="separator", default=" ",
                        help="Separator to join output list values " +
                        "(default: whitespace)")
    subparsers = parser.add_subparsers(dest="cmd_name",
                                       title="sub-commands",
                                       help="additional help")
    # sub-command: show
    parser_show = subparsers.add_parser("show", help="Show manifest contents")
    parser_show.set_defaults(func=cmd_show)
    # sub-command: get
    parser_get = subparsers.add_parser("get", help="Get an item from manifest")
    parser_get.add_argument("-f", "--field", dest="field", type=int,
                            help="which field to get (default: all fields)")
    parser_get.add_argument("key", help="key of the item")
    parser_get.set_defaults(func=cmd_get)
    # sub-command: getpath
    parser_getpath = subparsers.add_parser(
        "getpath", help="Get the path to a file item from manifest")
    parser_getpath.add_argument("-r", "--relative", dest="relative",
                                action="store_true",
                                help="Return relative path w.r.t. current " +
                                "working directory instead of absolute path")
    parser_getpath.add_argument("key", help="key of the file item")
    parser_getpath.set_defaults(func=cmd_getpath)
    # sub-command: set
    parser_set = subparsers.add_parser(
        "set", help="Set (add/update) an item in manifest")
    parser_set.add_argument("key", help="key of the item")
    parser_set.add_argument("value", nargs="+",
                            help="value of the item")
    parser_set.set_defaults(func=cmd_set)
    # sub-command: setpath
    parser_setpath = subparsers.add_parser(
        "setpath", help="Set a file item using relative path of given files")
    parser_setpath.add_argument("key", help="key of the file item")
    parser_setpath.add_argument("value", nargs="+",
                                help="paths to the files")
    parser_setpath.set_defaults(func=cmd_setpath)
    # sub-command: add
    parser_add = subparsers.add_parser(
        "add", help="Add a new item to manifest")
    parser_add.add_argument("key", help="key of the item")
    parser_add.add_argument("value", nargs="+",
                            help="value of the item")
    parser_add.set_defaults(func=cmd_add)
    # sub-command: update
    parser_update = subparsers.add_parser(
        "update", help="Update an existing item in manifest")
    parser_update.add_argument("key", help="key of the item")
    parser_update.add_argument("value", nargs="+",
                               help="new value of the item")
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
        manifest_file = find_manifest(
            args.file, startdir=os.path.abspath(args.directory))

    manifest = Manifest(manifest_file)

    if args.cmd_name:
        # Dispatch sub-commands to call its specified function
        args.func(args, manifest)
    else:
        cmd_show(None, manifest)
