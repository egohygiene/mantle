# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
"""Mantle-owned local release planning and source-bundle evidence; never publish.

Aether owns declaration grammar, Relay owns remote immutable verification.
This helper checks Mantle's local preparation and records evidence availability.
It does not authenticate a default branch, signature, attestation or installation.
Python is on demand for release tooling, never shell startup.
"""
from __future__ import annotations

import argparse
from datetime import date
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = re.compile(r"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
SHA = re.compile(r"^[0-9a-f]{40}$")
IDENTITY = "https://github.com/egohygiene/mantle/.github/workflows/release.yml@refs/heads/main"


def git(root: Path, *arguments: str) -> str:
    result = subprocess.run(["git", "-C", str(root), *arguments], check=True, capture_output=True, text=True)
    return result.stdout.strip()


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("release input must be a JSON object")
    return value


def write_json(path: Path, value: dict) -> None:
    with path.open("x", encoding="utf-8") as handle:
        handle.write(json.dumps(value, indent=2, sort_keys=True) + "\n")


def changelog(root: Path, version: str, promoted: bool) -> str:
    text = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    if not text.startswith("# Changelog\n") or len(re.findall(r"^## \[Unreleased\]\s*$", text, re.M)) != 1:
        raise ValueError("changelog needs one exact Unreleased heading")
    target = version[1:]
    headers = re.findall(r"^## \[" + re.escape(target) + r"\] - (\d{4}-\d{2}-\d{2})\s*$", text, re.M)
    if promoted:
        if len(headers) != 1:
            raise ValueError("verify requires one reviewed dated changelog promotion")
        date.fromisoformat(headers[0])
    elif headers:
        raise ValueError("plan/prepare require an unpromoted target version")
    else:
        section = re.split(r"^## \[Unreleased\]\s*$", text, flags=re.M)[1]
        section = re.split(r"^## \[", section, maxsplit=1, flags=re.M)[0]
        if not re.search(r"^[-*] \S", section, re.M):
            raise ValueError("Unreleased has no reviewable change entries")
    return text


def plan(arguments: argparse.Namespace) -> dict:
    version = arguments.version
    if not VERSION.fullmatch(version):
        raise ValueError("version must be exact stable vMAJOR.MINOR.PATCH")
    declaration = read_object(arguments.repository / ".egohygiene/release.json")
    expected = [{"id": "mantle", "kind": "repository", "version_authority": {"kind": "git-tag"}}]
    if declaration.get("components") != expected or declaration.get("repository", {}).get("id") != "egohygiene/mantle":
        raise ValueError("Mantle requires its sole git-tag component authority")
    if declaration.get("release", {}).get("immutable_tags") is not True:
        raise ValueError("immutable tags are required")
    changelog(arguments.repository, version, arguments.command == "verify")
    revision = git(arguments.repository, "rev-parse", "HEAD")
    if arguments.source_revision and (not SHA.fullmatch(arguments.source_revision) or arguments.source_revision != revision):
        raise ValueError("requested source revision differs from the checkout")
    if arguments.command == "verify" and git(arguments.repository, "status", "--porcelain", "--untracked-files=no"):
        raise ValueError("verify requires a committed clean tracked source candidate")
    return {
        "schema": "egohygiene.mantle.release-preparation/v1",
        "repository": "egohygiene/mantle", "tag": version, "source_revision": revision,
        "authority": "git-tag", "source_archive": f"mantle-{version[1:]}.tar.gz",
        "relay_archive": f"binary-{version}.tar.gz", "profile": "binary",
        "source_preparation": "verified-local" if arguments.command == "verify" else "planned-local",
        "default_branch": "not-authenticated-locally", "signature": "unavailable-locally",
        "publication": "not-performed", "review_required": True,
    }


def evidence(arguments: argparse.Namespace) -> dict:
    """Write a complete source bundle, recording files without claiming crypto verification."""
    if not VERSION.fullmatch(arguments.version) or not SHA.fullmatch(arguments.source_revision or ""):
        raise ValueError("evidence requires an exact stable tag and full source revision")
    archive = arguments.archive
    if not archive or not archive.is_file() or archive.is_symlink() or archive.name != f"mantle-{arguments.version[1:]}.tar.gz":
        raise ValueError("evidence requires the exact regular Mantle source archive")
    output = arguments.output_dir
    if not output:
        raise ValueError("evidence requires an explicit output directory")
    output.mkdir(parents=True, exist_ok=False)
    try:
        files = []
        with tarfile.open(archive, "r:gz") as payload:
            receipts = [member for member in payload.getmembers() if member.name == f"mantle-{arguments.version[1:]}/RELEASE-METADATA.json"]
            if len(receipts) != 1 or not receipts[0].isfile():
                raise ValueError("archive requires exactly one generated release receipt")
            receipt = json.load(payload.extractfile(receipts[0]))
            if not isinstance(receipt, dict):
                raise ValueError("archive receipt must be an object")
            if receipt.get("revision") != arguments.source_revision or receipt.get("tag") != arguments.version or receipt.get("source_state") != "clean-commit":
                raise ValueError("source archive does not bind the clean reviewed tag and revision")
            for member in payload.getmembers():
                if member.isfile():
                    data = payload.extractfile(member).read()
                    files.append({"fileName": member.name, "SPDXID": f"SPDXRef-File-{len(files)}", "checksums": [{"algorithm": "SHA256", "checksumValue": hashlib.sha256(data).hexdigest()}], "licenseConcluded": "NOASSERTION", "licenseInfoInFiles": ["NOASSERTION"], "copyrightText": "NOASSERTION"})
        shutil.copyfile(archive, output / archive.name)
        bundles = {}
        for label, path, name in [
            ("signature", arguments.signature_bundle, f"{archive.name}.sigstore.json"),
            ("attestation", arguments.attestation_bundle, "attestation.sigstore.json"),
        ]:
            if path:
                if not path.is_file() or path.is_symlink() or path.stat().st_size == 0:
                    raise ValueError(f"{label} bundle must be a nonempty regular file")
                shutil.copyfile(path, output / name)
                bundles[label] = name
        write_json(output / "provenance.json", {
            "schema": "egohygiene.mantle.source-provenance/v1", "repository": "egohygiene/mantle",
            "source_revision": arguments.source_revision, "tag": arguments.version,
            "archive": archive.name, "archive_sha256": digest(archive),
            "attestation_bundle": bundles.get("attestation"),
            "attestation_state": "recorded" if "attestation" in bundles else "unavailable",
            "verification": "not-performed-by-evidence-writer",
        })
        write_json(output / "signature.json", {
            "schema": "egohygiene.mantle.signature-status/v1",
            "state": "recorded" if "signature" in bundles else "unavailable",
            "bundle": bundles.get("signature"), "certificate_identity": IDENTITY,
            "oidc_issuer": "https://token.actions.githubusercontent.com",
            "verification": "not-performed-by-evidence-writer",
        })
        write_json(output / "sbom.spdx.json", {
            "spdxVersion": "SPDX-2.3", "dataLicense": "CC0-1.0", "SPDXID": "SPDXRef-DOCUMENT",
            "name": f"mantle-{arguments.version}",
            "documentNamespace": f"https://github.com/egohygiene/mantle/sbom/{arguments.source_revision}",
            "creationInfo": {"created": "1970-01-01T00:00:00Z", "creators": ["Tool: mantle-release-control"]},
            "documentDescribes": [item["SPDXID"] for item in files],
            "files": files, "comment": "Source-file checksum inventory; external runtime tools are not bundled or dependency-certified.",
        })
        if arguments.qualification:
            if not arguments.qualification.is_file() or arguments.qualification.is_symlink():
                raise ValueError("qualification receipt must be a regular file")
            shutil.copyfile(arguments.qualification, output / "qualification.json")
        sums = "".join(f"{digest(path)}  {path.name}\n" for path in sorted(output.iterdir()))
        (output / "SHA256SUMS").write_text(sums, encoding="utf-8")
    except Exception:
        shutil.rmtree(output)
        raise
    return {"source_revision": arguments.source_revision, "tag": arguments.version, "signature": "recorded-not-verified" if "signature" in bundles else "unavailable", "publication": "not-performed"}


def qualification(arguments: argparse.Namespace) -> dict:
    """Validate supplied GitHub observations; the workflow owns API authentication."""
    if not SHA.fullmatch(arguments.source_revision or "") or not arguments.runs_file:
        raise ValueError("qualification requires source revision and supplied run observations")
    observations = read_object(arguments.runs_file)
    runs = observations.get("workflow_runs", [])
    if not isinstance(runs, list):
        raise ValueError("qualification workflow_runs must be an array")
    matching = [run for run in runs if isinstance(run, dict)
                and run.get("head_sha") == arguments.source_revision
                and run.get("head_branch") == "main"
                and run.get("path") == ".github/workflows/test.yml"
                and run.get("event") == "workflow_dispatch"
                and run.get("status") == "completed" and run.get("conclusion") == "success"
                and type(run.get("id")) is int and run["id"] > 0]
    if not matching:
        raise ValueError("a successful manually qualified current-main Test Suite run is required")
    run = max(matching, key=lambda item: item.get("id", 0))
    if not isinstance(run.get("id"), int) or run["id"] <= 0:
        raise ValueError("qualification run identity is malformed")
    if not arguments.jobs_file:
        return {"run_id": run["id"], "source_revision": arguments.source_revision}
    jobs = read_object(arguments.jobs_file).get("jobs", [])
    if not isinstance(jobs, list):
        raise ValueError("qualification jobs must be an array")
    required = ["Static Validation", "Tests (Linux)", "Tests (macOS)"]
    for name in required:
        matching_jobs = [job for job in jobs if isinstance(job, dict) and job.get("name") == name]
        if len(matching_jobs) != 1:
            raise ValueError(f"qualification requires one exact-source job: {name}")
        job = matching_jobs[0]
        if (
            job.get("status") != "completed"
            or job.get("conclusion") != "success"
            or type(job.get("run_id")) is not int
            or job.get("run_id") != run["id"]
            or job.get("head_sha") != arguments.source_revision
        ):
            raise ValueError(f"qualification requires successful exact-source job: {name}")
    return {"schema": "egohygiene.mantle.platform-qualification/v1", "run_id": run["id"],
            "source_revision": arguments.source_revision, "jobs": required,
            "authentication": "caller-owned-github-api", "publication": "not-performed"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["plan", "prepare", "verify", "evidence", "qualification"])
    parser.add_argument("--repository", type=Path, default=ROOT)
    parser.add_argument("--version", required=True)
    parser.add_argument("--source-revision")
    parser.add_argument("--date")
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--runs-file", type=Path)
    parser.add_argument("--jobs-file", type=Path)
    parser.add_argument("--qualification", type=Path)
    parser.add_argument("--signature-bundle", type=Path)
    parser.add_argument("--attestation-bundle", type=Path)
    arguments = parser.parse_args()
    try:
        if not VERSION.fullmatch(arguments.version):
            raise ValueError("version must be exact stable vMAJOR.MINOR.PATCH")
        if arguments.command == "qualification":
            result = qualification(arguments)
        elif arguments.command == "evidence":
            result = evidence(arguments)
        else:
            result = plan(arguments)
            if arguments.command == "prepare":
                if not arguments.date:
                    raise ValueError("prepare requires a reviewed --date YYYY-MM-DD")
                if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", arguments.date):
                    raise ValueError("prepare date must use YYYY-MM-DD")
                date.fromisoformat(arguments.date)
                text = changelog(arguments.repository, arguments.version, False)
                proposed = text.replace("## [Unreleased]", f"## [Unreleased]\n\n## [{arguments.version[1:]}] - {arguments.date}", 1)
                print("".join(difflib.unified_diff(text.splitlines(keepends=True), proposed.splitlines(keepends=True), fromfile="a/CHANGELOG.md", tofile="b/CHANGELOG.md")), end="")
                return 0
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (ValueError, OSError, subprocess.SubprocessError, tarfile.TarError) as error:
        parser.exit(1, f"release preparation failed: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
