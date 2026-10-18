#!/usr/bin/env python3
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# ruff: noqa: PLR0912, PLR2004, TRY003
# Explicit contract diagnostics are clearer here than indirect exception constants.

"""Validate Mantle's pinned Fastfetch presentation contract without network access."""

from __future__ import annotations

import json
from pathlib import Path
import struct
import sys

MANTLE_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = MANTLE_ROOT / "config/fastfetch/fastfetch.jsonc"
BANNER_PATH = MANTLE_ROOT / "assets/presentation/incompris.png"
TEXT_PATH = MANTLE_ROOT / "assets/presentation/incompris.txt"
EXPECTED_SCHEMA = (
    "https://github.com/fastfetch-cli/fastfetch/raw/2.67.0/doc/json_schema.json"
)
EXPECTED_COMMANDS = (
    "mantle fastfetch runtime",
    "mantle fastfetch workspace",
    "mantle fastfetch toolchains",
    "mantle fastfetch contexts",
)


class ContractError(ValueError):
    """Report a violated Fastfetch presentation contract."""


def strip_json_comments(source: str) -> str:
    """Remove JSONC comments while preserving comment markers inside strings."""
    output: list[str] = []
    index = 0
    in_string = False
    escaped = False

    while index < len(source):
        character = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""

        if in_string:
            output.append(character)
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            index += 1
            continue

        if character == '"':
            in_string = True
            output.append(character)
            index += 1
            continue
        if character == "/" and following == "/":
            output.append(" ")
            index += 2
            while index < len(source) and source[index] not in "\r\n":
                index += 1
            continue
        if character == "/" and following == "*":
            output.append(" ")
            index += 2
            while index + 1 < len(source) and source[index : index + 2] != "*/":
                if source[index] in "\r\n":
                    output.append(source[index])
                index += 1
            if source[index : index + 2] != "*/":
                raise ContractError("Unterminated JSONC block comment")
            index += 2
            continue

        output.append(character)
        index += 1

    return "".join(output)


def strip_trailing_commas(source: str) -> str:
    """Remove only JSONC trailing commas outside quoted string values."""
    output: list[str] = []
    in_string = False
    escaped = False
    for index, character in enumerate(source):
        if in_string:
            output.append(character)
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            continue
        if character == '"':
            in_string = True
        if character == ",":
            following = source[index + 1 :].lstrip()
            if following.startswith(("}", "]")):
                continue
        output.append(character)
    return "".join(output)


def load_config() -> dict[str, object]:
    """Parse the canonical JSONC file using only the Python standard library."""
    source = CONFIG_PATH.read_text(encoding="utf-8")
    without_comments = strip_json_comments(source)
    payload = json.loads(strip_trailing_commas(without_comments))
    if not isinstance(payload, dict):
        raise ContractError("Fastfetch config root must be an object")
    return payload


def validate_banner() -> None:
    """Verify the supplied transparent banner contract and text fallback."""
    with BANNER_PATH.open("rb") as banner:
        signature = banner.read(8)
        if signature != b"\x89PNG\r\n\x1a\n":
            raise ContractError("Mantle banner is not a PNG")
        length = struct.unpack(">I", banner.read(4))[0]
        if banner.read(4) != b"IHDR" or length != 13:
            raise ContractError("Mantle banner is missing a canonical IHDR")
        width, height, _depth, color_type = struct.unpack(">IIBB", banner.read(10))
    if (width, height) != (400, 134):
        raise ContractError(f"Mantle banner dimensions changed: {width}x{height}")
    if color_type not in {4, 6}:
        raise ContractError("Mantle banner no longer declares an alpha channel")
    if not TEXT_PATH.read_text(encoding="utf-8").strip():
        raise ContractError("Mantle text fallback must not be empty")


def validate_config(payload: dict[str, object]) -> None:
    """Validate pinned compatibility, privacy, and command-module boundaries."""
    if payload.get("$schema") != EXPECTED_SCHEMA:
        raise ContractError("Fastfetch schema must remain pinned to 2.67.0")

    logo = payload.get("logo")
    if not isinstance(logo, dict) or logo.get("source") != "":
        raise ContractError("Standalone Fastfetch must retain its native OS logo fallback")
    chafa = logo.get("chafa")
    if not isinstance(chafa, dict):
        raise ContractError("Fastfetch Chafa settings are missing")
    for forced_capability in ("canvasMode", "colorSpace", "ditherMode"):
        if forced_capability in chafa:
            raise ContractError(f"Chafa capability must be negotiated: {forced_capability}")

    modules = payload.get("modules")
    if not isinstance(modules, list):
        raise ContractError("Fastfetch modules must be an array")

    module_types: list[str] = []
    command_texts: list[str] = []
    section_keys: list[object] = []
    for module in modules:
        if isinstance(module, str):
            module_types.append(module.lower())
            continue
        if not isinstance(module, dict):
            raise ContractError("Every Fastfetch module must be an object or shorthand string")
        module_type = str(module.get("type", "")).lower()
        module_types.append(module_type)
        if module_type == "command":
            command_texts.append(str(module.get("text", "")))
        if module_type == "custom" and str(module.get("format", "")).startswith(
            ("╭─", "├─", "╰─")
        ):
            section_keys.append(module.get("key"))

    if tuple(command_texts) != EXPECTED_COMMANDS:
        raise ContractError(f"Unexpected Fastfetch command modules: {command_texts}")
    if any(key != " " for key in section_keys):
        raise ContractError("Custom section headers must use a single-space key")
    for forbidden_module in ("publicip", "weather"):
        if forbidden_module in module_types:
            raise ContractError(f"Network-backed startup module is forbidden: {forbidden_module}")

    serialized = json.dumps(payload)
    if "dsForceDrm" in serialized:
        raise ContractError("Linux-only dsForceDrm is forbidden in the universal config")


def main() -> int:
    """Run the offline contract validation."""
    validate_banner()
    validate_config(load_config())
    sys.stdout.write("Mantle Fastfetch presentation contract is valid.\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ContractError, json.JSONDecodeError, OSError, struct.error) as error:
        sys.stderr.write(f"mantle-fastfetch-validation: {error}\n")
        raise SystemExit(1) from error
