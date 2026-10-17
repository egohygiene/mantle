#!/usr/bin/env python3
"""Read-only storage measurements behind the public Mantle shell dispatcher."""

import sys

if sys.version_info < (3, 9):
    print("[mantle:error] storage diagnostics require Python 3.9 or newer.", file=sys.stderr)
    sys.exit(69)

import argparse
import errno
import heapq
import json
import os
import re
import stat


SCHEMA = "egohygiene.mantle.storage/v1"
LFS_POINTER_LIMIT = 20
DIRECTORY_FLAGS = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
FILE_FLAGS = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
SUPPORTED_DIRECTORY_APIS = (hasattr(os, "O_DIRECTORY") and hasattr(os, "O_NOFOLLOW")
                            and os.open in os.supports_dir_fd and os.stat in os.supports_dir_fd
                            and os.scandir in os.supports_fd)


class UsageParser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(64, "mantle storage: " + json.dumps(message, ensure_ascii=True)[1:-1] + "\n")


def nonnegative_integer(value):
    if not re.fullmatch(r"[0-9]+", value):
        raise argparse.ArgumentTypeError("must be a nonnegative byte integer")
    return int(value)


def positive_integer(value):
    result = nonnegative_integer(value)
    if result == 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return result


def parse_arguments():
    parser = UsageParser(prog="mantle storage")
    parser.add_argument("command", choices=("disk", "directory", "repo", "objects", "large-files"))
    parser.add_argument("path", nargs="?", default=".")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--limit", type=positive_integer)
    parser.add_argument("--min-size", type=nonnegative_integer)
    arguments = parser.parse_intermixed_args()
    if arguments.command != "large-files" and (arguments.limit is not None or arguments.min_size is not None):
        parser.error("--limit and --min-size are only available for large-files")
    arguments.limit = 20 if arguments.limit is None else arguments.limit
    arguments.min_size = 1048576 if arguments.min_size is None else arguments.min_size
    return arguments


def empty_stats():
    return dict(apparent_bytes=0, allocated_bytes=0, files=0, directories=0,
                symlinks=0, hardlinks=0, sparse_files=0, special_files=0,
                skipped_mounts=0, skipped_repositories=0)


class Measurement:
    def __init__(self, arguments):
        self.arguments = arguments
        self.path = os.path.abspath(arguments.path)
        self.warnings = []

    def warn(self, code, path, message):
        warning = dict(code=code, path=path, message=message)
        if warning not in self.warnings:
            self.warnings.append(warning)

    def error(self, path, exception):
        code = "permission_denied" if exception.errno in (errno.EACCES, errno.EPERM) else "scan_error"
        self.warn(code, path, str(exception))

    def open_target(self, directory=True):
        """Resolve explicit components before '..', holding no-follow directory FDs."""
        raw_path = self.arguments.path
        components = raw_path.split(os.sep)
        descriptor = None
        displayed = os.sep if os.path.isabs(raw_path) else os.getcwd()
        try:
            descriptor = os.open(displayed, DIRECTORY_FLAGS)
            for index, component in enumerate(components):
                if component in ("", "."):
                    continue
                displayed = os.path.join(displayed, component)
                information = os.stat(component, dir_fd=descriptor, follow_symlinks=False)
                if stat.S_ISLNK(information.st_mode):
                    self.warn("symlink_boundary", displayed,
                              "Symbolic-link targets are not followed; choose a physical path.")
                    return None
                final = not any(part not in ("", ".") for part in components[index + 1:])
                if final and not directory and not (stat.S_ISREG(information.st_mode) or stat.S_ISDIR(information.st_mode)):
                    self.warn("unsafe_target", displayed, "Disk targets must be regular files or directories; special files are not opened.")
                    return None
                flags = FILE_FLAGS if final and not directory else DIRECTORY_FLAGS
                next_descriptor = os.open(component, flags, dir_fd=descriptor)
                os.close(descriptor)
                descriptor = next_descriptor
            result = descriptor
            descriptor = None
            return result
        except OSError as exception:
            self.error(displayed, exception)
            return None
        finally:
            if descriptor is not None:
                os.close(descriptor)

    def allocated(self, information, path):
        if not hasattr(information, "st_blocks"):
            if not any(warning["code"] == "allocation_unavailable" for warning in self.warnings):
                self.warn("allocation_unavailable", path,
                          "The filesystem does not expose allocated file blocks.")
            return None
        return information.st_blocks * 512

    def scan(self, descriptor, path, exclude_names=(), prune_repositories=True, on_file=None, warn_symlinks=False):
        totals = empty_stats()
        root_device = os.fstat(descriptor).st_dev
        seen = set()

        def walk(current_descriptor, current_path, relative_prefix):
            totals["directories"] += 1
            try:
                with os.scandir(current_descriptor) as entries:
                    names = sorted(entry.name for entry in entries)
            except OSError as exception:
                self.error(current_path, exception)
                return
            for name in names:
                if not relative_prefix and name in exclude_names:
                    continue
                entry_path = os.path.join(current_path, name)
                relative_path = os.path.join(relative_prefix, name)
                try:
                    information = os.stat(name, dir_fd=current_descriptor, follow_symlinks=False)
                    if stat.S_ISLNK(information.st_mode):
                        totals["symlinks"] += 1
                        if warn_symlinks:
                            self.warn("git_metadata_boundary", entry_path, "Symbolic-link Git metadata was not followed.")
                        continue
                    if information.st_dev != root_device:
                        totals["skipped_mounts"] += 1
                        self.warn("filesystem_boundary", entry_path, "A different filesystem was not scanned.")
                        continue
                    if stat.S_ISDIR(information.st_mode):
                        child = os.open(name, DIRECTORY_FLAGS, dir_fd=current_descriptor)
                        try:
                            child_information = os.fstat(child)
                            if child_information.st_dev != root_device:
                                totals["skipped_mounts"] += 1
                                self.warn("filesystem_boundary", entry_path, "A different filesystem was not scanned.")
                                continue
                            if (child_information.st_dev, child_information.st_ino) != (information.st_dev, information.st_ino):
                                self.warn("changed_during_scan", entry_path, "The directory changed while scanning.")
                                continue
                            if prune_repositories and self.repository_boundary(child, allow_metadata=not relative_prefix and name == ".git"):
                                totals["skipped_repositories"] += 1
                                continue
                            walk(child, entry_path, relative_path)
                        finally:
                            os.close(child)
                    elif stat.S_ISREG(information.st_mode):
                        identity = (information.st_dev, information.st_ino)
                        if identity in seen:
                            totals["hardlinks"] += 1
                            continue
                        seen.add(identity)
                        totals["files"] += 1
                        totals["apparent_bytes"] += information.st_size
                        allocated = self.allocated(information, entry_path)
                        if allocated is None:
                            totals["allocated_bytes"] = None
                        elif totals["allocated_bytes"] is not None:
                            totals["allocated_bytes"] += allocated
                        if allocated is not None and allocated < information.st_size:
                            totals["sparse_files"] += 1
                        if on_file is not None:
                            on_file(current_descriptor, name, relative_path, information, allocated)
                    else:
                        totals["special_files"] += 1
                except OSError as exception:
                    self.error(entry_path, exception)
                except RecursionError:
                    self.warn("scan_limit", entry_path, "The directory nesting exceeded the safe scan depth.")

        walk(descriptor, path, "")
        return totals

    @staticmethod
    def exists(descriptor, name):
        try:
            os.stat(name, dir_fd=descriptor, follow_symlinks=False)
            return True
        except FileNotFoundError:
            return False

    @classmethod
    def repository_boundary(cls, descriptor, allow_metadata=False):
        if cls.exists(descriptor, ".git"):
            return True
        if allow_metadata:
            return False
        try:
            return (stat.S_ISREG(os.stat("HEAD", dir_fd=descriptor, follow_symlinks=False).st_mode)
                    and stat.S_ISDIR(os.stat("objects", dir_fd=descriptor, follow_symlinks=False).st_mode)
                    and stat.S_ISDIR(os.stat("refs", dir_fd=descriptor, follow_symlinks=False).st_mode))
        except FileNotFoundError:
            return False

    def disk(self, descriptor):
        information = os.fstatvfs(descriptor)
        unit = information.f_frsize
        return dict(total_bytes=information.f_blocks * unit,
                    used_bytes=(information.f_blocks - information.f_bfree) * unit,
                    free_bytes=information.f_bavail * unit)

    def large_files(self, descriptor):
        # The heap retains only the requested largest candidates, never the whole listing.
        candidates = []

        class Candidate:
            def __init__(self, item):
                self.item = item

            def __lt__(self, other):
                left, right = self.item, other.item
                if left["apparent_bytes"] != right["apparent_bytes"]:
                    return left["apparent_bytes"] < right["apparent_bytes"]
                return left["path"] > right["path"]

        def consider(_descriptor, _name, relative_path, information, allocated):
            if information.st_size < self.arguments.min_size:
                return
            candidate = Candidate(dict(path=relative_path, apparent_bytes=information.st_size,
                                       allocated_bytes=allocated))
            if len(candidates) < self.arguments.limit:
                heapq.heappush(candidates, candidate)
            elif candidates[0] < candidate:
                heapq.heapreplace(candidates, candidate)

        totals = self.scan(descriptor, self.path, on_file=consider)
        files = sorted((candidate.item for candidate in candidates),
                       key=lambda item: (-item["apparent_bytes"], item["path"]))
        return dict(limit=self.arguments.limit, min_size_bytes=self.arguments.min_size,
                    files=files, scanned_files=totals["files"])

    def open_child_directory(self, descriptor, name, path):
        information = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
        if not stat.S_ISDIR(information.st_mode):
            self.warn("git_metadata_boundary", path, "Git metadata must be a real local directory; it was not followed.")
            return None
        if information.st_dev != os.fstat(descriptor).st_dev:
            self.warn("filesystem_boundary", path, "A different filesystem was not scanned.")
            return None
        child = os.open(name, DIRECTORY_FLAGS, dir_fd=descriptor)
        observed = os.fstat(child)
        if (observed.st_dev, observed.st_ino) != (information.st_dev, information.st_ino):
            os.close(child)
            self.warn("changed_during_scan", path, "The directory changed while scanning.")
            return None
        return child

    def object_storage(self, objects_descriptor):
        result = {key: dict(count=0, apparent_bytes=0, allocated_bytes=0)
                  for key in ("loose", "packs", "other")}
        objects_path = os.path.join(self.path, ".git", "objects")

        def classify(_descriptor, _name, relative_path, information, allocated):
            parts = relative_path.split(os.sep)
            if len(parts) == 2 and re.fullmatch(r"[0-9a-f]{2}", parts[0]) and re.fullmatch(r"[0-9a-f]{38}|[0-9a-f]{62}", parts[1]):
                category = "loose"
            elif len(parts) == 2 and parts[0] == "pack" and parts[1].endswith(".pack"):
                category = "packs"
            else:
                category = "other"
            bucket = result[category]
            bucket["count"] += 1
            bucket["apparent_bytes"] += information.st_size
            if allocated is None:
                bucket["allocated_bytes"] = None
            elif bucket["allocated_bytes"] is not None:
                bucket["allocated_bytes"] += allocated

        self.scan(objects_descriptor, objects_path, prune_repositories=False, on_file=classify, warn_symlinks=True)
        return result

    def lfs_pointer(self, descriptor, name, relative_path, information, pointers):
        if information.st_size > 4096:
            return
        pointer_descriptor = os.open(name, FILE_FLAGS, dir_fd=descriptor)
        try:
            observed = os.fstat(pointer_descriptor)
            if not stat.S_ISREG(observed.st_mode) or (observed.st_dev, observed.st_ino, observed.st_size) != (information.st_dev, information.st_ino, information.st_size):
                self.warn("changed_during_scan", os.path.join(self.path, relative_path), "The file changed while scanning.")
                return
            content = os.read(pointer_descriptor, 4097)
        finally:
            os.close(pointer_descriptor)
        lines = content.splitlines()
        if not lines or lines[0] != b"version https://git-lfs.github.com/spec/v1":
            return
        oid_lines = [line for line in lines[1:] if re.fullmatch(rb"oid sha256:[0-9a-f]{64}", line)]
        size_lines = [line for line in lines[1:] if re.fullmatch(rb"size [0-9]+", line)]
        if len(oid_lines) != 1 or len(size_lines) != 1:
            return
        declared = int(size_lines[0].split(b" ", 1)[1])
        pointers["count"] += 1
        pointers["declared_bytes"] += declared
        if len(pointers["files"]) < LFS_POINTER_LIMIT:
            pointers["files"].append(dict(path=relative_path, size_bytes=declared,
                                          oid=oid_lines[0][4:].decode("ascii")))
        else:
            pointers["truncated"] = True

    def repository(self, descriptor):
        git_path = os.path.join(self.path, ".git")
        if not self.exists(descriptor, ".git"):
            self.warn("repository_root_required", self.path,
                      "Choose the root of a standard working repository containing .git; bare repositories are unsupported.")
            return {}
        git_descriptor = self.open_child_directory(descriptor, ".git", git_path)
        if git_descriptor is None:
            return {}
        objects_descriptor = None
        try:
            if self.exists(git_descriptor, "commondir"):
                self.warn("git_metadata_boundary", os.path.join(git_path, "commondir"),
                          "Shared Git metadata is an external boundary and was not followed.")
                return {}
            try:
                head = os.stat("HEAD", dir_fd=git_descriptor, follow_symlinks=False)
                if not stat.S_ISREG(head.st_mode):
                    self.warn("git_metadata_boundary", os.path.join(git_path, "HEAD"), "Git HEAD must be a regular local file.")
                    return {}
                objects_descriptor = self.open_child_directory(git_descriptor, "objects", os.path.join(git_path, "objects"))
            except FileNotFoundError:
                self.warn("invalid_repository", git_path, "Standard local Git metadata (HEAD and objects) is required.")
                return {}
            if objects_descriptor is None:
                return {}
            try:
                info_descriptor = self.open_child_directory(objects_descriptor, "info", os.path.join(git_path, "objects", "info"))
            except FileNotFoundError:
                info_descriptor = None
            except OSError as exception:
                self.error(os.path.join(git_path, "objects", "info"), exception)
                info_descriptor = None
            if info_descriptor is not None:
                try:
                    for name in ("alternates", "http-alternates"):
                        alternate_path = os.path.join(git_path, "objects", "info", name)
                        try:
                            if self.exists(info_descriptor, name):
                                self.warn("git_alternates_boundary", alternate_path,
                                          "Alternate object storage was not read or followed; only local objects are measured.")
                        except OSError as exception:
                            self.error(alternate_path, exception)
                finally:
                    os.close(info_descriptor)
            objects = self.object_storage(objects_descriptor)
            if self.arguments.command == "objects":
                return objects
            pointers = dict(count=0, declared_bytes=0, files=[], truncated=False)

            def inspect_pointer(file_descriptor, name, relative_path, information, _allocated):
                self.lfs_pointer(file_descriptor, name, relative_path, information, pointers)

            worktree = self.scan(descriptor, self.path, exclude_names=(".git",), on_file=inspect_pointer)
            git_totals = self.scan(git_descriptor, git_path, prune_repositories=False, warn_symlinks=True)
            cache = empty_stats()
            lfs_descriptor = None
            cache_descriptor = None
            cache_path = os.path.join(git_path, "lfs")
            try:
                if self.exists(git_descriptor, "lfs"):
                    lfs_descriptor = self.open_child_directory(git_descriptor, "lfs", cache_path)
                    if lfs_descriptor is not None and self.exists(lfs_descriptor, "objects"):
                        cache_path = os.path.join(git_path, "lfs", "objects")
                        cache_descriptor = self.open_child_directory(lfs_descriptor, "objects", cache_path)
                        if cache_descriptor is not None:
                            cache = self.scan(cache_descriptor, cache_path, prune_repositories=False, warn_symlinks=True)
            except OSError as exception:
                self.error(cache_path, exception)
            finally:
                if cache_descriptor is not None:
                    os.close(cache_descriptor)
                if lfs_descriptor is not None:
                    os.close(lfs_descriptor)
            return dict(worktree=worktree, git=git_totals, objects=objects,
                        lfs=dict(cache=cache, pointers=pointers))
        finally:
            if objects_descriptor is not None:
                os.close(objects_descriptor)
            os.close(git_descriptor)

    def run(self):
        result = {}
        supported = (SUPPORTED_DIRECTORY_APIS
                     and (self.arguments.command != "disk" or hasattr(os, "fstatvfs")))
        if not supported:
            self.warn("unsupported_platform", self.path,
                      "Safe storage scans require Unix directory descriptors and no-follow support.")
        if "\0" in self.arguments.path:
            self.warn("unsafe_target", self.path, "Paths cannot contain a NUL byte.")
            supported = False
        descriptor = self.open_target(directory=self.arguments.command != "disk") if supported else None
        if descriptor is not None:
            try:
                if self.arguments.command == "disk":
                    result = self.disk(descriptor)
                elif self.arguments.command == "directory":
                    result = self.scan(descriptor, self.path)
                elif self.arguments.command == "large-files":
                    result = self.large_files(descriptor)
                else:
                    result = self.repository(descriptor)
            except OSError as exception:
                self.error(self.path, exception)
            except RecursionError:
                self.warn("scan_limit", self.path, "The directory nesting exceeded the safe scan depth.")
            finally:
                os.close(descriptor)
        self.warnings.sort(key=lambda warning: (warning["path"], warning["code"], warning["message"]))
        return dict(schema=SCHEMA, command=self.arguments.command, path=self.path,
                    complete=not self.warnings, data=result, warnings=self.warnings)


def human_output(result):
    # JSON string escaping keeps filenames and error text safe for terminals.
    print("Mantle storage: " + result["command"] + " " + json.dumps(result["path"], ensure_ascii=True))
    print("Status: " + ("complete" if result["complete"] else "partial"))

    def display(value, prefix=""):
        if isinstance(value, dict):
            for key, nested in value.items():
                display(nested, prefix + key + ".")
        elif isinstance(value, list):
            if not value:
                print(prefix[:-1] + ": []")
            for index, nested in enumerate(value, 1):
                display(nested, prefix + str(index) + ".")
        else:
            rendered = json.dumps(value, ensure_ascii=True)
            suffix = " bytes" if prefix.rstrip(".").split(".")[-1].endswith("bytes") and value is not None else ""
            print(prefix[:-1] + ": " + rendered + suffix)

    display(result["data"])
    for warning in result["warnings"]:
        print("Warning " + warning["code"] + " " + json.dumps(warning["path"], ensure_ascii=True)
              + ": " + json.dumps(warning["message"], ensure_ascii=True))


def main():
    arguments = parse_arguments()
    result = Measurement(arguments).run()
    if arguments.json:
        print(json.dumps(result, ensure_ascii=True, sort_keys=True))
    else:
        human_output(result)
    return 0 if result["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
