#!/usr/bin/env bash
# shellcheck shell=bash

case $- in *i*) ;; *) return 0 ;; esac

if command -v ss >/dev/null 2>&1; then
	alias ports="ss --listening --numeric --tcp --udp"
fi
if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
	alias setclip="wl-copy"
	alias getclip="wl-paste"
elif command -v xclip >/dev/null 2>&1; then
	alias setclip="xclip -selection clipboard"
	alias getclip="xclip -selection clipboard -out"
fi
