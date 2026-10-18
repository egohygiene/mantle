#!/usr/bin/env bats
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Contract tests for Mantle's maintained documentation surfaces.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
}

@test "required Mantle documentation is non-empty" {
	local document_path=""

	for document_path in \
		"README.md" \
		"ARCHITECTURE.md" \
		"CONTRIBUTING.md" \
		"PROVENANCE.md" \
		"tests/README.md"; do
		assert_file_exists "${MANTLE_ROOT}/${document_path}"
		[[ -s "${MANTLE_ROOT}/${document_path}" ]]
	done
}

@test "README links the architecture, provenance, contribution, and test contracts" {
	local readme_path="${MANTLE_ROOT}/README.md"
	local expected_link=""

	for expected_link in \
		"ARCHITECTURE.md" \
		"PROVENANCE.md" \
		"CONTRIBUTING.md" \
		"tests/README.md"; do
		run grep -F "${expected_link}" "${readme_path}"
		assert_success
	done
}

@test "architecture and contribution docs name the layer registry" {
	for document_path in "ARCHITECTURE.md" "CONTRIBUTING.md"; do
		run grep -F "config/architecture/layers.tsv" \
			"${MANTLE_ROOT}/${document_path}"
		assert_success
	done
}
