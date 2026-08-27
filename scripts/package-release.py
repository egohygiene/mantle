#!/usr/bin/env python3
"""Build Mantle's deterministic source-distribution archive.

The release workflow calls this script from an annotated, immutable Git tag.
It deliberately packages tracked source only, assigns stable archive metadata,
and replaces VERSION with the requested release version.
"""

from __future__ import annotations

import argparse
import gzip
import io
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import tarfile
import tempfile


VERSION_PATTERN = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a deterministic Mantle source-distribution archive."
    )
    parser.add_argument(
        "--version",
        required=True,
        help="Exact semantic version to embed in the archive, without a leading v.",
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        type=Path,
        help="Directory that will receive mantle-VERSION.tar.gz.",
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Mantle Git working tree (defaults to this script's repository root).",
    )
    parser.add_argument(
        "--include-worktree",
        action="store_true",
        help="Include untracked, non-ignored source files for local validation only.",
    )
    return parser.parse_args()


def run_git(source_dir: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(source_dir), *arguments],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown Git error"
        raise RuntimeError(f"Git command failed: {' '.join(arguments)}: {detail}")
    return result.stdout


def require_clean_tracked_worktree(source_dir: Path) -> None:
    status = run_git(source_dir, "status", "--porcelain", "--untracked-files=no")
    if status.strip():
        raise RuntimeError(
            "refusing to package modified tracked source; commit the release candidate first"
        )


def tracked_files(source_dir: Path, include_worktree: bool) -> list[Path]:
    arguments = ["ls-files", "-z", "--cached"]
    if include_worktree:
        arguments.extend(["--others", "--exclude-standard"])

    raw_paths = run_git(source_dir, *arguments)
    files: set[Path] = set()
    for raw_path in raw_paths.split("\0"):
        if not raw_path:
            continue
        relative_path = Path(raw_path)
        if relative_path.is_absolute() or ".git" in relative_path.parts:
            raise RuntimeError(f"unsafe source path reported by Git: {raw_path}")
        source_path = source_dir / relative_path
        if not source_path.is_file() and not source_path.is_symlink():
            raise RuntimeError(f"tracked source path is missing or not a file: {raw_path}")
        files.add(relative_path)

    if not files:
        raise RuntimeError("no source files were selected for the release archive")
    return sorted(files, key=lambda path: path.as_posix())


def add_directory(archive: tarfile.TarFile, name: str, source_date_epoch: int) -> None:
    entry = tarfile.TarInfo(name)
    entry.type = tarfile.DIRTYPE
    entry.mode = 0o755
    entry.uid = 0
    entry.gid = 0
    entry.uname = ""
    entry.gname = ""
    entry.mtime = source_date_epoch
    archive.addfile(entry)


def add_bytes(
    archive: tarfile.TarFile, name: str, contents: bytes, source_date_epoch: int
) -> None:
    entry = tarfile.TarInfo(name)
    entry.mode = 0o644
    entry.uid = 0
    entry.gid = 0
    entry.uname = ""
    entry.gname = ""
    entry.mtime = source_date_epoch
    entry.size = len(contents)
    archive.addfile(entry, io.BytesIO(contents))


def add_source_file(
    archive: tarfile.TarFile,
    source_path: Path,
    archive_path: str,
    source_date_epoch: int,
) -> None:
    source_stat = source_path.lstat()
    entry = tarfile.TarInfo(archive_path)
    entry.uid = 0
    entry.gid = 0
    entry.uname = ""
    entry.gname = ""
    entry.mtime = source_date_epoch

    if stat.S_ISLNK(source_stat.st_mode):
        entry.type = tarfile.SYMTYPE
        entry.mode = 0o777
        entry.linkname = os.readlink(source_path)
        archive.addfile(entry)
        return

    if not stat.S_ISREG(source_stat.st_mode):
        raise RuntimeError(f"unsupported source file type: {source_path}")

    entry.mode = 0o755 if source_stat.st_mode & 0o111 else 0o644
    entry.size = source_stat.st_size
    with source_path.open("rb") as source_file:
        archive.addfile(entry, source_file)


def build_archive(
    source_dir: Path,
    output_dir: Path,
    version: str,
    include_worktree: bool,
) -> tuple[Path, str, int]:
    source_dir = source_dir.resolve()
    output_dir = output_dir.resolve()
    if not (source_dir / ".git").exists():
        raise RuntimeError(f"source directory is not a Git working tree: {source_dir}")
    if not include_worktree:
        require_clean_tracked_worktree(source_dir)

    revision = run_git(source_dir, "rev-parse", "HEAD").strip()
    source_date_epoch = int(run_git(source_dir, "show", "-s", "--format=%ct", "HEAD").strip())
    files = tracked_files(source_dir, include_worktree)
    output_dir.mkdir(parents=True, exist_ok=True)

    archive_name = f"mantle-{version}.tar.gz"
    archive_path = output_dir / archive_name
    archive_root = f"mantle-{version}"
    release_metadata = {
        "schema": "egohygiene.mantle.release/v1",
        "version": version,
        "revision": revision,
        "source_date_epoch": source_date_epoch,
    }

    directory_names = {archive_root}
    for relative_path in files:
        parent = relative_path.parent
        while parent != Path("."):
            directory_names.add(f"{archive_root}/{parent.as_posix()}")
            parent = parent.parent

    temporary_handle = tempfile.NamedTemporaryFile(
        mode="wb", prefix=f".{archive_name}.", suffix=".tmp", dir=output_dir, delete=False
    )
    temporary_path = Path(temporary_handle.name)
    try:
        with temporary_handle:
            with gzip.GzipFile(
                filename="", mode="wb", fileobj=temporary_handle, mtime=source_date_epoch, compresslevel=9
            ) as compressed:
                with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
                    for directory_name in sorted(directory_names):
                        add_directory(archive, directory_name, source_date_epoch)
                    for relative_path in files:
                        archive_path_name = f"{archive_root}/{relative_path.as_posix()}"
                        if relative_path.as_posix() == "VERSION":
                            continue
                        add_source_file(
                            archive,
                            source_dir / relative_path,
                            archive_path_name,
                            source_date_epoch,
                        )
                    add_bytes(
                        archive,
                        f"{archive_root}/VERSION",
                        f"{version}\n".encode("utf-8"),
                        source_date_epoch,
                    )
                    add_bytes(
                        archive,
                        f"{archive_root}/RELEASE-METADATA.json",
                        (json.dumps(release_metadata, indent=2, sort_keys=True) + "\n").encode("utf-8"),
                        source_date_epoch,
                    )
        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, archive_path)
    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise

    return archive_path, revision, source_date_epoch


def main() -> int:
    arguments = parse_args()
    if not VERSION_PATTERN.fullmatch(arguments.version):
        raise SystemExit("error: --version must be a semantic version without a leading v")

    try:
        archive_path, revision, source_date_epoch = build_archive(
            arguments.source_dir,
            arguments.output_dir,
            arguments.version,
            arguments.include_worktree,
        )
    except RuntimeError as error:
        raise SystemExit(f"error: {error}") from error

    print(f"archive: {archive_path}")
    print(f"version: {arguments.version}")
    print(f"revision: {revision}")
    print(f"source-date-epoch: {source_date_epoch}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
