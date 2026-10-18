#!/usr/bin/env bats
# Real local Git repositories; no remote network access or forced deletion.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
	REPO_DIR="${BIN_TEST_HOME}/repository"
	git init --quiet --initial-branch=main "${REPO_DIR}"
	git -C "${REPO_DIR}" config user.email "fixture@mantle.invalid"
	git -C "${REPO_DIR}" config user.name "Mantle Fixture"
	git -C "${REPO_DIR}" commit --quiet --allow-empty --message "Initial fixture"
	git -C "${REPO_DIR}" remote add origin "${BIN_TEST_HOME}/deliberately-unavailable-remote.git"
}

teardown() {
	bin_test_teardown
}

# @description Create one local branch with a removed configured tracking ref.
# @arg $1 string Local branch name.
_gone_branch() {
	local branch="${1:?}"
	git -C "${REPO_DIR}" update-ref "refs/remotes/origin/${branch}" HEAD
	git -C "${REPO_DIR}" branch --quiet --track "${branch}" "origin/${branch}"
	git -C "${REPO_DIR}" update-ref -d "refs/remotes/origin/${branch}"
}

# @description Invoke with the native platform Bash, including macOS Bash 3.2.
# @arg $@ string Public command arguments.
_gone_run() {
	run /bin/bash --noprofile --norc -c 'cd -- "$1" || exit; shift; exec /bin/bash "$@"' \
		_ "${REPO_DIR}" "${MANTLE_ROOT}/bin/git-delete-gone-branches" "$@"
}

@test "git-delete-gone-branches documents safe defaults and rejects invalid arguments" {
	_gone_run --help
	assert_success
	assert_output_contains "Nothing is fetched or deleted automatically"
	_gone_run --version
	assert_success
	assert_output_contains "1.0.0"
	_gone_run --unknown
	assert_failure
	[[ "${status}" == 64 ]]
	_gone_run --apply --dry-run
	[[ "${status}" == 64 ]]
}

@test "git-delete-gone-branches previews locally without fetching or deleting" {
	_gone_branch stale
	git -C "${REPO_DIR}" branch no-upstream
	_gone_run
	assert_success
	assert_output_contains "Would delete merged branch: stale"
	assert_output_not_contains "no-upstream"
	git -C "${REPO_DIR}" show-ref --verify --quiet refs/heads/stale
	_gone_run --dry-run
	assert_success
	git -C "${REPO_DIR}" show-ref --verify --quiet refs/heads/stale
}

@test "git-delete-gone-branches applies merged deletion and cleans branch configuration" {
	_gone_branch stale
	_gone_run --apply
	assert_success
	assert_output_contains "deleted: 1"
	run git -C "${REPO_DIR}" show-ref --verify --quiet refs/heads/stale
	assert_failure
	run git -C "${REPO_DIR}" config --get branch.stale.remote
	assert_failure
	_gone_run --apply
	assert_success
	assert_output_contains "Gone branches: 0"
}

@test "git-delete-gone-branches preserves unmerged current and linked-worktree branches" {
	_gone_branch unmerged
	git -C "${REPO_DIR}" switch --quiet unmerged
	git -C "${REPO_DIR}" commit --quiet --allow-empty --message "Unique local work"
	git -C "${REPO_DIR}" switch --quiet main
	_gone_branch checked-out
	git -C "${REPO_DIR}" worktree add --quiet "${BIN_TEST_HOME}/linked" checked-out
	git -C "${REPO_DIR}" config branch.main.remote origin
	git -C "${REPO_DIR}" config branch.main.merge refs/heads/deleted-main
	_gone_run --apply
	assert_success
	assert_output_contains "Protected checked-out branch: main"
	assert_output_contains "Protected checked-out branch: checked-out"
	assert_output_contains "Preserved branch without a proven merge into HEAD: unmerged"
	git -C "${REPO_DIR}" show-ref --verify --quiet refs/heads/unmerged
	git -C "${REPO_DIR}" show-ref --verify --quiet refs/heads/checked-out
}

@test "git-delete-gone-branches fetch is explicit and failure prevents local deletion" {
	_gone_branch stale
	_gone_run --fetch --apply
	assert_failure
	git -C "${REPO_DIR}" show-ref --verify --quiet refs/heads/stale
	git init --quiet --bare "${BIN_TEST_HOME}/remote.git"
	git -C "${REPO_DIR}" remote set-url origin "${BIN_TEST_HOME}/remote.git"
	git -C "${REPO_DIR}" push --quiet origin main
	git -C "${REPO_DIR}" push --quiet origin main:removed
	git -C "${REPO_DIR}" branch --quiet --track newly-gone origin/removed
	git --git-dir="${BIN_TEST_HOME}/remote.git" update-ref -d refs/heads/removed
	_gone_run --fetch
	assert_success
	assert_output_contains "Would delete merged branch: newly-gone"
	git -C "${REPO_DIR}" show-ref --verify --quiet refs/heads/newly-gone
}

@test "git-delete-gone-branches treats shell metacharacters as literal branch names" {
	_gone_branch 'stale;literal$(command)'
	_gone_run --apply
	assert_success
	assert_output_contains 'stale;literal$(command)'
	run git -C "${REPO_DIR}" show-ref --verify --quiet 'refs/heads/stale;literal$(command)'
	assert_failure
}

@test "git-delete-gone-branches preserves a branch changed after the preview snapshot" {
	_gone_branch stale
	local actual_git changed_revision tree
	actual_git="$(command -v git)"
	tree="$(git -C "${REPO_DIR}" rev-parse 'HEAD^{tree}')"
	changed_revision="$(printf "Concurrent local work\n" | git -C "${REPO_DIR}" commit-tree "${tree}" -p HEAD)"
	{
		printf '#!/bin/sh\n'
		printf 'if [ "$1" = for-each-ref ] && [ "${3:-}" = -- ]; then\n'
		printf '  %q update-ref refs/heads/stale %q\n' "${actual_git}" "${changed_revision}"
		printf 'fi\nexec %q "$@"\n' "${actual_git}"
	} >"${BIN_STUB_DIR}/git"
	chmod 0755 "${BIN_STUB_DIR}/git"
	_gone_run --apply
	assert_failure
	assert_output_contains "selection or HEAD changed"
	[[ "$("${actual_git}" -C "${REPO_DIR}" rev-parse stale)" == "${changed_revision}" ]]
}

@test "git-delete-gone-branches reports missing Git and a non-worktree without mutations" {
	local empty_path="${BIN_TEST_HOME}/empty-path"
	mkdir -p "${empty_path}"
	run env PATH="${empty_path}" /bin/bash "${MANTLE_ROOT}/bin/git-delete-gone-branches" --apply
	[[ "${status}" == 69 ]]
	builtin cd -- "${BIN_TEST_HOME}"
	run /bin/bash "${MANTLE_ROOT}/bin/git-delete-gone-branches" --apply
	[[ "${status}" == 65 ]]
}

@test "git-delete-gone-branches accepts an unborn worktree as an empty selection" {
	REPO_DIR="${BIN_TEST_HOME}/unborn"
	git init --quiet --initial-branch=main "${REPO_DIR}"
	_gone_run --apply
	assert_success
	assert_output_contains "Gone branches: 0"
}
