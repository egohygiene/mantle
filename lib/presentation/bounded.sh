#!/usr/bin/env bash
# shellcheck shell=bash
# Private presentation deadline helper; does not change the caller's shell options.

# @description Run an optional display operation with a wall-clock deadline.
# @arg $1 number Maximum seconds, including a fractional value for local probes.
# @arg $@ string Command and literal arguments.
# @exitcode 64 Invalid deadline or missing command.
# @exitcode 143 The deadline terminated the operation (137 if forced).
mantle_presentation_run_bounded() (
	local duration="${1:-}"
	local operation_pid="" watchdog_pid="" operation_status=0
	[[ "${duration}" =~ ^[0-9]+([.][0-9]+)?$ ]] && (($# >= 2)) || exit 64
	shift

	# Job control assigns independent process groups even in a noninteractive
	# Bash. The watchdog and cleanup can stop grandchildren on macOS as well as
	# Linux, without requiring GNU timeout, Python, or a container runtime.
	set -m
	("$@") <&0 &
	operation_pid=$!
	(
		sleep "${duration}"
		kill -TERM -- "-${operation_pid}" 2>/dev/null || :
		sleep 0.1
		kill -KILL -- "-${operation_pid}" 2>/dev/null || :
	) &
	watchdog_pid=$!
	trap 'kill -KILL -- "-${operation_pid}" "-${watchdog_pid}" 2>/dev/null || :; wait "${watchdog_pid}" 2>/dev/null || :' EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM HUP
	if [[ -t 0 && -t 1 ]]; then
		# Renderers may query terminal capabilities. Give the operation the
		# foreground TTY while the independent watchdog enforces its deadline.
		# The child already owns its output FD; silence only fg's job announcement.
		# Bash uses stderr's terminal FD for foreground ownership; keep it open.
		if fg %1 >/dev/null; then
			operation_status=0
		else
			operation_status=$?
			# A very short operation may finish before fg; retain its real status.
			if ((operation_status == 1)); then
				if wait "${operation_pid}" 2>/dev/null; then
					operation_status=0
				else
					operation_status=$?
				fi
			fi
		fi
	elif wait "${operation_pid}" 2>/dev/null; then
		operation_status=0
	else
		operation_status=$?
	fi
	set +m
	exit "${operation_status}"
)
