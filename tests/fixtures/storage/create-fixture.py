#!/usr/bin/env python3
"""Generate disposable storage fixtures; never commit large or opaque binaries."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess


def sparse_file(path, size):
    """Create a large logical file without allocating its contents."""
    with path.open("wb") as stream:
        stream.truncate(size)


def filesystem_fixture(root):
    directory = root / "directory"
    directory.mkdir()
    (directory / "nested").mkdir()
    (directory / "empty").mkdir()
    files = {
        "small.txt": b"small fixture\n",
        "nested/payload.bin": b"n" * 4096,
        "large.bin": b"L" * (2 * 1024 * 1024),
        "line\nbreak\x1b[31m.txt": b"control characters stay data\n",
    }
    for relative_path, payload in files.items():
        (directory / relative_path).write_bytes(payload)
    os.link(directory / "large.bin", directory / "large-hardlink.bin")
    sparse_size = 32 * 1024 * 1024
    sparse_file(directory / "sparse.bin", sparse_size)
    outside = root / "outside"
    outside.mkdir()
    sparse_file(outside / "must-not-be-counted.bin", 256 * 1024 * 1024)
    os.symlink(outside, directory / "outside-directory")
    os.symlink(outside / "must-not-be-counted.bin", directory / "outside-file")
    os.symlink(outside / "missing", directory / "broken-link")
    return {
        "apparent_bytes": sum(map(len, files.values())) + sparse_size,
        "files": len(files) + 1,
        "directories": 3,
        "hardlinks": 1,
        "symlinks": 3,
        "sparse_size": sparse_size,
        "control_filename": "line\nbreak\x1b[31m.txt",
    }


def git(repository, *arguments):
    """Run local Git without hooks, user identity, or signing dependencies."""
    subprocess.run(
        [
            "git", "-C", str(repository),
            "-c", "user.name=Mantle Storage Fixture",
            "-c", "user.email=storage@mantle.invalid",
            "-c", "commit.gpgSign=false",
            "-c", "core.hooksPath=/dev/null",
            *arguments,
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def repository_fixture(root):
    repository = root / "repository"
    repository.mkdir()
    git(repository, "init", "--quiet")
    (repository / "README.md").write_text("Storage fixture repository.\n", encoding="utf-8")
    generator = random.Random(18)
    historical_bytes = bytes(generator.randrange(256) for _ in range(128 * 1024))
    (repository / "historical.bin").write_bytes(historical_bytes)
    git(repository, "add", "--all")
    git(repository, "commit", "--quiet", "--message=historical binary")
    git(repository, "rm", "--quiet", "historical.bin")
    lfs_payload = b"lfs cache payload\n" * (64 * 1024)
    oid = hashlib.sha256(lfs_payload).hexdigest()
    pointer = (
        "version https://git-lfs.github.com/spec/v1\n"
        f"oid sha256:{oid}\n"
        f"size {len(lfs_payload)}\n"
    )
    (repository / "asset.lfs").write_text(pointer, encoding="ascii")
    git(repository, "add", "--all")
    git(repository, "commit", "--quiet", "--message=LFS pointer")
    lfs_path = repository / ".git" / "lfs" / "objects" / oid[:2] / oid[2:4] / oid
    lfs_path.parent.mkdir(parents=True)
    lfs_path.write_bytes(lfs_payload)
    return {"lfs_bytes": len(lfs_payload), "lfs_oid": oid, "historical_bytes": len(historical_bytes)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--repository", action="store_true")
    arguments = parser.parse_args()
    arguments.destination.mkdir(parents=True, exist_ok=True)
    manifest = {"directory": filesystem_fixture(arguments.destination)}
    if arguments.repository:
        manifest["repository"] = repository_fixture(arguments.destination)
    (arguments.destination / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
