#!/usr/bin/env zsh
#
# Establish Mantle's Zsh-specific runtime adapter.
#
# History and other interactive preferences are owned by environment modules,
# so this adapter deliberately avoids changing global Zsh options.

if [[ "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
	printf "[mantle:error] runtime/shells/zsh/runtime.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_RUNTIME_ZSH_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${ZSH_VERSION:-}" ]]; then
	printf "[mantle:error] Zsh runtime was sourced by a non-Zsh shell\n" >&2
	return 64
fi

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] runtime/shells/zsh/runtime.sh: MANTLE_ROOT is not set\n" >&2
	return 1
fi

if [[ "${MANTLE_RUNTIME_SHARED_LOADED:-0}" != "1" ||
	"${MANTLE_RUNTIME_POSIX_LOADED:-0}" != "1" ]]; then
	printf "[mantle:error] Zsh runtime requires the shared and POSIX runtimes\n" >&2
	return 1
fi

MANTLE_RUNTIME_ZSH_LOADED="1"

return 0

