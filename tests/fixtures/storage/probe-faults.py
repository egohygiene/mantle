#!/usr/bin/env python3
"""Inject filesystem failures without privileges, mounts, or platform skips."""

import argparse
import errno
import importlib.util
import json
import os
from pathlib import Path
import stat
import sys
from unittest import mock


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backend", type=Path)
    parser.add_argument("directory", type=Path)
    parser.add_argument("fault", choices=("permission", "device", "allocation", "lfs-permission"))
    arguments = parser.parse_args()
    specification = importlib.util.spec_from_file_location("mantle_storage", arguments.backend)
    storage = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(storage)
    measurement_arguments = argparse.Namespace(
        command="repo" if arguments.fault == "lfs-permission" else "directory",
        path=str(arguments.directory), json=True,
        limit=20, min_size=1048576,
    )
    real_scandir, real_stat, real_fstat = os.scandir, os.stat, os.fstat
    blocked_path = arguments.directory / (".git/lfs" if arguments.fault == "lfs-permission" else "nested")
    blocked_inode = blocked_path.stat().st_ino

    def permission_scandir(descriptor):
        if real_fstat(descriptor).st_ino == blocked_inode:
            raise PermissionError(errno.EACCES, "Fixture directory is unreadable")
        return real_scandir(descriptor)

    def foreign_device(information):
        if information.st_ino != blocked_inode:
            return information
        fields = list(information)
        fields[2] = information.st_dev + 1
        return os.stat_result(fields)

    class WithoutAllocation:
        def __init__(self, information):
            self.information = information

        def __getattr__(self, name):
            if name == "st_blocks":
                raise AttributeError(name)
            return getattr(self.information, name)

    def altered_stat(*positional, **keywords):
        information = real_stat(*positional, **keywords)
        if arguments.fault == "lfs-permission" and information.st_ino == blocked_inode:
            raise PermissionError(errno.EACCES, "Fixture LFS cache is unreadable")
        if arguments.fault == "device":
            return foreign_device(information)
        if arguments.fault == "allocation" and stat.S_ISREG(information.st_mode):
            return WithoutAllocation(information)
        return information

    with mock.patch.object(os, "scandir", side_effect=permission_scandir if arguments.fault == "permission" else real_scandir), \
            mock.patch.object(os, "stat", side_effect=altered_stat if arguments.fault != "permission" else real_stat), \
            mock.patch.object(os, "fstat", side_effect=lambda descriptor: foreign_device(real_fstat(descriptor)) if arguments.fault == "device" else real_fstat(descriptor)):
        result = storage.Measurement(measurement_arguments).run()
    print(json.dumps(result, ensure_ascii=True))
    return 0 if result["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
