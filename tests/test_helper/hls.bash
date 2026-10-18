#!/usr/bin/env bash
# shellcheck shell=bash
# Local synthetic HLS fixtures and public-command assertions.

# @description Require real media tools, failing the dedicated HLS CI job when absent.
hls_require_media_tools() {
	local tool
	for tool in python3 ffmpeg ffprobe; do
		if ! command -v "${tool}" >/dev/null 2>&1; then
			if [[ "${MANTLE_REQUIRE_HLS_TESTS:-0}" == 1 ]]; then
				printf "HLS tests require %s\n" "${tool}" >&2
				return 1
			fi
			skip "${tool} is not available for synthetic HLS integration"
		fi
	done
	if ! ffmpeg -hide_banner -h demuxer=hls 2>&1 | grep --quiet "seg_max_retry"; then
		if [[ "${MANTLE_REQUIRE_HLS_TESTS:-0}" == 1 ]]; then
			printf "HLS tests require FFmpeg with bounded HLS segment retries\n" >&2
			return 1
		fi
		skip "FFmpeg does not provide bounded HLS segment retries"
	fi
}

# @description Start an isolated loopback fixture with sanitized request events.
hls_start_fixture() {
	HLS_READY="${TEST_HOME}/server-ready.json"
	HLS_EVENTS="${TEST_HOME}/server-events.jsonl"
	python3 "${MANTLE_ROOT}/tests/fixtures/hls/server.py" serve "${HLS_MEDIA_DIR}" \
		--ready-file "${HLS_READY}" --events-file "${HLS_EVENTS}" --delay-seconds 2 \
		>"${TEST_HOME}/server.log" 2>&1 3>&- &
	HLS_SERVER_PID=$!
	export HLS_READY HLS_EVENTS HLS_SERVER_PID
	python3 - "${HLS_READY}" "${HLS_SERVER_PID}" <<'PY'
import json
import os
from pathlib import Path
import sys
import time
ready = Path(sys.argv[1])
for _ in range(100):
    if ready.exists():
        report = json.loads(ready.read_text())
        assert report["origin"].startswith("http://127.0.0.1:")
        break
    os.kill(int(sys.argv[2]), 0)
    time.sleep(0.05)
else:
    raise AssertionError("local HLS fixture did not become ready")
PY
}

# @description Stop the local fixture without leaving background servers running.
hls_stop_fixture() {
	if [[ -n "${HLS_SERVER_PID:-}" ]]; then
		kill "${HLS_SERVER_PID}" 2>/dev/null || true
		wait "${HLS_SERVER_PID}" 2>/dev/null || true
	fi
}

# @description Print one enumerated loopback endpoint from the ready document.
# @arg $1 string Endpoint name.
hls_endpoint() {
	python3 - "${HLS_READY}" "$1" <<'PY'
import json
from pathlib import Path
import sys
print(json.loads(Path(sys.argv[1]).read_text())["endpoints"][sys.argv[2]])
PY
}

# @description Print the synthetic player's loopback Referer.
hls_referer() {
	python3 - "${HLS_READY}" <<'PY'
import json
from pathlib import Path
import sys
print(json.loads(Path(sys.argv[1]).read_text())["origin"] + "/player")
PY
}

# @description Invoke the public HLS command in an isolated environment.
# @arg $@ string Public command arguments.
hls_run() {
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${PATH}" \
		LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" TERM=dumb \
		"${MANTLE_ROOT}/bin/mantle" hls-download "$@"
}

# @description Validate real decoded synthetic media and its expected container.
# @arg $1 string Downloaded media path.
# @arg $2 string Expected container (mkv, mp4, or ts).
# @arg $3 number Optional minimum duration, default 2.5 seconds.
# @arg $4 number Optional maximum duration, default 4 seconds.
hls_assert_media() {
	local media_path="${1:?}" format="${2:?}"
	ffprobe -v error -show_streams -show_format -of json "${media_path}" >"${TEST_HOME}/probe.json"
	python3 - "${TEST_HOME}/probe.json" "${format}" "${3:-2.5}" "${4:-4}" <<'PY'
import json
from pathlib import Path
import sys
report = json.loads(Path(sys.argv[1]).read_text())
streams = report["streams"]
assert any(stream.get("codec_name") == "h264" and stream.get("width") == 160
           and stream.get("height") == 90 for stream in streams), report
assert any(stream.get("codec_name") == "aac" for stream in streams), report
expected = {"mkv": "matroska", "mp4": "mp4", "ts": "mpegts"}[sys.argv[2]]
assert expected in report["format"]["format_name"].split(","), report
assert float(sys.argv[3]) <= float(report["format"]["duration"]) <= float(sys.argv[4]), report
PY
	ffmpeg -nostdin -hide_banner -loglevel error -xerror -i "${media_path}" -f null - >/dev/null 2>&1
}

# @description Assert trusted conditions against sanitized request events.
# @arg $1 string Python assertions using the events list.
hls_assert_events() {
	python3 - "${HLS_EVENTS}" "$1" <<'PY'
import json
from pathlib import Path
import sys
events = [json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
exec(sys.argv[2])
PY
}

# @description Check diagnostics and fixture logs for synthetic credential leaks.
hls_assert_redacted() {
	local marker
	for marker in fixture-access fixture-child fixture-password fixture-private-header; do
		assert_output_not_contains "${marker}"
	done
	python3 - "${HLS_READY}" "${HLS_EVENTS}" "${TEST_HOME}/server.log" <<'PY'
from pathlib import Path
import sys
for name in sys.argv[1:]:
    data = Path(name).read_bytes()
    assert all(marker not in data for marker in
               (b"fixture-access", b"fixture-child", b"fixture-password", b"fixture-private-header")), name
for name in Path(sys.argv[1]).parent.iterdir():
    if name.suffix in (".mkv", ".mp4", ".ts", ".media") and name.is_file():
        data = name.read_bytes()
        assert b"fixture-access" not in data and b"fixture-private-header" not in data, name
PY
}

# @description Assert no published output or unmanaged partial file remains.
# @arg $1 string Expected output path.
hls_assert_no_output() {
	assert_file_not_exists "$1"
	python3 - "${TEST_HOME}" <<'PY'
from pathlib import Path
import sys
assert not list(Path(sys.argv[1]).glob("*.partial*"))
assert not list(Path(sys.argv[1]).glob(".*.partial*"))
PY
}
