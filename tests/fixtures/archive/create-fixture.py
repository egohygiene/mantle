#!/usr/bin/env python3
"""Generate small, disposable project archives with real filesystem boundaries."""

import argparse
import json
import os
from pathlib import Path
import subprocess


def git(project, *arguments):
    subprocess.run(
        ["git", "-C", str(project), "-c", "core.hooksPath=/dev/null", *arguments],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--git", action="store_true")
    arguments = parser.parse_args()
    root = arguments.destination
    project = root / "project"
    project.mkdir(parents=True)
    files = {
        "README.md": b"Project archive fixture.\n",
        "source.py": b"print(\"fixture\")\n",
        "script.sh": b"#!/bin/sh\nprintf \"fixture\\n\"\n",
        "notes.txt": b"untracked user work\n",
        "line\nbreak\x1b[31m.txt": b"unusual names remain data\n",
        "node_modules/dependency/index.js": b"generated dependency\n",
        "build/generated.txt": b"generated build\n",
        ".venv/cache.txt": b"local environment\n",
        ".env": b"SECRET=fixture-only\n",
        ".env.production": b"SECRET=tracked-fixture-only\n",
        "custom-local.txt": b"custom Git ignore rule\n",
        "ignored-but-tracked.txt": b"tracked despite later ignore rule\n",
    }
    for relative_path, content in files.items():
        path = project / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    (project / "script.sh").chmod(0o755)
    os.link(project / "source.py", project / "source-alias.py")
    outside = root / "outside"
    outside.mkdir()
    (outside / "secret.txt").write_bytes(b"must never enter the archive\n")
    os.symlink(outside, project / "outside-directory")
    os.symlink(outside / "secret.txt", project / "outside-file")
    os.symlink(outside / "missing", project / "broken-link")
    os.mkfifo(project / "named-pipe")
    (project / "embedded" / ".git").mkdir(parents=True)
    (project / "embedded" / "nested.txt").write_bytes(b"nested repository data\n")
    if arguments.git:
        git(project, "init", "--quiet")
        git(project, "add", "--", "README.md", "source.py", "script.sh", ".env.production", "ignored-but-tracked.txt")
        (project / ".gitignore").write_text("custom-local.txt\nignored-but-tracked.txt\n", encoding="utf-8")
        git(project, "add", "--", ".gitignore")
    manifest = {
        "project": str(project),
        "sizes": {name: len(content) for name, content in files.items()},
        "control_filename": "line\nbreak\x1b[31m.txt",
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
