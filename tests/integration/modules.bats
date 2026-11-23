#!/usr/bin/env bats
# Integration tests for module behavior (xdg, privacy, update-checks, etc.).

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
}

teardown() {
	teardown_isolated_home
}

# ---------------------------------------------------------------------------
# XDG module
# ---------------------------------------------------------------------------

@test "xdg module sets XDG_CONFIG_HOME to default" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			printf '%s\n' \"\${XDG_CONFIG_HOME}\"
		"
	assert_success
	assert_output_contains "${TEST_HOME}/.config"
}

@test "xdg module preserves caller-provided absolute XDG_CONFIG_HOME" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		XDG_CONFIG_HOME="${TEST_HOME}/custom-config" \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			printf '%s\n' \"\${XDG_CONFIG_HOME}\"
		"
	assert_success
	assert_output_contains "${TEST_HOME}/custom-config"
}

@test "xdg module replaces relative XDG_CONFIG_HOME with default and warns" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		XDG_CONFIG_HOME="relative/path" \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg 2>&1
			printf '%s\n' \"\${XDG_CONFIG_HOME}\"
		" 2>&1
	assert_output_contains "must be absolute"
	assert_output_contains "${TEST_HOME}/.config"
}

@test "xdg module sets XDG_RUNTIME_DIR to an absolute path" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			printf '%s\n' \"\${XDG_RUNTIME_DIR}\"
		"
	assert_success
	[[ "${lines[0]}" == /* ]]
}

# ---------------------------------------------------------------------------
# Privacy module
# ---------------------------------------------------------------------------

@test "privacy module exports DO_NOT_TRACK=1 by default" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			mantle_load_module privacy
			printf '%s\n' \"\${DO_NOT_TRACK}\"
		"
	assert_success
	assert_output_contains "1"
}

@test "privacy module is skipped when MANTLE_DISABLE_TELEMETRY=0" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		MANTLE_DISABLE_TELEMETRY=0 \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			mantle_load_module privacy
			printf '%s\n' \"\${DO_NOT_TRACK:-unset}\"
		"
	assert_success
	assert_output_contains "unset"
}

@test "privacy module is independent from update-check suppression" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			mantle_load_module privacy
			# HOMEBREW_NO_AUTO_UPDATE should NOT be set by privacy alone
			printf '%s\n' \"\${HOMEBREW_NO_AUTO_UPDATE:-unset}\"
		"
	assert_success
	assert_output_contains "unset"
}

# ---------------------------------------------------------------------------
# Update-checks module contract
# ---------------------------------------------------------------------------

@test "update-checks module is not loaded by default" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${MANTLE_LOADED_MODULES}\"
		"
	assert_success
	assert_output_not_contains "update-checks"
}

@test "update-checks module loads only when MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS=1" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS=1 \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${MANTLE_LOADED_MODULES}\"
		"
	assert_success
	assert_output_contains "update-checks"
}

@test "update-checks module sets HOMEBREW_NO_AUTO_UPDATE when loaded" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS=1 \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${HOMEBREW_NO_AUTO_UPDATE:-unset}\"
		"
	assert_success
	assert_output_contains "1"
}

@test "HOMEBREW_NO_AUTO_UPDATE is unset by default" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${HOMEBREW_NO_AUTO_UPDATE:-unset}\"
		"
	assert_success
	assert_output_contains "unset"
}

@test "update-check suppression does not affect telemetry policy" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS=1 \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf 'telemetry=%s\n' \"\${DO_NOT_TRACK:-unset}\"
		"
	assert_success
	assert_output_contains "telemetry=1"
}

@test "update-checks module rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/modules/update-checks.sh"
	assert_status 64
}

@test "privacy module rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/modules/privacy.sh"
	assert_status 64
}

# ---------------------------------------------------------------------------
# Migration-safe XDG tooling, caches, and history
# ---------------------------------------------------------------------------

@test "tooling preserves legacy state and reports every pending migration" {
	mkdir -p "${TEST_HOME}/.cargo/bin" "${TEST_HOME}/go" "${TEST_HOME}/.android"

	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf 'cargo=%s\n' \"\${CARGO_HOME:-legacy}\"
			printf 'go=%s\n' \"\${GOPATH:-legacy}\"
			printf 'android=%s\n' \"\${ANDROID_USER_HOME:-legacy}\"
			printf 'path=%s\n' \"\${PATH}\"
			printf 'warnings=%s\n' \"\${MANTLE_XDG_MIGRATION_WARNINGS:-}\"
		"
	assert_success
	assert_output_contains "cargo=legacy"
	assert_output_contains "go=legacy"
	assert_output_contains "android=legacy"
	assert_output_contains "${TEST_HOME}/.cargo/bin"
	assert_output_contains "CARGO_HOME"
	assert_output_contains "GOPATH"
	assert_output_contains "ANDROID_USER_HOME"
}

@test "tooling selects audited XDG roots for a fresh home" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf 'ansible=%s\n' \"\${ANSIBLE_HOME}\"
			printf 'docker=%s\n' \"\${DOCKER_CONFIG}\"
			printf 'dart=%s\n' \"\${DART_DATA_HOME}\"
			printf 'sdk=%s\n' \"\${ANDROID_HOME:-unset}\"
			printf 'sdk_root=%s\n' \"\${ANDROID_SDK_ROOT:-unset}\"
			printf 'flutter=%s\n' \"\${FLUTTER_HOME:-unset}\"
		"
	assert_success
	assert_output_contains "ansible=${TEST_HOME}/.local/share/ansible"
	assert_output_contains "docker=${TEST_HOME}/.config/docker"
	assert_output_contains "dart=${TEST_HOME}/.local/share/dart"
	assert_output_contains "sdk=unset"
	assert_output_contains "sdk_root=unset"
	assert_output_contains "flutter=unset"
}

@test "cache preserves an existing npm cache until migration" {
	mkdir -p "${TEST_HOME}/.npm"

	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf 'cache=%s\n' \"\${NPM_CONFIG_CACHE:-legacy}\"
			printf 'warnings=%s\n' \"\${MANTLE_XDG_MIGRATION_WARNINGS:-}\"
		"
	assert_success
	assert_output_contains "cache=legacy"
	assert_output_contains "NPM_CONFIG_CACHE"
}

@test "tooling preserves a legacy npmrc until its XDG file exists" {
	printf '%s\n' 'fund=false' >"${TEST_HOME}/.npmrc"

	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf 'config=%s\n' \"\${NPM_CONFIG_USERCONFIG:-legacy}\"
			printf 'warnings=%s\n' \"\${MANTLE_XDG_MIGRATION_WARNINGS:-}\"
		"
	assert_success
	assert_output_contains "config=legacy"
	assert_output_contains "NPM_CONFIG_USERCONFIG"
}

@test "history preserves legacy Bash history instead of silently splitting it" {
	printf '%s\n' 'existing command' >"${TEST_HOME}/.bash_history"

	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			MANTLE_INTERACTIVE=1
			MANTLE_SHELL_NAME=bash
			export MANTLE_ROOT MANTLE_INTERACTIVE MANTLE_SHELL_NAME
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			mantle_load_module history
			printf 'history=%s\n' \"\${HISTFILE}\"
			printf 'warnings=%s\n' \"\${MANTLE_XDG_MIGRATION_WARNINGS:-}\"
		"
	assert_success
	assert_output_contains "history=${TEST_HOME}/.bash_history"
	assert_output_contains "HISTFILE"
}

@test "history retains the prior Mantle history file and an explicit caller override" {
	mkdir -p "${XDG_STATE_HOME}/history/bash"
	touch "${XDG_STATE_HOME}/history/bash/history"
	# shellcheck disable=SC2016 # History assertions run in the isolated child shell.
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb MANTLE_ROOT="${MANTLE_ROOT}" \
		/bin/bash --noprofile --norc -c '
            source "$MANTLE_ROOT/modules/xdg.sh" || exit $?
            MANTLE_INTERACTIVE=1
            MANTLE_SHELL_NAME=bash
            source "$MANTLE_ROOT/modules/history.sh" || exit $?
            test "$HISTFILE" = "$XDG_STATE_HOME/history/bash/history" || exit 91
            HISTFILE="$HOME/caller-history"
            source "$MANTLE_ROOT/modules/history.sh" || exit $?
            test "$HISTFILE" = "$HOME/caller-history" || exit 92
            printf "existing-history-preserved\n"
        '
	assert_success
	assert_output_contains "existing-history-preserved"
}

# Existing state remains authoritative until the caller selects or retires it.
@test "tooling and cache preserve legacy state when XDG targets also exist" {
	mkdir -p "$TEST_HOME/.cargo/bin" "$TEST_HOME/.npm" "$TEST_HOME/.minikube/profiles"
	mkdir -p "$TEST_HOME/.local/share/cargo/bin" "$TEST_HOME/.local/share/minikube"
	mkdir -p "$TEST_HOME/.cache/npm" "$TEST_HOME/.config/npm"
	printf '%s\n' 'legacy configuration' >"$TEST_HOME/.npmrc"
	printf '%s\n' 'selected later' >"$TEST_HOME/.config/npm/npmrc"

	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test -z "${CARGO_HOME+x}" || exit 91
		test -z "${NPM_CONFIG_CACHE+x}" || exit 92
		test -z "${NPM_CONFIG_USERCONFIG+x}" || exit 93
		test -z "${MINIKUBE_HOME+x}" || exit 94
		case ":$PATH:" in *":$HOME/.cargo/bin:"*) ;; *) exit 95 ;; esac
		case ":$PATH:" in *":$HOME/.local/share/cargo/bin:"*) exit 96 ;; esac
		printf "%s\n" "$MANTLE_XDG_MIGRATION_WARNINGS"
	'
	assert_success
	assert_output_contains "CARGO_HOME"
	assert_output_contains "NPM_CONFIG_CACHE"
	assert_output_contains "NPM_CONFIG_USERCONFIG"
	assert_output_contains "MINIKUBE_HOME"
	[[ "$(cat "$TEST_HOME/.npmrc")" == "legacy configuration" ]]
	[[ "$(cat "$TEST_HOME/.config/npm/npmrc")" == "selected later" ]]
}

@test "precreated empty Codex target does not hide existing authentication state" {
	mkdir -p "$TEST_HOME/.codex" "$TEST_HOME/.local/share/codex"
	printf '%s\n' 'fixture authentication' >"$TEST_HOME/.codex/auth.json"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test -z "${CODEX_HOME+x}" || exit 91
		printf "%s\n" "$MANTLE_XDG_MIGRATION_WARNINGS"
	'
	assert_success
	assert_output_contains "CODEX_HOME"
	[[ "$(cat "$TEST_HOME/.codex/auth.json")" == "fixture authentication" ]]
	[[ ! -e "$TEST_HOME/.local/share/codex/auth.json" ]]
}

@test "broken legacy links remain visible to migration policy" {
	ln -s "$TEST_HOME/missing-cargo" "$TEST_HOME/.cargo"
	ln -s "$TEST_HOME/missing-npmrc" "$TEST_HOME/.npmrc"
	mkdir -p "$TEST_HOME/.local/share/cargo/bin" "$TEST_HOME/.config/npm"
	touch "$TEST_HOME/.config/npm/npmrc"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test -z "${CARGO_HOME+x}" || exit 91
		test -z "${NPM_CONFIG_USERCONFIG+x}" || exit 92
		case ":$PATH:" in *":$HOME/.local/share/cargo/bin:"*) exit 93 ;; esac
		case ":$PATH:" in *":$HOME/.cargo/bin:"*) exit 94 ;; esac
		printf "%s\n" "$MANTLE_XDG_MIGRATION_WARNINGS"
	'
	assert_success
	assert_output_contains "CARGO_HOME"
	assert_output_contains "NPM_CONFIG_USERCONFIG"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		CARGO_HOME="$TEST_HOME/.local/share/cargo" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
		/bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test "$CARGO_HOME" = "$HOME/.local/share/cargo" || exit 91
		case ":$PATH:" in *":$CARGO_HOME/bin:"*) ;; *) exit 92 ;; esac
		case ":${MANTLE_XDG_MIGRATION_WARNINGS:-}:" in *":CARGO_HOME:"*) exit 93 ;; esac
	'
	assert_success
	[[ -L "$TEST_HOME/.cargo" && -L "$TEST_HOME/.npmrc" ]]
}

@test "explicit XDG tool selections remain authoritative with both roots present" {
	mkdir -p "$TEST_HOME/.cargo" "$TEST_HOME/.npm" "$TEST_HOME/.local/share/cargo" "$TEST_HOME/.cache/npm"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		CARGO_HOME="$TEST_HOME/.local/share/cargo" NPM_CONFIG_CACHE="$TEST_HOME/.cache/npm" \
		XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test "$CARGO_HOME" = "$HOME/.local/share/cargo" || exit 91
		test "$NPM_CONFIG_CACHE" = "$HOME/.cache/npm" || exit 92
		case ":${MANTLE_XDG_MIGRATION_WARNINGS:-}:" in
			*":CARGO_HOME:"*|*":NPM_CONFIG_CACHE:"*) exit 93 ;;
		esac
	'
	assert_success
}

@test "Claude standalone legacy JSON is preserved until explicitly selected" {
	printf '%s\n' 'fixture account state' >"$TEST_HOME/.claude.json"
	mkdir -p "$TEST_HOME/.local/share/claude"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test -z "${CLAUDE_CONFIG_DIR+x}" || exit 91
		printf "%s\n" "$MANTLE_XDG_MIGRATION_WARNINGS"
	'
	assert_success
	assert_output_contains "CLAUDE_CONFIG_DIR"

	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		CLAUDE_CONFIG_DIR="$TEST_HOME/.local/share/claude" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
		/bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test "$CLAUDE_CONFIG_DIR" = "$HOME/.local/share/claude" || exit 91
	'
	assert_success
	[[ "$(cat "$TEST_HOME/.claude.json")" == "fixture account state" ]]
}

@test "OpenHands CLI persistence honors fresh legacy and explicit choices" {
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test "$OPENHANDS_PERSISTENCE_DIR" = "$HOME/.local/state/openhands" || exit 91
	'
	assert_success
	mkdir -p "$TEST_HOME/.openhands" "$TEST_HOME/.local/state/openhands"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test -z "${OPENHANDS_PERSISTENCE_DIR+x}" || exit 91
		printf "%s\n" "$MANTLE_XDG_MIGRATION_WARNINGS"
	'
	assert_success
	assert_output_contains "OPENHANDS_PERSISTENCE_DIR"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		OPENHANDS_PERSISTENCE_DIR="$TEST_HOME/selected-openhands" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
		/bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test "$OPENHANDS_PERSISTENCE_DIR" = "$HOME/selected-openhands" || exit 91
	'
	assert_success
}

@test "new activation recomputes migration warnings and repeat sourcing retains them" {
	mkdir -p "$TEST_HOME/.cargo"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		MANTLE_XDG_MIGRATION_WARNINGS=STALE_PARENT_WARNING XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
		/bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		before="$MANTLE_XDG_MIGRATION_WARNINGS"
		case ":$before:" in *":STALE_PARENT_WARNING:"*) exit 91 ;; esac
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test "$MANTLE_XDG_MIGRATION_WARNINGS" = "$before" || exit 92
		printf "%s\n" "$before"
	'
	assert_success
	assert_output_contains "CARGO_HOME"
}

@test "history preserves legacy content when the new history file already exists" {
	mkdir -p "$XDG_STATE_HOME/bash"
	printf '%s\n' 'legacy command' >"$TEST_HOME/.bash_history"
	printf '%s\n' 'new command' >"$XDG_STATE_HOME/bash/history"
	run env -i HOME="$TEST_HOME" PATH="$PATH" MANTLE_ROOT="$MANTLE_ROOT" \
		XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/modules/xdg.sh" || exit $?
		MANTLE_INTERACTIVE=1
		MANTLE_SHELL_NAME=bash
		source "$MANTLE_ROOT/modules/history.sh" || exit $?
		test "$HISTFILE" = "$HOME/.bash_history" || exit 91
		printf "%s\n" "$MANTLE_XDG_MIGRATION_WARNINGS"
	'
	assert_success
	assert_output_contains "HISTFILE"
	[[ "$(cat "$TEST_HOME/.bash_history")" == "legacy command" ]]
	[[ "$(cat "$XDG_STATE_HOME/bash/history")" == "new command" ]]
}

@test "XDG runtime rejects a symbolic link before changing target permissions" {
	mkdir -p "$TEST_HOME/runtime-target"
	chmod 755 "$TEST_HOME/runtime-target"
	ln -s "$TEST_HOME/runtime-target" "$TEST_HOME/runtime-link"
	run env -i HOME="$TEST_HOME" PATH="$PATH" MANTLE_ROOT="$MANTLE_ROOT" \
		XDG_RUNTIME_DIR="$TEST_HOME/runtime-link" /bin/bash --noprofile --norc -c \
		'source "$MANTLE_ROOT/modules/xdg.sh"'
	assert_failure
	assert_output_contains "must not be a symbolic link"
	run find "$TEST_HOME/runtime-target" -prune -perm 0755
	assert_success
	assert_output_contains "$TEST_HOME/runtime-target"
}

@test "Zsh preserves both-root state and legacy PATH without implicit migration" {
	local zsh_binary
	zsh_binary="$(command -v zsh || true)"
	[[ -n "$zsh_binary" ]] || skip "zsh is not available"
	mkdir -p "$TEST_HOME/.cargo/bin" "$TEST_HOME/.local/share/cargo/bin"
	printf '%s\n' 'fixture account state' >"$TEST_HOME/.claude.json"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" "$zsh_binary" --no-rcs -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test -z "${CARGO_HOME+x}" || exit 91
		test -z "${CLAUDE_CONFIG_DIR+x}" || exit 92
		case ":$PATH:" in *":$HOME/.cargo/bin:"*) ;; *) exit 93 ;; esac
		printf "%s\n" "$MANTLE_XDG_MIGRATION_WARNINGS"
	'
	assert_success
	assert_output_contains "CARGO_HOME"
	assert_output_contains "CLAUDE_CONFIG_DIR"
}

@test "automatic Codex home secures an existing user-owned default directory" {
	mkdir -p "$TEST_HOME/.local/share/codex"
	chmod 755 "$TEST_HOME/.local/share/codex"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		MANTLE_CREATE_XDG_DIRECTORIES=0 XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
		/bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test "$CODEX_HOME" = "$HOME/.local/share/codex" || exit 91
	'
	assert_success
	run find "$TEST_HOME/.local/share/codex" -prune -perm 0700
	assert_success
	assert_output_contains "$TEST_HOME/.local/share/codex"
}

@test "automatic Codex home rejects a symbolic link without changing its target" {
	mkdir -p "$TEST_HOME/codex-target"
	chmod 755 "$TEST_HOME/codex-target"
	ln -s "$TEST_HOME/codex-target" "$TEST_HOME/.local/share/codex"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /bin/bash --noprofile --norc -c \
		'source "$MANTLE_ROOT/.shellrc"'
	assert_failure
	assert_output_contains "private directory must not be a symbolic link"
	run find "$TEST_HOME/codex-target" -prune -perm 0755
	assert_success
	assert_output_contains "$TEST_HOME/codex-target"
}

@test "explicit Codex home permissions remain caller-owned and opt-out creates no default" {
	mkdir -p "$TEST_HOME/caller-codex"
	chmod 755 "$TEST_HOME/caller-codex"
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		CODEX_HOME="$TEST_HOME/caller-codex" MANTLE_CREATE_XDG_DIRECTORIES=0 XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
		/bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test "$CODEX_HOME" = "$HOME/caller-codex" || exit 91
	'
	assert_success
	run find "$TEST_HOME/caller-codex" -prune -perm 0755
	assert_success
	assert_output_contains "$TEST_HOME/caller-codex"
	[[ ! -e "$TEST_HOME/.local/share/codex" ]]
	run env -i HOME="$TEST_HOME" PATH="$PATH" TERM=dumb MANTLE_ROOT="$MANTLE_ROOT" \
		MANTLE_CREATE_XDG_DIRECTORIES=0 XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
		/bin/bash --noprofile --norc -c '
		source "$MANTLE_ROOT/.shellrc" || exit $?
		test -z "${CODEX_HOME+x}" || exit 91
	'
	assert_success
	[[ ! -e "$TEST_HOME/.local/share/codex" ]]
}
