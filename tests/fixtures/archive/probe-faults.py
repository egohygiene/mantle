#!/usr/bin/env python3
"""Inject real I/O failures and publication races without requiring root changes."""

import argparse
import errno
import gzip
import importlib.util
import os
from pathlib import Path
import sys
from unittest import mock


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backend", type=Path)
    parser.add_argument("project", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("fault", choices=("read", "write", "changed", "publish", "device"))
    arguments = parser.parse_args()
    specification = importlib.util.spec_from_file_location("mantle_archive_probe", arguments.backend)
    archive = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(archive)
    triggered = False
    real_open, real_link = os.open, os.link
    real_stat = os.stat
    real_gzip_write = gzip.GzipFile.write

    def intercepted_open(path, flags, *positional, **keywords):
        nonlocal triggered
        source_read = os.path.basename(os.fsdecode(path)) == "source.py" and not flags & (os.O_WRONLY | os.O_RDWR)
        if source_read and arguments.fault in ("read", "changed") and not triggered:
            triggered = True
            if arguments.fault == "read":
                raise PermissionError(errno.EACCES, "Fixture selected file cannot be read")
            source = arguments.project / "source.py"
            source.write_bytes(source.read_bytes() + b"changed immediately before archive reading\n")
        return real_open(path, flags, *positional, **keywords)

    def intercepted_write(stream, data):
        nonlocal triggered
        if arguments.fault == "write":
            triggered = True
            raise OSError(errno.ENOSPC, "Fixture output filesystem is full")
        return real_gzip_write(stream, data)

    def intercepted_link(*positional, **keywords):
        nonlocal triggered
        if arguments.fault == "publish" and not triggered:
            triggered = True
            arguments.output.write_bytes(b"concurrent output must survive\n")
        return real_link(*positional, **keywords)

    foreign_inode = (arguments.project / "other-device").stat().st_ino if arguments.fault == "device" else None

    def intercepted_stat(*positional, **keywords):
        nonlocal triggered
        information = real_stat(*positional, **keywords)
        if arguments.fault == "device" and information.st_ino == foreign_inode:
            triggered = True
            fields = list(information)
            fields[2] = information.st_dev + 1
            return os.stat_result(fields)
        return information

    action = ["--dry-run"] if arguments.fault == "device" else ["--output", str(arguments.output)]
    sys.argv = [str(arguments.backend), str(arguments.project), *action, "--json"]
    status = 0
    with mock.patch.object(os, "open", side_effect=intercepted_open), \
            mock.patch.object(os, "stat", side_effect=intercepted_stat), \
            mock.patch.object(os, "link", side_effect=intercepted_link), \
            mock.patch.object(gzip.GzipFile, "write", intercepted_write):
        try:
            status = archive.main()
        except SystemExit as exception:
            status = exception.code
    assert triggered, "The requested I/O fault was not exercised"
    return status


if __name__ == "__main__":
    sys.exit(main())
