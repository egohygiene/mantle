#!/usr/bin/env python3
"""Read and validate Mantle's runtime profiles and public command catalog.

This optional, standard-library developer CLI never runs during shell startup.
Catalog applicability describes useful commands; it does not restrict dispatch
or install dependencies. Unknown legacy requirements remain explicitly unknown.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
from typing import Any


SCHEMA_VERSION = 1
PROFILE_NAMES = ("core", "interactive", "workstation", "container", "ci", "full")
CAPABILITIES = frozenset(("core", "interactive", "tooling", "workstation", "container", "ci"))
CATEGORIES = frozenset(("core", "development", "files", "media", "network", "security", "system", "legacy"))
PLATFORMS = frozenset(("darwin", "linux", "windows"))
COMMAND_FIELDS = frozenset(("id", "path", "category", "profiles", "platforms", "dependencies", "network", "privilege", "review_status"))
COMMAND_NAME = re.compile(r"[a-z0-9][a-z0-9-]*\Z")
DEPENDENCY_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+<>=:-]*\Z")


class MetadataError(Exception):
    """The installed metadata is invalid or incomplete."""


class UsageParser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        self.print_usage(sys.stderr)
        self.exit(64, f"[mantle:error] {message}\n")


def unique_strings(value: Any, field: str, allowed: Any = None) -> list[str]:
    if not isinstance(value, list) or not value:
        raise MetadataError(f"{field} must be a nonempty list")
    if any(not isinstance(item, str) or not item for item in value):
        raise MetadataError(f"{field} must contain nonempty strings")
    if len(set(value)) != len(value):
        raise MetadataError(f"{field} contains duplicate values")
    if allowed is not None and any(item not in allowed for item in value):
        raise MetadataError(f"{field} contains an unknown value")
    return value


def profile_tokens(value: str, field: str, allowed: Any) -> list[str]:
    if value == "-":
        return []
    return unique_strings(value.split(":"), field, allowed)


def load_profiles(root: Path) -> list[dict[str, Any]]:
    profile_path = root / "config/profiles.tsv"
    try:
        # newline="" preserves carriage returns so the trusted TSV format has
        # exactly the same strict LF contract as the shell runtime parser.
        with profile_path.open(encoding="utf-8", newline="") as source:
            lines = source.read().split("\n")
    except (OSError, UnicodeError) as error:
        raise MetadataError(f"cannot read profile metadata: {error}") from error
    if lines and lines[-1] == "":
        lines.pop()
    if not lines or lines.pop(0) != "profile\tparents\tcapabilities":
        raise MetadataError("profiles.tsv requires the exact profile/parents/capabilities TSV header")
    profiles: dict[str, dict[str, Any]] = {}
    if len(lines) != len(PROFILE_NAMES):
        raise MetadataError("profiles.tsv must define exactly the six supported profiles")
    for line_number, line in enumerate(lines, start=2):
        fields = line.split("\t")
        if len(fields) != 3:
            raise MetadataError(f"profiles.tsv line {line_number} must contain exactly three fields")
        name, parents, capabilities = fields
        if name not in PROFILE_NAMES or name in profiles:
            raise MetadataError(f"profiles.tsv has an unknown or duplicate profile: {name}")
        profiles[name] = {
            "name": name,
            "parents": profile_tokens(parents, f"{name}.parents", PROFILE_NAMES),
            "capabilities": profile_tokens(capabilities, f"{name}.capabilities", CAPABILITIES),
        }
    if set(profiles) != set(PROFILE_NAMES):
        raise MetadataError("profiles.tsv does not define all supported profiles")

    def resolve(name: str, visiting: set[str]) -> tuple[list[str], list[str]]:
        if name in visiting:
            raise MetadataError(f"profile inheritance contains a cycle at {name}")
        profile = profiles[name]
        if "resolved_profiles" in profile:
            return profile["resolved_profiles"], profile["resolved_capabilities"]
        inherited_profiles: list[str] = []
        inherited_capabilities: list[str] = []
        for parent in profile["parents"]:
            if parent not in profiles:
                raise MetadataError(f"profile {name} has an unknown parent: {parent}")
            parent_profiles, parent_capabilities = resolve(parent, visiting | {name})
            inherited_profiles.extend(item for item in parent_profiles if item not in inherited_profiles)
            inherited_capabilities.extend(item for item in parent_capabilities if item not in inherited_capabilities)
        inherited_profiles.append(name)
        inherited_capabilities.extend(item for item in profile["capabilities"] if item not in inherited_capabilities)
        profile["resolved_profiles"] = inherited_profiles
        profile["resolved_capabilities"] = inherited_capabilities
        return inherited_profiles, inherited_capabilities

    for name in PROFILE_NAMES:
        resolve(name, set())
    return [profiles[name] for name in PROFILE_NAMES]


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise MetadataError(f"command catalog contains a duplicate JSON key: {key}")
        result[key] = value
    return result


def executable_inventory(root: Path) -> dict[str, str]:
    """Discover public entry points without executing them or probing a host."""
    inventory: dict[str, str] = {}
    for path in sorted((root / "bin").iterdir()):
        if path.is_file() and os.access(path, os.X_OK):
            inventory[path.name] = path.relative_to(root).as_posix()
    for path in sorted((root / "libexec/mantle/commands").glob("*.sh")):
        if path.is_file() and os.access(path, os.X_OK):
            inventory[f"mantle {path.stem}"] = path.relative_to(root).as_posix()
    return inventory


def load_catalog(root: Path, profiles: list[dict[str, Any]]) -> list[dict[str, Any]]:
    catalog_path = root / "config/commands.json"
    try:
        document = json.loads(catalog_path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_keys)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise MetadataError(f"cannot read command catalog: {error}") from error
    if not isinstance(document, dict) or set(document) != {"schema_version", "commands"}:
        raise MetadataError("command catalog requires schema_version and commands fields")
    if type(document["schema_version"]) is not int or document["schema_version"] != SCHEMA_VERSION:
        raise MetadataError("unsupported command catalog schema_version")
    commands = document["commands"]
    if not isinstance(commands, list) or not commands:
        raise MetadataError("command catalog commands must be a nonempty list")
    supported_profiles = {profile["name"] for profile in profiles}
    inventory = executable_inventory(root)
    seen: set[str] = set()
    seen_paths: set[str] = set()
    for index, command in enumerate(commands):
        if not isinstance(command, dict) or set(command) != COMMAND_FIELDS:
            raise MetadataError(f"command catalog entry {index} has missing or unknown fields")
        identifier = command["id"]
        if not isinstance(identifier, str):
            raise MetadataError(f"command catalog entry {index} has an invalid id")
        name = identifier.removeprefix("mantle ")
        if not COMMAND_NAME.fullmatch(name) or identifier in seen:
            raise MetadataError(f"invalid or duplicate command id: {identifier}")
        seen.add(identifier)
        relative_path = command["path"]
        if not isinstance(relative_path, str) or not relative_path:
            raise MetadataError(f"{identifier}.path must be a relative executable path")
        parsed_path = PurePosixPath(relative_path)
        if parsed_path.is_absolute() or any(part in ("", ".", "..") for part in relative_path.split("/")) or "\\" in relative_path:
            raise MetadataError(f"{identifier}.path is unsafe")
        if relative_path in seen_paths:
            raise MetadataError(f"duplicate command path: {relative_path}")
        seen_paths.add(relative_path)
        command_path = root / relative_path
        try:
            # Installation directories may themselves be development symlinks.
            # The expected public inventory path remains the authority below.
            command_path.resolve(strict=True)
        except (OSError, RuntimeError) as error:
            raise MetadataError(f"{identifier}.path does not exist: {relative_path}") from error
        if inventory.get(identifier) != relative_path or not command_path.is_file() or not os.access(command_path, os.X_OK):
            raise MetadataError(f"{identifier}.path is stale, nonexecutable, or not its public entry point: {relative_path}")
        if not isinstance(command["category"], str) or command["category"] not in CATEGORIES:
            raise MetadataError(f"{identifier}.category is unknown")
        unique_strings(command["profiles"], f"{identifier}.profiles", supported_profiles)
        if command["platforms"] is not None:
            unique_strings(command["platforms"], f"{identifier}.platforms", PLATFORMS)
        dependencies = command["dependencies"]
        if dependencies is not None:
            if not isinstance(dependencies, list) or any(not isinstance(item, str) or not DEPENDENCY_NAME.fullmatch(item) for item in dependencies) or len(set(dependencies)) != len(dependencies):
                raise MetadataError(f"{identifier}.dependencies must be null or unique dependency names")
        if command["network"] is not None and type(command["network"]) is not bool:
            raise MetadataError(f"{identifier}.network must be null or boolean")
        if command["privilege"] not in (None, "none", "elevated"):
            raise MetadataError(f"{identifier}.privilege must be null, none, or elevated")
        if command["review_status"] not in ("reviewed", "unreviewed"):
            raise MetadataError(f"{identifier}.review_status is unknown")
    uncovered = sorted(set(inventory) - seen)
    if uncovered:
        raise MetadataError(f"public commands missing from catalog: {', '.join(uncovered)}")
    return sorted(commands, key=lambda command: command["id"])


def parse_args(arguments: list[str]) -> argparse.Namespace:
    parser = UsageParser(description=__doc__)
    groups = parser.add_subparsers(dest="group", required=True, parser_class=UsageParser)
    profiles = groups.add_parser("profiles", help="Inspect validated runtime profile inheritance.")
    profile_actions = profiles.add_subparsers(dest="action", required=True, parser_class=UsageParser)
    for action in ("list", "show", "validate"):
        command = profile_actions.add_parser(action)
        if action == "show":
            command.add_argument("name", choices=PROFILE_NAMES)
        command.add_argument("--json", action="store_true", help="Print normalized machine-readable JSON.")
    catalog = groups.add_parser("catalog", help="Inspect validated command applicability metadata.")
    catalog_actions = catalog.add_subparsers(dest="action", required=True, parser_class=UsageParser)
    for action in ("list", "validate"):
        command = catalog_actions.add_parser(action)
        if action == "list":
            command.add_argument("--profile", choices=PROFILE_NAMES, help="Include commands recommended for this profile's inheritance closure.")
        command.add_argument("--json", action="store_true", help="Print normalized machine-readable JSON.")
    return parser.parse_args(arguments)


def display(result: dict[str, Any], arguments: argparse.Namespace) -> None:
    if arguments.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    elif arguments.action == "validate":
        count_key = "profiles" if arguments.group == "profiles" else "commands"
        print(f"Validated {result[count_key]} {count_key} (schema {SCHEMA_VERSION}).")
    elif arguments.group == "profiles":
        profiles = result.get("profiles", [result.get("profile")])
        for profile in profiles:
            print(f"{profile['name']}: parents={','.join(profile['parents']) or '-'} capabilities={','.join(profile['resolved_capabilities']) or '-'}")
    else:
        print("ID\tCATEGORY\tPROFILES\tPLATFORMS\tREVIEW")
        for command in result["commands"]:
            print("\t".join((command["id"], command["category"], ",".join(command["profiles"]), ",".join(command["platforms"]) if command["platforms"] else "unknown", command["review_status"])))


def main(arguments: list[str]) -> int:
    if sys.version_info < (3, 9):
        print("[mantle:error] metadata commands require Python 3.9 or newer.", file=sys.stderr)
        return 69
    parsed = parse_args(arguments)
    configured_root = os.environ.get("MANTLE_ROOT")
    if not configured_root:
        print("[mantle:error] MANTLE_ROOT is required for command dispatch", file=sys.stderr)
        return 70
    root = Path(configured_root)
    try:
        profiles = load_profiles(root)
        result: dict[str, Any] = {"schema_version": SCHEMA_VERSION}
        if parsed.group == "profiles":
            if parsed.action == "validate":
                result.update(valid=True, profiles=len(profiles))
            elif parsed.action == "show":
                result["profile"] = next(profile for profile in profiles if profile["name"] == parsed.name)
            else:
                result["profiles"] = profiles
        else:
            commands = load_catalog(root, profiles)
            if parsed.action == "validate":
                result.update(valid=True, commands=len(commands))
            else:
                if parsed.profile:
                    inherited = next(profile["resolved_profiles"] for profile in profiles if profile["name"] == parsed.profile)
                    commands = [command for command in commands if any(name in inherited for name in command["profiles"])]
                    result["profile"] = parsed.profile
                result["commands"] = commands
        display(result, parsed)
    except (MetadataError, OSError) as error:
        print(f"[mantle:error] {error}", file=sys.stderr)
        return 78
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except BrokenPipeError:
        # Avoid another flush failure when a caller intentionally closes a pipe.
        sys.stdout = open(os.devnull, "w", encoding="utf-8")
        raise SystemExit(0)
