#!/usr/bin/env bash
# shellcheck shell=bash

case $- in *i*) ;; *) return 0 ;; esac

alias show-hidden-files="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias hide-hidden-files="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# @description Flush the macOS DNS caches after requesting administrator access.
# @exitcode 0 The caches were flushed.
# @exitcode 1 A required command failed.
mantle_flush_dns() {
	command sudo command dscacheutil -flushcache &&
		command sudo command killall -HUP mDNSResponder &&
		printf "DNS cache flushed.\n"
}

# @description Lock the active macOS user session.
# @exitcode 0 The lock request was submitted.
# @exitcode 1 No supported lock command was available or it failed.
mantle_lock_screen() {
	if [[ -x "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" ]]; then
		command "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" -suspend
	elif command -v pmset >/dev/null 2>&1; then
		command pmset displaysleepnow
	else
		printf "[mantle:error] no supported macOS lock command is available\n" >&2
		return 1
	fi
}
