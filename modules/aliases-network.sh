# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# Interactive network inspection helpers. Public IP lookup performs network I/O.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/aliases-network.sh is internal and must be sourced\n" >&2
	exit 64
fi
if [[ "${MANTLE_INTERACTIVE:-0}" != "1" ]]; then return 0; fi

# @description List listening TCP and UDP ports with an available utility.
mantle_list_ports() {
	if command -v ss >/dev/null 2>&1; then
		command ss --listening --numeric --tcp --udp
	elif command -v lsof >/dev/null 2>&1; then
		command lsof -nP -iTCP -sTCP:LISTEN -iUDP
	elif command -v netstat >/dev/null 2>&1; then
		command netstat -an
	else
		printf "[mantle:error] no supported port-listing command is available\n" >&2
		return 69
	fi
}

# @description Print non-loopback local IP addresses one per line.
mantle_local_ip_addresses() {
	if command hostname -I >/dev/null 2>&1; then
		command hostname -I | tr " " "\n" | sed "/^$/d"
	elif command -v ip >/dev/null 2>&1; then
		command ip -o -4 address show scope global | awk '{print $4}' | cut -d/ -f1
	elif command -v ifconfig >/dev/null 2>&1; then
		command ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2}'
	else
		printf "[mantle:error] no supported local-address command is available\n" >&2
		return 69
	fi
}

# @description Print the current public IP address using DNS or HTTPS.
mantle_public_ip() {
	if command -v dig >/dev/null 2>&1; then
		command dig +short myip.opendns.com @resolver1.opendns.com
	elif command -v curl >/dev/null 2>&1; then
		command curl --fail --silent --show-error https://api.ipify.org
		printf "\n"
	else
		printf "[mantle:error] dig or curl is required to resolve the public IP address\n" >&2
		return 69
	fi
}

alias ports="mantle_list_ports"
alias ipaddr="mantle_local_ip_addresses"
alias public-ip="mantle_public_ip"

return 0
