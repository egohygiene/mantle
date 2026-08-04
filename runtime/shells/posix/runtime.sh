#!/bin/sh
# shellcheck shell=sh
#
# Establish Mantle's portable POSIX runtime baseline.
#
# This file intentionally contains no shell-specific behavior. It is a stable
# hook for future shell-neutral runtime helpers and verifies lifecycle order.

if [ "${MANTLE_RUNTIME_POSIX_LOADED:-0}" = "1" ]; then
	return 0
fi

if [ -z "${MANTLE_ROOT:-}" ]; then
	printf "[mantle:error] runtime/shells/posix/runtime.sh: MANTLE_ROOT is not set\n" >&2
	return 1
fi

if [ "${MANTLE_RUNTIME_SHARED_LOADED:-0}" != "1" ]; then
	printf "[mantle:error] POSIX runtime requires the shared runtime\n" >&2
	return 1
fi

MANTLE_RUNTIME_POSIX_LOADED="1"

return 0
