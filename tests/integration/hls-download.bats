#!/usr/bin/env bats
# Real, authorized synthetic HLS media over hermetic loopback HTTP fixtures.

setup_file() {
	load '../test_helper/common'
	load '../test_helper/hls'
	hls_require_media_tools
	HLS_MEDIA_DIR="${BATS_FILE_TMPDIR}/media"
	export HLS_MEDIA_DIR
	python3 "${MANTLE_ROOT}/tests/fixtures/hls/server.py" generate "${HLS_MEDIA_DIR}" \
		>"${BATS_FILE_TMPDIR}/generation.json"
}

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	load '../test_helper/hls'
	setup_isolated_home
	setup_stub_dir
	hls_start_fixture
	HLS_OUTPUT="${TEST_HOME}/download.mkv"
}

teardown() {
	if declare -F hls_stop_fixture >/dev/null; then hls_stop_fixture; fi
	if declare -F teardown_stub_dir >/dev/null; then teardown_stub_dir; fi
	if declare -F teardown_isolated_home >/dev/null; then teardown_isolated_home; fi
	return 0
}

@test "hls-download help version and standalone alias expose the public interface" {
	run "${MANTLE_ROOT}/bin/mantle" help hls-download
	assert_success
	assert_output_contains "--inherit-query"
	assert_output_contains "--no-range"
	assert_output_contains "--no-preflight"
	run "${MANTLE_ROOT}/bin/hls-download" --version
	assert_success
	assert_output_contains "hls-download"
	hls_assert_events 'assert events == []'
}

@test "hls-download rejects malformed options and header injection before any request" {
	hls_run
	assert_status 64
	hls_run "$(hls_endpoint vod)" --retry-count -1
	assert_status 64
	hls_run "$(hls_endpoint vod)" --timeout 0
	assert_status 64
	hls_run "$(hls_endpoint vod)" --header $'X-Fixture: safe\r\nAuthorization: injected'
	assert_status 64
	hls_run "$(hls_endpoint vod)" --header-file "${TEST_HOME}/missing-header-file"
	assert_status 64
	hls_run "http://fixture-user:fixture-password@127.0.0.1:1/index.m3u8"
	assert_status 64
	hls_assert_redacted
	hls_assert_events 'assert events == []'
	hls_assert_no_output "${HLS_OUTPUT}"
}

@test "hls-download dry-run is offline redacted and does not probe tools or create output" {
	create_recording_stub ffmpeg 99
	create_recording_stub ffprobe 99
	hls_run "$(hls_endpoint vod)?token=fixture-access" --output "${HLS_OUTPUT}" \
		--header "X-Private: fixture-private-header" --header-file "${TEST_HOME}/must-not-read.txt" --dry-run
	assert_success
	python3 - "${output}" <<'PY'
import json
import sys
report = json.loads(sys.argv[1])
assert report["schema_version"] == 1 and report["mode"] == "dry-run", report
assert report["header_file_count"] == 1 and not report["header_files_read"], report
PY
	[[ "$(stub_call_count ffmpeg)" == 0 ]]
	[[ "$(stub_call_count ffprobe)" == 0 ]]
	hls_assert_events 'assert events == []'
	hls_assert_no_output "${HLS_OUTPUT}"
	hls_assert_redacted
}

@test "hls-download stream-copies real master and VOD media into MKV MP4 and TS" {
	local format endpoint target
	builtin cd -- "${TEST_HOME}"
	for format in mkv mp4 ts; do
		endpoint=vod
		[[ "${format}" != mkv ]] || endpoint=master
		if [[ "${format}" == mkv ]]; then
			target="${TEST_HOME}/download.mkv"
			hls_run "$(hls_endpoint "${endpoint}")"
		else
			target="${TEST_HOME}/copied.${format}"
			hls_run "$(hls_endpoint "${endpoint}")" --output "${target}"
		fi
		assert_success
		hls_assert_media "${target}" "${format}"
	done
	hls_assert_redacted
}

@test "hls-download supports explicit container selection H264 AAC transcoding and fMP4 maps" {
	hls_run "$(hls_endpoint fmp4)" --output "${TEST_HOME}/transcoded.media" --format mp4 --transcode
	assert_success
	hls_assert_media "${TEST_HOME}/transcoded.media" mp4
	hls_assert_events 'assert any(event["path"].endswith("/init.mp4") for event in events)'
}

@test "hls-download ordinary synthetic AES128 HLS decrypts through authorized key requests" {
	hls_run "$(hls_endpoint aes)" --output "${HLS_OUTPUT}"
	assert_success
	hls_assert_media "${HLS_OUTPUT}" mkv
	hls_assert_events 'assert any(event["path"].endswith("/key.bin") for event in events)'
}

@test "hls-download query inheritance is opt-in and covers children segments keys and maps" {
	hls_run "$(hls_endpoint inherit_aes)?token=fixture-access" --output "${TEST_HOME}/without-query.mkv"
	assert_status 65
	assert_file_not_exists "${TEST_HOME}/without-query.mkv"
	local endpoint
	for endpoint in inherit_aes inherit_fmp4; do
		hls_run "$(hls_endpoint "${endpoint}")?token=fixture-access" --inherit-query \
			--output "${TEST_HOME}/${endpoint}.mkv"
		assert_success
		hls_assert_media "${TEST_HOME}/${endpoint}.mkv" mkv
	done
	hls_assert_events '
authorized = [event for event in events if event["status"] in (200, 206)]
assert any(event["path"].endswith("/key.bin") for event in authorized)
assert any(event["path"].endswith("/init.mp4") for event in authorized)
assert all(event["token_valid"] for event in authorized)
'
	hls_assert_redacted
}

@test "hls-download preserves child-owned signed queries instead of replacing them" {
	hls_run "$(hls_endpoint own_query)?token=fixture-access" --inherit-query --output "${HLS_OUTPUT}"
	assert_success
	hls_assert_media "${HLS_OUTPUT}" mkv
	hls_assert_events 'assert events and all(event["token_valid"] for event in events)'
	hls_assert_redacted
}

@test "hls-download does not forward private context or inherited query across origins" {
	hls_run "$(hls_endpoint cross_origin)?token=fixture-access" --inherit-query \
		--header "X-Fixture-Access: fixture-access" --header "Authorization: Bearer fixture-access" \
		--referer "$(hls_referer)" \
		--output "${HLS_OUTPUT}"
	assert_success
	hls_assert_media "${HLS_OUTPUT}" mkv
	hls_assert_events '
primary = [event for event in events if event["server"] == "primary"]
secondary = [event for event in events if event["server"] == "secondary"]
assert primary and primary[0]["header_valid"] and primary[0]["authorization_present"]
assert secondary
assert all(not event[key] for event in secondary for key in
           ("query_present", "header_present", "authorization_present", "cookie_present", "referer_present"))
'
	hls_assert_redacted
}

@test "hls-download no-preflight fetches a single-use initial manifest exactly once" {
	hls_run "$(hls_endpoint vod)" --no-preflight --output "${HLS_OUTPUT}"
	assert_success
	hls_assert_media "${HLS_OUTPUT}" mkv
	hls_assert_events 'assert sum(event["path"] == "/vod/index.m3u8" for event in events) == 1'
}

@test "hls-download range compatibility is explicit and no-range handles a rejecting CDN" {
	hls_run "$(hls_endpoint range)" --retry-count 0 --output "${TEST_HOME}/ranged.mkv"
	assert_status 65
	assert_file_not_exists "${TEST_HOME}/ranged.mkv"
	hls_run "$(hls_endpoint range)" --no-range --output "${HLS_OUTPUT}"
	assert_success
	hls_assert_media "${HLS_OUTPUT}" mkv
	hls_assert_events '
failed = [event for event in events if event["status"] == 422]
assert failed and all(event["range_present"] for event in failed)
assert any(event["path"].endswith(".ts") and not event["range_present"] and event["status"] == 200 for event in events)
'
}

@test "hls-download deterministic 404 and 422 failures stop early without retry storms or output" {
	local endpoint
	for endpoint in 404 422 segment_404 segment_422 expired missing; do
		: >"${HLS_EVENTS}"
		hls_run "$(hls_endpoint "${endpoint}")" --retry-count 2 --output "${HLS_OUTPUT}"
		assert_status 65
		case "${endpoint}" in
		404 | segment_404 | missing)
			assert_output_contains "HTTP 404"
			assert_output_contains "remain available"
			;;
		422 | segment_422)
			assert_output_contains "HTTP 422"
			assert_output_contains "query inheritance"
			assert_output_contains "byte-range compatibility"
			;;
		expired) assert_output_contains "HTTP 410" ;;
		esac
		hls_assert_no_output "${HLS_OUTPUT}"
		hls_assert_events '
from collections import Counter
errors = [event for event in events if 400 <= event["status"] < 500]
assert errors and len(events) <= 6, events
assert max(Counter(event["path"] for event in errors).values()) <= 2, events
'
	done
	hls_assert_redacted
}

@test "hls-download retries transient segments and bounds persistent failures by retry-count" {
	hls_run "$(hls_endpoint transient_once)" --output "${HLS_OUTPUT}"
	assert_success
	hls_assert_media "${HLS_OUTPUT}" mkv
	hls_assert_events '
from collections import Counter
failed = [event for event in events if event["status"] == 503]
assert len(failed) == 3, events
assert all(count == 1 for count in Counter(event["path"] for event in failed).values()), events
assert all(any(event["path"] == failure["path"] and event["status"] in (200, 206) for event in events) for failure in failed), events
'
	local retry target
	for retry in 0 2; do
		: >"${HLS_EVENTS}"
		target="${TEST_HOME}/unavailable-${retry}.mkv"
		hls_run "$(hls_endpoint unavailable)" --retry-count "${retry}" --output "${target}"
		assert_status 65
		hls_assert_no_output "${target}"
		hls_assert_events "
failed = [event for event in events if event[\"status\"] == 503]
assert 1 <= len(failed) <= ${retry} + 1, events
assert len({event[\"path\"] for event in failed}) == 1, events
"
	done
}

@test "hls-download bounds unresponsive or truncated segments and removes their partials" {
	local endpoint
	for endpoint in timeout truncated; do
		: >"${HLS_EVENTS}"
		hls_run "$(hls_endpoint "${endpoint}")" --timeout 0.25 --retry-count 0 --output "${HLS_OUTPUT}"
		assert_status 65
		hls_assert_no_output "${HLS_OUTPUT}"
		hls_assert_events 'assert len(events) <= 5'
	done
}

@test "hls-download finite EOF responses finish without low-level reconnect loops" {
	hls_run "$(hls_endpoint finite_eof)" --output "${HLS_OUTPUT}"
	assert_success
	hls_assert_media "${HLS_OUTPUT}" mkv
	hls_assert_events 'assert len(events) <= 8'
}

@test "hls-download refuses malformed and DRM-protected playlists before media processing" {
	local endpoint
	for endpoint in malformed drm; do
		: >"${HLS_EVENTS}"
		hls_run "$(hls_endpoint "${endpoint}")" --output "${HLS_OUTPUT}"
		assert_status 65
		hls_assert_no_output "${HLS_OUTPUT}"
		hls_assert_events 'assert events and all(event["path"].endswith(".m3u8") for event in events)'
	done
}

@test "hls-download captures bounded live and event playlists" {
	local endpoint target
	for endpoint in live event; do
		target="${TEST_HOME}/${endpoint}.mkv"
		hls_run "$(hls_endpoint "${endpoint}")" --duration 2 --timeout 3 --output "${target}"
		assert_success
		hls_assert_media "${target}" mkv 1.5 3.5
	done
	hls_assert_events '
for kind in ("live", "event"):
    assert sum(event["path"] == "/" + kind + "/index.m3u8" for event in events) >= 2, events
'
}

@test "hls-download refuses existing output without network or file replacement" {
	printf "existing-user-data\n" >"${HLS_OUTPUT}"
	hls_run "$(hls_endpoint vod)" --output "${HLS_OUTPUT}"
	assert_status 73
	[[ "$(cat "${HLS_OUTPUT}")" == existing-user-data ]]
	hls_assert_events 'assert events == []'
}

@test "hls-download imports literal header files and supports explicit browser request context" {
	local header_file="${TEST_HOME}/request headers.txt"
	printf "X-Fixture-Access: fixture-access\nAuthorization: Bearer fixture-access\n" >"${header_file}"
	printf "X-Literal: \$(touch %s)\n" "${TEST_HOME}/unexpected-evaluation" >>"${header_file}"
	hls_run "$(hls_endpoint all_context)?token=fixture-access" --inherit-query \
		--header-file "${header_file}" --referer "$(hls_referer)" \
		--cookie "fixture_session=fixture-access" --user-agent "Mantle-Fixture/1" --output "${HLS_OUTPUT}"
	assert_success
	hls_assert_media "${HLS_OUTPUT}" mkv
	assert_file_not_exists "${TEST_HOME}/unexpected-evaluation"
	hls_assert_events '
assert events
assert all(all(event[key] for key in ("token_valid", "header_valid", "cookie_valid", "referer_valid", "authorization_present")) for event in events)
'
	hls_assert_redacted
}

@test "hls-download accepts Cookie records in header files and rejects executable import text" {
	local header_file="${TEST_HOME}/cookie headers.txt"
	printf "Cookie: fixture_session=fixture-access\n" >"${header_file}"
	hls_run "$(hls_endpoint cookie)" --header-file "${header_file}" --output "${HLS_OUTPUT}"
	assert_success
	hls_assert_media "${HLS_OUTPUT}" mkv
	printf "curl \$(touch %s)\n" "${TEST_HOME}/unexpected-evaluation" >"${header_file}"
	hls_run "$(hls_endpoint vod)" --header-file "${header_file}" --output "${TEST_HOME}/invalid.mkv"
	assert_status 64
	assert_file_not_exists "${TEST_HOME}/unexpected-evaluation"
	assert_file_not_exists "${TEST_HOME}/invalid.mkv"
	hls_assert_redacted
}

@test "hls-download diagnostics classify manifests and report redacted request shape without tools" {
	create_recording_stub ffmpeg 99
	create_recording_stub ffprobe 99
	local endpoint expected
	for endpoint in master vod; do
		expected=media
		[[ "${endpoint}" != master ]] || expected=master
		hls_run "$(hls_endpoint "${endpoint}")?token=fixture-access" \
			--header "Authorization: Bearer fixture-access" --diagnose
		assert_success
		python3 - "${output}" "${expected}" <<'PY'
import json
import sys
report = json.loads(sys.argv[1])
assert report["schema_version"] == 1 and report["mode"] == "diagnose", report
assert report["playlist_type"] == sys.argv[2], report
assert report["request_shape"]["private_header_count"] == 1, report
assert report["request_shape"]["source_has_query"], report
PY
		hls_assert_redacted
	done
	[[ "$(stub_call_count ffmpeg)" == 0 ]]
	[[ "$(stub_call_count ffprobe)" == 0 ]]
	hls_assert_no_output "${HLS_OUTPUT}"
	hls_assert_events 'assert events and all(event["path"].endswith(".m3u8") for event in events)'
}

@test "hls-download strips all private context after a redirect to another origin" {
	hls_run "$(hls_endpoint redirect_origin)?token=fixture-access" --inherit-query \
		--header "X-Fixture-Access: fixture-access" --header "Authorization: Bearer fixture-access" \
		--cookie "fixture_session=fixture-access" --referer "$(hls_referer)" --output "${HLS_OUTPUT}"
	assert_success
	hls_assert_media "${HLS_OUTPUT}" mkv
	hls_assert_events '
initial = [event for event in events if event["status"] == 302]
secondary = [event for event in events if event["server"] == "secondary"]
assert initial and all(initial[0][key] for key in ("token_valid", "header_valid", "authorization_present", "cookie_valid", "referer_valid"))
assert secondary
assert all(not event[key] for event in secondary for key in
           ("query_present", "header_present", "authorization_present", "cookie_present", "referer_present"))
'
	hls_assert_redacted
}

@test "hls-download feature-probes bounded retries and rejects unsupported reconnect opt-in" {
	local actual_ffmpeg
	actual_ffmpeg="$(command -v ffmpeg)"
	{
		printf '#!/bin/sh\n'
		printf 'case "$*" in\n*protocol=http*) printf " -reconnect boolean\\n"; exit 0 ;;\nesac\n'
		printf 'exec %q "$@"\n' "${actual_ffmpeg}"
	} >"${STUB_DIR}/ffmpeg"
	chmod 0755 "${STUB_DIR}/ffmpeg"
	hls_run "$(hls_endpoint vod)" --http-reconnect --output "${HLS_OUTPUT}"
	assert_status 69
	hls_assert_events 'assert events == []'
	hls_assert_no_output "${HLS_OUTPUT}"
	hls_run "$(hls_endpoint vod)" --output "${HLS_OUTPUT}"
	assert_success
	# Inspect with the real decoder, because this test intentionally wraps FFmpeg.
	hls_assert_media "${HLS_OUTPUT}" mkv
	create_stub ffmpeg 0 "no bounded segment retry option"
	hls_run "$(hls_endpoint vod)" --output "${TEST_HOME}/unsupported.mkv"
	assert_status 69
	assert_file_not_exists "${TEST_HOME}/unsupported.mkv"
}

@test "hls-download reports missing media tools before fetching a manifest" {
	local minimal_path="${TEST_HOME}/without-ffmpeg" tool
	mkdir -p "${minimal_path}"
	for tool in bash basename dirname readlink python3 ffprobe; do
		ln -s "$(command -v "${tool}")" "${minimal_path}/${tool}"
	done
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${minimal_path}" \
		LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" TERM=dumb \
		"${MANTLE_ROOT}/bin/mantle" hls-download "$(hls_endpoint vod)" --output "${HLS_OUTPUT}"
	assert_status 69
	hls_assert_events 'assert events == []'
	hls_assert_no_output "${HLS_OUTPUT}"
}

@test "hls-download failed validation and a publication collision never publish or replace media" {
	local actual_ffprobe
	actual_ffprobe="$(command -v ffprobe)"
	create_stub ffprobe 0 "{invalid-json fixture-private-header"
	hls_run "$(hls_endpoint vod)" --output "${HLS_OUTPUT}"
	assert_status 65
	hls_assert_no_output "${HLS_OUTPUT}"
	hls_assert_redacted
	{
		printf '#!/bin/sh\n'
		printf 'printf "racing-user-data\\n" >%q\n' "${HLS_OUTPUT}"
		printf 'exec %q "$@"\n' "${actual_ffprobe}"
	} >"${STUB_DIR}/ffprobe"
	chmod 0755 "${STUB_DIR}/ffprobe"
	hls_run "$(hls_endpoint vod)" --output "${HLS_OUTPUT}"
	assert_status 73
	[[ "$(cat "${HLS_OUTPUT}")" == racing-user-data ]]
	python3 - "${TEST_HOME}" <<'PY'
from pathlib import Path
import sys
assert not list(Path(sys.argv[1]).glob(".mantle-hls-*.partial.*"))
PY
}

@test "hls-download interruption returns 130 and obeys the private partial retention policy" {
	run python3 - "${MANTLE_ROOT}/bin/mantle" "$(hls_endpoint timeout)" "${HLS_EVENTS}" "${TEST_HOME}" <<'PY'
import json
from pathlib import Path
import signal
import stat
import subprocess
import sys
import time
root = Path(sys.argv[4])
events_file = Path(sys.argv[3])
for keep in (False, True):
    events_file.write_text("")
    destination = root / ("kept.mkv" if keep else "discarded.mkv")
    arguments = [sys.argv[1], "hls-download", sys.argv[2], "--timeout", "5", "--output", str(destination)]
    if keep:
        arguments.append("--keep-partial")
    process = subprocess.Popen(arguments, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        for _ in range(200):
            events = [json.loads(line) for line in events_file.read_text().splitlines()]
            if any(event["path"].endswith(".ts") for event in events):
                break
            assert process.poll() is None, "download stopped before the interrupt test reached a segment"
            time.sleep(0.025)
        else:
            raise AssertionError("download never requested a synthetic segment")
        process.send_signal(signal.SIGINT)
        stdout, stderr = process.communicate(timeout=10)
        assert process.returncode == 130, (process.returncode, stdout, stderr)
        assert not destination.exists()
        partials = list(root.glob(".mantle-hls-*.partial.*"))
        assert len(partials) == int(keep), partials
        for partial in partials:
            assert stat.S_IMODE(partial.stat().st_mode) == 0o600
            partial.unlink()
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate(timeout=5)
print("interrupt and retention policies verified")
PY
	assert_success
	assert_output_contains "interrupt and retention policies verified"
}

@test "hls-download standalone command is invocable from Zsh and Fish" {
	local shell_name executable available=0
	for shell_name in zsh fish; do
		executable="$(command -v "${shell_name}" || true)"
		[[ -n "${executable}" ]] || continue
		available=1
		case "${shell_name}" in
		zsh)
			# shellcheck disable=SC2016 # Arguments expand inside the requested shell.
			run "${executable}" --no-rcs -c '"$1/bin/hls-download" "$2" --dry-run' _ "${MANTLE_ROOT}" "$(hls_endpoint vod)"
			;;
		fish)
			# shellcheck disable=SC2016 # Fish expands its native argv in the child.
			run "${executable}" --no-config --command '"$argv[1]/bin/hls-download" "$argv[2]" --dry-run' "${MANTLE_ROOT}" "$(hls_endpoint vod)"
			;;
		esac
		assert_success
		assert_output_contains '"mode": "dry-run"'
	done
	[[ "${available}" == 1 ]] || skip "Zsh and Fish are not available"
	hls_assert_events 'assert events == []'
}
