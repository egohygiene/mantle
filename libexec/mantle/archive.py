#!/usr/bin/env python3
"""Select regular project files and publish a no-clobber tar.gz archive."""

import sys

if sys.version_info < (3, 9):
    print("[mantle:error] project archives require Python 3.9 or newer.", file=sys.stderr)
    sys.exit(69)

import argparse
import gzip
import hashlib
import json
import ntpath
import os
import re
import secrets
import shutil
import stat
import subprocess
import tarfile


SCHEMA = "egohygiene.mantle.archive/v1"
DIRECTORY_FLAGS = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
FILE_FLAGS = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
SUPPORTED = (hasattr(os, "O_NOFOLLOW") and hasattr(os, "O_DIRECTORY")
             and os.open in os.supports_dir_fd and os.stat in os.supports_dir_fd
             and os.scandir in os.supports_fd and os.link in os.supports_dir_fd)
FILTER_DIRECTORIES = {
    "node_modules", ".venv", "venv", "vendor", "__pycache__", ".pytest_cache",
    ".mypy_cache", ".ruff_cache", ".cache", ".tox", ".nox", "build", "dist",
    "target", ".next", ".nuxt", "coverage", ".ssh", ".aws", ".azure",
    ".gnupg", ".kube", ".docker",
}
FILTER_FILES = {
    "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519", "credentials.json", "secrets.json",
    "secrets.yaml", "secrets.yml", ".netrc", "_netrc", ".npmrc", ".pypirc",
    "service-account.json", "service_account.json",
}


class UsageParser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(64, "mantle archive: " + json.dumps(message, ensure_ascii=True)[1:-1] + "\n")


def arguments():
    parser = UsageParser(prog="mantle archive")
    parser.add_argument("path", nargs="?", default=".")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--output")
    parser.add_argument("--include", action="append", default=[])
    parser.add_argument("--reproducible", action="store_true")
    parser.add_argument("--json", action="store_true")
    result = parser.parse_intermixed_args()
    if not result.dry_run and result.output is None:
        parser.error("--output FILE.tar.gz is required unless --dry-run is used")
    if result.output is not None and not result.output.endswith(".tar.gz"):
        parser.error("--output must name a .tar.gz file")
    for path in result.include:
        if not portable_name(path):
            parser.error("--include must be an exact portable relative file path: " + path)
    return result


def portable_name(path):
    return (bool(path) and not path.startswith("/") and "\\" not in path
            and not ntpath.splitdrive(path)[0] and "\0" not in path
            and all(component not in ("", ".", "..") for component in path.split("/")))


def snapshot(information):
    return (information.st_dev, information.st_ino, information.st_mode,
            information.st_size, information.st_mtime_ns, information.st_ctime_ns)


def identity(information):
    return information.st_dev, information.st_ino


def filtered_file(name):
    name = name.lower()
    if name == ".env" or name.startswith(".env."):
        return not name.endswith((".example", ".sample", ".template", ".defaults"))
    return name in FILTER_FILES or name.endswith((".pem", ".key", ".p12", ".pfx"))


class Archive:
    def __init__(self, options):
        self.options = options
        self.path = os.path.abspath(options.path)
        self.output = os.path.abspath(options.output) if options.output is not None else None
        self.included = []
        self.excluded = []
        self.warnings = []
        self.selected = {}
        self.directories = {}
        self.includes = set(options.include)
        self.observed_includes = set()
        self.selection_mode = "filesystem"
        self.sha256 = None
        self.status = 1
        self.output_identity = None
        self.output_parent = None
        self.output_name = None
        self.root = None

    def warn(self, code, path, message):
        warning = dict(code=code, path=path, message=message)
        if warning not in self.warnings:
            self.warnings.append(warning)

    def error(self, path, exception):
        self.warn("io_error", path, str(exception))

    def exclude(self, path, reason):
        self.excluded.append(dict(path=path, reason=reason))

    def open_path(self, raw_path, directory=True):
        """Open each explicit component without normalizing away a link/.. boundary."""
        descriptor = None
        displayed = os.sep if os.path.isabs(raw_path) else os.getcwd()
        try:
            descriptor = os.open(displayed, DIRECTORY_FLAGS)
            components = raw_path.split(os.sep)
            for index, name in enumerate(components):
                if name in ("", "."):
                    continue
                displayed = os.path.join(displayed, name)
                information = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
                if stat.S_ISLNK(information.st_mode):
                    self.warn("symlink_boundary", displayed, "Choose a physical path; symbolic-link components are not followed.")
                    return None
                final = not any(part not in ("", ".") for part in components[index + 1:])
                if final and not directory and not stat.S_ISREG(information.st_mode):
                    self.warn("unsafe_file", displayed, "A regular file is required.")
                    return None
                child = os.open(name, FILE_FLAGS if final and not directory else DIRECTORY_FLAGS, dir_fd=descriptor)
                if identity(os.fstat(child)) != identity(information):
                    os.close(child)
                    self.warn("changed_during_scan", displayed, "A path component changed while opening it.")
                    return None
                os.close(descriptor)
                descriptor = child
            result, descriptor = descriptor, None
            return result
        except OSError as exception:
            self.error(displayed, exception)
            return None
        finally:
            if descriptor is not None:
                os.close(descriptor)

    def child_directory(self, parent, name, path):
        information = os.stat(name, dir_fd=parent, follow_symlinks=False)
        if not stat.S_ISDIR(information.st_mode) or information.st_dev != os.fstat(self.root).st_dev:
            self.warn("unsafe_git_metadata", path, "Git metadata must be a real directory on the source filesystem.")
            return None
        child = os.open(name, DIRECTORY_FLAGS, dir_fd=parent)
        if identity(os.fstat(child)) != identity(information):
            os.close(child)
            self.warn("changed_during_scan", path, "Git metadata changed while opening it.")
            return None
        return child

    @staticmethod
    def exists(parent, name):
        try:
            return os.stat(name, dir_fd=parent, follow_symlinks=False)
        except FileNotFoundError:
            return None

    def nested_repository(self, descriptor):
        if self.exists(descriptor, ".git") is not None:
            return True
        head = self.exists(descriptor, "HEAD")
        objects = self.exists(descriptor, "objects")
        refs = self.exists(descriptor, "refs")
        return (head is not None and stat.S_ISREG(head.st_mode)
                and objects is not None and stat.S_ISDIR(objects.st_mode)
                and refs is not None and stat.S_ISDIR(refs.st_mode))

    def prepare_output(self):
        if self.options.output is None:
            return
        raw_parent, self.output_name = os.path.split(self.options.output)
        if self.output_name in ("", ".", ".."):
            self.warn("unsafe_output", self.output, "The output must be a file in an existing physical directory.")
            return
        self.output_parent = self.open_path(raw_parent or ".")
        if self.output_parent is not None:
            existing = self.exists(self.output_parent, self.output_name)
            if existing is not None:
                self.output_identity = identity(existing)
                self.warn("output_exists", self.output, "The output already exists and will never be replaced.")

    def scan(self, descriptor, prefix="", inherited_filter=False):
        self.directories[prefix] = snapshot(os.fstat(descriptor))
        with os.scandir(descriptor) as entries:
            names = sorted(entry.name for entry in entries)
        for name in names:
            relative = prefix + "/" + name if prefix else name
            displayed = os.path.join(self.path, relative)
            try:
                information = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
                if (self.selection_mode == "git" and name == ".gitignore"
                        and (not stat.S_ISREG(information.st_mode) or information.st_dev != os.fstat(self.root).st_dev)):
                    self.warn("unsafe_git_metadata", displayed, "Git ignore files must be regular files on the source filesystem.")
                if name == ".git":
                    self.exclude(relative, "git_metadata")
                elif self.output == displayed or (self.output_identity is not None and identity(information) == self.output_identity):
                    self.exclude(relative, "output")
                elif stat.S_ISLNK(information.st_mode):
                    self.exclude(relative, "symlink")
                    if self.selection_mode == "git" and name == ".gitignore":
                        self.warn("unsafe_git_metadata", displayed, "Git ignore files cannot be symbolic links.")
                elif information.st_dev != os.fstat(self.root).st_dev:
                    self.exclude(relative, "filesystem_boundary")
                elif stat.S_ISDIR(information.st_mode):
                    child = os.open(name, DIRECTORY_FLAGS, dir_fd=descriptor)
                    try:
                        if identity(os.fstat(child)) != identity(information):
                            self.warn("changed_during_scan", displayed, "The directory changed while scanning.")
                        elif self.nested_repository(child):
                            self.exclude(relative, "nested_repository")
                        else:
                            common_filter = inherited_filter or name.lower() in FILTER_DIRECTORIES
                            needed = any(path.startswith(relative + "/") for path in self.includes)
                            if common_filter and not needed:
                                self.exclude(relative, "common_filter")
                            else:
                                self.scan(child, relative, common_filter)
                    finally:
                        os.close(child)
                elif stat.S_ISREG(information.st_mode):
                    if not portable_name(relative):
                        self.exclude(relative, "unsafe_name")
                        self.warn("unsafe_archive_name", displayed, "A portable relative tar member name is required.")
                    elif relative not in self.includes and (inherited_filter or filtered_file(name)):
                        self.exclude(relative, "common_filter")
                    else:
                        self.selected[relative] = information
                        if relative in self.includes:
                            self.observed_includes.add(relative)
                else:
                    self.exclude(relative, "special_file")
            except (OSError, RecursionError) as exception:
                self.error(displayed, exception)

    def read_metadata(self, parent, name, path, limit=1048576):
        information = self.exists(parent, name)
        if information is None:
            return None, None
        if not stat.S_ISREG(information.st_mode) or information.st_dev != os.fstat(self.root).st_dev:
            self.warn("unsafe_git_metadata", path, "Git metadata must be a regular file on the source filesystem.")
            return None, None
        descriptor = os.open(name, FILE_FLAGS, dir_fd=parent)
        try:
            before = snapshot(os.fstat(descriptor))
            if before != snapshot(information):
                self.warn("changed_during_scan", path, "Git metadata changed while opening it.")
                return None, None
            content = b""
            if limit is not None:
                pieces = []
                remaining = limit + 1
                while remaining:
                    piece = os.read(descriptor, remaining)
                    if not piece:
                        break
                    pieces.append(piece)
                    remaining -= len(piece)
                content = b"".join(pieces)
                if len(content) > limit:
                    self.warn("unsafe_git_metadata", path, "Git configuration exceeds the supported size.")
                    return None, None
            if snapshot(os.fstat(descriptor)) != before:
                self.warn("changed_during_scan", path, "Git metadata changed while reading it.")
            return content, before
        finally:
            os.close(descriptor)

    def git_selection(self):
        executable = shutil.which("git")
        if executable is None:
            self.warn("missing_dependency", self.path, "Git is required to select files in a Git project root.")
            self.status = 69
            return None
        git_path = os.path.join(self.path, ".git")
        git = self.child_directory(self.root, ".git", git_path)
        if git is None:
            return None
        held = [(git, ".git")]
        observed = []
        try:
            for forbidden in ("commondir", "config.worktree"):
                if self.exists(git, forbidden) is not None:
                    self.warn("unsafe_git_metadata", os.path.join(git_path, forbidden), "Redirected or shared Git metadata is unsupported.")
            for name in ("HEAD", "config", "index"):
                content, information = self.read_metadata(git, name, os.path.join(git_path, name), limit=1048576 if name == "config" else None)
                observed.append((git, name, information))
                if name == "HEAD" and information is None:
                    self.warn("unsafe_git_metadata", git_path, "A normal local Git HEAD is required.")
                if name == "config" and content is not None:
                    try:
                        content.decode("utf-8")
                    except UnicodeDecodeError:
                        self.warn("unsafe_git_configuration", os.path.join(git_path, name), "Git configuration must be valid UTF-8.")
                    if (re.search(rb"(?im)^\s*\[\s*include", content.lstrip(b"\xef\xbb\xbf"))
                            or b"\\\n" in content or b"\\\r\n" in content
                            or re.search(rb"(?i)partialclone|promisor|sparsecheckout|worktreeconfig", content)):
                        self.warn("unsafe_git_configuration", os.path.join(git_path, name), "Includes, sparse/partial clones, and worktree configuration are unsupported.")
            with os.scandir(git) as entries:
                shared_indices = sorted(entry.name for entry in entries if entry.name.startswith("sharedindex."))
            for name in shared_indices:
                _content, information = self.read_metadata(git, name, os.path.join(git_path, name), limit=None)
                observed.append((git, name, information))
            for parent, name, relative in ((git, "info", ".git/info"), (git, "objects", ".git/objects")):
                if self.exists(parent, name) is None:
                    if name == "objects":
                        self.warn("unsafe_git_metadata", os.path.join(self.path, relative), "A normal local Git object directory is required.")
                    continue
                child = self.child_directory(parent, name, os.path.join(self.path, relative))
                if child is None:
                    continue
                held.append((child, relative))
                if name == "info":
                    _content, information = self.read_metadata(child, "exclude", os.path.join(self.path, relative, "exclude"), limit=None)
                    observed.append((child, "exclude", information))
                else:
                    for subdirectory in ("info", "pack"):
                        if self.exists(child, subdirectory) is None:
                            continue
                        sub = self.child_directory(child, subdirectory, os.path.join(self.path, relative, subdirectory))
                        if sub is None:
                            continue
                        held.append((sub, relative + "/" + subdirectory))
                        with os.scandir(sub) as entries:
                            metadata_names = [entry.name for entry in entries]
                        if subdirectory == "info" and any(name in metadata_names for name in ("alternates", "http-alternates")):
                            self.warn("unsafe_git_metadata", os.path.join(self.path, relative, subdirectory), "Alternate object storage is unsupported.")
                        if subdirectory == "pack" and any(name.endswith(".promisor") for name in metadata_names):
                            self.warn("unsafe_git_metadata", os.path.join(self.path, relative, subdirectory), "Partial-clone object storage is unsupported.")
            if any(warning["code"] in ("unsafe_git_metadata", "unsafe_git_configuration", "changed_during_scan", "io_error") for warning in self.warnings):
                return None
            environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
            environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_SYSTEM=os.devnull,
                               GIT_CONFIG_GLOBAL=os.devnull, GIT_OPTIONAL_LOCKS="0",
                               GIT_NO_LAZY_FETCH="1", GIT_ALLOW_PROTOCOL="",
                               GIT_TERMINAL_PROMPT="0", GIT_PAGER="cat")
            root_reference = "/dev/fd/" + str(self.root)
            git_reference = "/dev/fd/" + str(git)
            command = [executable, "--no-pager", "--no-optional-locks", "--git-dir=" + git_reference,
                       "--work-tree=" + root_reference, "-c", "core.fsmonitor=false", "-c",
                       "core.untrackedCache=false", "-c", "core.hooksPath=" + os.devnull,
                       "-c", "core.excludesFile=" + os.devnull, "-c", "core.bare=false"]
            completed = subprocess.run(command + ["ls-files", "--cached", "--full-name", "--sparse", "--stage", "-z"],
                                       env=environment, cwd=root_reference, pass_fds=(self.root, git),
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=30)
            if completed.returncode != 0 or completed.stderr:
                self.warn("git_selection_failed", git_path, completed.stderr.decode("utf-8", errors="backslashreplace").strip())
                return None
            tracked = set()
            for entry in completed.stdout.split(b"\0"):
                if not entry:
                    continue
                header, separator, raw_path = entry.partition(b"\t")
                if not separator or header.startswith(b"040000 "):
                    self.warn("unsafe_git_metadata", git_path, "Sparse index entries are unsupported.")
                    return None
                tracked.add(os.fsdecode(raw_path))
            untracked = sorted(set(self.selected) - tracked - self.includes)
            ignored = set()
            if untracked:
                payload = b"".join(os.fsencode(path) + b"\0" for path in untracked)
                completed = subprocess.run(command + ["check-ignore", "--stdin", "-z"], input=payload,
                                           env=environment, cwd=root_reference, pass_fds=(self.root, git),
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=30)
                if completed.returncode not in (0, 1) or completed.stderr:
                    self.warn("git_selection_failed", git_path, completed.stderr.decode("utf-8", errors="backslashreplace").strip())
                    return None
                ignored = {os.fsdecode(path) for path in completed.stdout.split(b"\0") if path}
            selected = {path: "git_tracked" if path in tracked else "git_untracked"
                        for path in self.selected if path not in ignored}
            for parent, name, before in observed:
                current = self.exists(parent, name)
                after = snapshot(current) if current is not None else None
                if after != before:
                    self.warn("changed_during_scan", git_path + "/" + name, "Git metadata changed during file selection.")
            return selected
        finally:
            for descriptor, _path in reversed(held):
                os.close(descriptor)

    def open_selected(self, relative):
        parent = os.dup(self.root)
        try:
            parts = relative.split("/")
            prefix = ""
            for name in parts[:-1]:
                prefix = prefix + "/" + name if prefix else name
                child = os.open(name, DIRECTORY_FLAGS, dir_fd=parent)
                if snapshot(os.fstat(child))[:3] != self.directories[prefix][:3]:
                    os.close(child)
                    raise OSError("The source directory changed after selection: " + prefix)
                os.close(parent)
                parent = child
            descriptor = os.open(parts[-1], FILE_FLAGS, dir_fd=parent)
            if snapshot(os.fstat(descriptor)) != snapshot(self.selected[relative]):
                os.close(descriptor)
                raise OSError("The source file changed after selection: " + relative)
            return descriptor
        finally:
            os.close(parent)

    def publish(self):
        temporary_name = ".mantle-archive-" + secrets.token_hex(16) + ".tmp"
        temporary = None
        try:
            temporary = os.open(temporary_name, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                0o600, dir_fd=self.output_parent)
            with os.fdopen(os.dup(temporary), "wb") as raw:
                with gzip.GzipFile(filename="", mode="wb", fileobj=raw,
                                   mtime=0 if self.options.reproducible else None) as compressed:
                    with tarfile.open(fileobj=compressed, mode="w|", format=tarfile.PAX_FORMAT) as archive:
                        root_member = tarfile.TarInfo("project/")
                        root_member.type = tarfile.DIRTYPE
                        root_member.mode = 0o755
                        root_member.mtime = 0 if self.options.reproducible else int(os.fstat(self.root).st_mtime)
                        archive.addfile(root_member)
                        for item in self.included:
                            relative = item["path"]
                            descriptor = self.open_selected(relative)
                            try:
                                information = self.selected[relative]
                                member = tarfile.TarInfo("project/" + relative)
                                member.size = information.st_size
                                member.mode = 0o755 if information.st_mode & 0o111 else 0o644
                                member.mtime = 0 if self.options.reproducible else int(information.st_mtime)
                                with os.fdopen(os.dup(descriptor), "rb") as source:
                                    archive.addfile(member, source)
                                if snapshot(os.fstat(descriptor)) != snapshot(information):
                                    raise OSError("The source file changed while copying: " + relative)
                            finally:
                                os.close(descriptor)
            os.fsync(temporary)
            os.lseek(temporary, 0, os.SEEK_SET)
            digest = hashlib.sha256()
            while True:
                block = os.read(temporary, 1048576)
                if not block:
                    break
                digest.update(block)
            os.link(temporary_name, self.output_name, src_dir_fd=self.output_parent,
                    dst_dir_fd=self.output_parent, follow_symlinks=False)
            self.sha256 = digest.hexdigest()
        except (OSError, tarfile.TarError) as exception:
            self.error(self.output, exception)
        finally:
            if temporary is not None:
                os.close(temporary)
                try:
                    os.unlink(temporary_name, dir_fd=self.output_parent)
                except OSError as exception:
                    self.error(self.output, exception)

    def run(self):
        try:
            if not SUPPORTED:
                self.warn("unsupported_platform", self.path, "Safe archives require Unix directory descriptors and no-follow support.")
            else:
                self.root = self.open_path(self.options.path)
            if self.root is not None:
                self.prepare_output()
                git_marker = self.exists(self.root, ".git")
                if git_marker is not None:
                    self.selection_mode = "git"
                elif self.nested_repository(self.root):
                    self.warn("unsafe_git_metadata", self.path, "Bare repositories are unsupported archive targets.")
                self.scan(self.root)
                try:
                    git_files = self.git_selection() if self.selection_mode == "git" else {}
                except (OSError, subprocess.TimeoutExpired) as exception:
                    self.error(os.path.join(self.path, ".git"), exception)
                    git_files = None
                for relative in sorted(self.selected):
                    information = self.selected[relative]
                    if relative in self.includes:
                        reason = "explicit_include"
                    elif self.selection_mode == "git" and git_files is None:
                        reason = "git_unverified"
                    elif self.selection_mode == "git" and relative not in git_files:
                        self.exclude(relative, "git_ignored")
                        continue
                    else:
                        reason = git_files.get(relative, "filesystem")
                    self.included.append(dict(path=relative, size_bytes=information.st_size, reason=reason))
                for missing in sorted(self.includes - self.observed_includes):
                    self.warn("include_unavailable", os.path.join(self.path, missing), "The exact include is missing or crosses a structural boundary.")
                if not self.warnings and not self.options.dry_run:
                    self.publish()
        except (OSError, RecursionError, ValueError) as exception:
            self.error(self.path, exception)
        finally:
            if self.output_parent is not None:
                os.close(self.output_parent)
            if self.root is not None:
                os.close(self.root)
        self.excluded.sort(key=lambda item: (item["path"], item["reason"]))
        self.warnings.sort(key=lambda item: (item["path"], item["code"], item["message"]))
        complete = not self.warnings
        if complete:
            self.status = 0
        return dict(schema=SCHEMA, path=self.path, output=self.output, selection_mode=self.selection_mode,
                    dry_run=self.options.dry_run, reproducible=self.options.reproducible,
                    complete=complete, included=self.included, excluded=self.excluded,
                    warnings=self.warnings, sha256=self.sha256,
                    totals=dict(files=len(self.included), bytes=sum(item["size_bytes"] for item in self.included)))


def human_output(result):
    print("Mantle archive " + ("preview: " if result["dry_run"] else ": ") + json.dumps(result["path"], ensure_ascii=True))
    print("Status: " + ("complete" if result["complete"] else "failed"))
    if result["output"] is not None:
        print("Output: " + json.dumps(result["output"], ensure_ascii=True))
    for item in result["included"]:
        print("Include " + json.dumps(item["path"], ensure_ascii=True) + ": " + str(item["size_bytes"]) + " bytes (" + item["reason"] + ")")
    for item in result["excluded"]:
        print("Exclude " + json.dumps(item["path"], ensure_ascii=True) + " (" + item["reason"] + ")")
    print("Totals: " + str(result["totals"]["files"]) + " files, " + str(result["totals"]["bytes"]) + " bytes")
    if result["sha256"] is not None:
        print("SHA-256: " + result["sha256"])
    for warning in result["warnings"]:
        print("Warning " + warning["code"] + " " + json.dumps(warning["path"], ensure_ascii=True)
              + ": " + json.dumps(warning["message"], ensure_ascii=True))


def main():
    options = arguments()
    operation = Archive(options)
    result = operation.run()
    print(json.dumps(result, ensure_ascii=True, sort_keys=True)) if options.json else human_output(result)
    return operation.status


if __name__ == "__main__":
    sys.exit(main())
