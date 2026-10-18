#!/usr/bin/env bats
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Offline contracts for the current Incompris startup presentation.

setup() {
	load "../test_helper/common"
	load "../test_helper/assertions"
	command -v python3 >/dev/null 2>&1 || skip "python3 is unavailable"
}

@test "Fastfetch config and artwork satisfy the offline presentation contract" {
	run python3 "${MANTLE_ROOT}/tests/validate_fastfetch.py"
	assert_success
	assert_output_contains "presentation contract is valid"
}

@test "shell adapters delegate rendering to the shared startup command" {
	run grep -F '"${MANTLE_ROOT}/bin/mantle" startup' "${MANTLE_ROOT}/.shellrc"
	assert_success
	run grep -F 'command "$MANTLE_ROOT/bin/mantle" startup' \
		"${MANTLE_ROOT}/runtime/shells/fish/functions/fish_greeting.fish"
	assert_success
}

@test "JSONC validation preserves comment markers and comma-like text inside strings" {
	run env MANTLE_ROOT="${MANTLE_ROOT}" python3 - <<'PYTHON'
import importlib.util
import json
import os
from pathlib import Path

path = Path(os.environ["MANTLE_ROOT"]) / "tests/validate_fastfetch.py"
spec = importlib.util.spec_from_file_location("mantle_fastfetch_validation", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
source = '{"url":"https://example.test/*literal*/", "text":",}", /* comment */ "items":[1,],}'
parsed = json.loads(module.strip_trailing_commas(module.strip_json_comments(source)))
assert parsed == {"url": "https://example.test/*literal*/", "text": ",}", "items": [1]}
PYTHON
	assert_success
}

@test "Fastfetch validation rejects network modules and unpinned schemas" {
	run env MANTLE_ROOT="${MANTLE_ROOT}" python3 - <<'PYTHON'
import copy
import importlib.util
import os
from pathlib import Path

path = Path(os.environ["MANTLE_ROOT"]) / "tests/validate_fastfetch.py"
spec = importlib.util.spec_from_file_location("mantle_fastfetch_validation", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
original = module.load_config()
for modification in ("network", "schema"):
    payload = copy.deepcopy(original)
    if modification == "network":
        payload["modules"].append({"type": "publicip"})
    else:
        payload["$schema"] = "https://example.test/mutable.json"
    try:
        module.validate_config(payload)
    except module.ContractError:
        continue
    raise AssertionError(f"accepted invalid {modification} configuration")
try:
    module.strip_json_comments("{} /* unterminated")
except module.ContractError:
    pass
else:
    raise AssertionError("accepted an unterminated JSONC comment")
PYTHON
	assert_success
}
