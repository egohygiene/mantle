#!/usr/bin/env bash
# shellcheck shell=bash
#
# Define portable, low-surprise interactive aliases and helper functions for
# Bash and Zsh. Platform-specific behavior is guarded at runtime so sourcing
# this module never assumes that a particular operating system or command is
# available.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/aliases.sh is internal and must be sourced\n" >&2
	exit 64
elif [[ -n "${ZSH_VERSION:-}" && "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
	printf "[mantle:error] modules/aliases.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INTERACTIVE:-0}" != "1" ]]; then
	return 0
fi

# ─── Shared helper functions ─────────────────────────────────────────────────

# @description Replace the current shell with a fresh login shell.
# @exitcode 64 SHELL was unset or did not identify an executable file.
mantle_reload_shell() {
	local shell_path="${SHELL:-}"

	if [[ -z "${shell_path}" || ! -x "${shell_path}" ]]; then
		printf "[mantle:error] cannot reload an unavailable shell: %s\n" \
			"${shell_path:-<unset>}" >&2
		return 64
	fi

	exec "${shell_path}" --login
}

# @description Create a directory and change the current shell into it.
# @arg $1 string Directory to create and enter.
# @exitcode 0 The directory was created, if necessary, and entered.
# @exitcode 64 Exactly one directory argument was not provided.
# @exitcode 1 Directory creation or the directory change failed.
mantle_mkcd() {
	if (($# != 1)); then
		printf "Usage: mkcd DIRECTORY\n" >&2
		return 64
	fi

	mkdir -p -- "$1" || return 1
	builtin cd -- "$1" || return 1
}

# @description Print PATH entries one per line in resolution order.
# @stdout Zero or more PATH entries.
# @exitcode 0 PATH was printed.
# @exitcode 64 Unexpected arguments were provided.
mantle_print_path() {
	local remaining_path="${PATH:-}"
	local path_entry=""

	if [[ -z "${remaining_path}" ]]; then
		return 0
	fi

	while :; do
		if [[ "${remaining_path}" == *:* ]]; then
			path_entry="${remaining_path%%:*}"
			remaining_path="${remaining_path#*:}"
			printf "%s\n" "${path_entry}"
		else
			printf "%s\n" "${remaining_path}"
			break
		fi
	done
}

# @description Print PATH entries one per line in locale-independent sort order.
# @stdout Zero or more sorted PATH entries.
# @exitcode 0 PATH was printed and sorted.
# @exitcode 64 Unexpected arguments were provided.
mantle_print_sorted_path() {
	if (($# != 0)); then
		printf "[mantle:error] mantle_print_sorted_path does not accept arguments\n" >&2
		return 64
	fi

	mantle_print_path | LC_ALL=C sort
}

# @description Invoke man with a readable color palette when less is the pager.
# @arg $@ string Arguments forwarded to man.
# @exitcode 0 man completed successfully.
# @exitcode * The status returned by man.
mantle_man() {
	LESS_TERMCAP_mb=$'\E[01;31m' \
		LESS_TERMCAP_md=$'\E[01;38;5;74m' \
		LESS_TERMCAP_me=$'\E[0m' \
		LESS_TERMCAP_se=$'\E[0m' \
		LESS_TERMCAP_so=$'\E[38;5;246m' \
		LESS_TERMCAP_ue=$'\E[0m' \
		LESS_TERMCAP_us=$'\E[04;38;5;146m' \
		command man "$@"
}

# @description Remove .DS_Store files below the current directory.
# @exitcode 0 Matching files were removed or none were present.
# @exitcode * The status returned by find.
mantle_remove_ds_store_files() {
	if (($# != 0)); then
		printf "[mantle:error] rmds does not accept arguments\n" >&2
		return 64
	fi

	command find . -type f -name ".DS_Store" -print -delete
}

# @description Show human-readable disk usage one directory level deep.
# @arg $@ string Paths forwarded to du; defaults to the current directory.
# @exitcode * The status returned by du.
mantle_disk_usage_depth_one() {
	if (($# == 0)); then
		set -- .
	fi

	if command du --version >/dev/null 2>&1; then
		command du --human-readable --max-depth=1 "$@"
	else
		command du -h -d 1 "$@"
	fi
}

# @description Show filesystem usage with filesystem types when supported.
# @arg $@ string Arguments forwarded to df.
# @exitcode * The status returned by df.
mantle_disk_free_with_type() {
	if command df --version >/dev/null 2>&1; then
		command df --human-readable --print-type "$@"
	else
		command df -h "$@"
	fi
}

# @description Show a human-readable filesystem summary with a total on GNU systems.
# @arg $@ string Arguments forwarded to df.
# @exitcode * The status returned by df.
mantle_disk_summary() {
	if command df --version >/dev/null 2>&1; then
		command df --human-readable --total "$@"
	else
		command df -h "$@"
	fi
}

# @description List processes without headers, newest process identifiers first.
# @exitcode * The status returned by the process-listing pipeline.
mantle_process_summary() {
	command ps -axo pid=,ppid=,command= | LC_ALL=C sort -k1,1nr
}

# @description Open top with a one-second refresh interval.
# @arg $@ string Additional arguments forwarded to top.
# @exitcode * The status returned by top.
mantle_top_continuous() {
	if [[ "$(command uname -s)" == "Darwin" ]]; then
		command top -s 1 "$@"
	else
		command top --delay 1 "$@"
	fi
}

# @description List listening TCP and UDP ports with the best available utility.
# @exitcode 0 Listening ports were listed.
# @exitcode 69 No supported port-listing utility was available.
# @exitcode * The status returned by the selected utility.
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
# @exitcode 0 At least one supported address command completed.
# @exitcode 69 No supported address command was available.
mantle_local_ip_addresses() {
	if command hostname -I >/dev/null 2>&1; then
		command hostname -I | tr " " "\n" | sed "/^$/d"
	elif command -v ip >/dev/null 2>&1; then
		command ip -o -4 address show scope global |
			awk '{print $4}' |
			cut -d/ -f1
	elif command -v ifconfig >/dev/null 2>&1; then
		command ifconfig |
			awk '/inet / && $2 != "127.0.0.1" {print $2}'
	else
		printf "[mantle:error] no supported local-address command is available\n" >&2
		return 69
	fi
}

# @description Print the current public IP address.
# @exitcode 0 The address lookup completed.
# @exitcode 69 Neither dig nor curl was available.
# @exitcode * The status returned by the selected lookup command.
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

# @description Print the current local timestamp as ISO 8601 with a UTC offset.
# @stdout An ISO 8601 timestamp.
# @exitcode * The status returned by date or sed.
mantle_now_iso() {
	command date "+%Y-%m-%dT%H:%M:%S%z" |
		sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/'
}

# @description Print human-readable uptime when supported.
# @exitcode * The status returned by uptime.
mantle_pretty_uptime() {
	if command uptime --pretty >/dev/null 2>&1; then
		command uptime --pretty
	else
		command uptime
	fi
}

# @description Copy standard input to the system clipboard.
# @exitcode 69 No supported clipboard command was available.
# @exitcode * The status returned by the selected clipboard command.
mantle_set_clipboard() {
	if command -v pbcopy >/dev/null 2>&1; then
		command pbcopy
	elif command -v wl-copy >/dev/null 2>&1; then
		command wl-copy
	elif command -v xclip >/dev/null 2>&1; then
		command xclip -selection clipboard
	elif command -v xsel >/dev/null 2>&1; then
		command xsel --clipboard --input
	else
		printf "[mantle:error] no supported clipboard command is available\n" >&2
		return 69
	fi
}

# @description Print the current contents of the system clipboard.
# @exitcode 69 No supported clipboard command was available.
# @exitcode * The status returned by the selected clipboard command.
mantle_get_clipboard() {
	if command -v pbpaste >/dev/null 2>&1; then
		command pbpaste
	elif command -v wl-paste >/dev/null 2>&1; then
		command wl-paste
	elif command -v xclip >/dev/null 2>&1; then
		command xclip -selection clipboard -out
	elif command -v xsel >/dev/null 2>&1; then
		command xsel --clipboard --output
	else
		printf "[mantle:error] no supported clipboard command is available\n" >&2
		return 69
	fi
}

# @description Generate a 32-character password from operating-system entropy.
# @stdout A 32-character password followed by a newline.
# @exitcode 69 A required utility was unavailable.
# @exitcode * The status returned by the generation pipeline.
mantle_generate_password() {
	local generated_password=""

	if ! command -v base64 >/dev/null 2>&1; then
		printf "[mantle:error] base64 is required to generate a password\n" >&2
		return 69
	fi

	generated_password="$(
		command head -c 48 /dev/urandom |
			command base64 |
			tr -d "=+/\n"
	)" || return 1

	if ((${#generated_password} < 32)); then
		printf "[mantle:error] insufficient entropy output while generating a password\n" >&2
		return 1
	fi

	printf "%.32s\n" "${generated_password}"
}

# @description Send a desktop notification describing the previous command.
# @arg $1 integer Exit status of the previous command.
# @exitcode 69 notify-send was unavailable.
# @exitcode * The status returned by notify-send.
mantle_alert() {
	local previous_status="${1:-1}"
	local icon_name="error"
	local previous_command=""

	if ! command -v notify-send >/dev/null 2>&1; then
		printf "[mantle:error] notify-send is required for alert\n" >&2
		return 69
	fi

	if [[ "${previous_status}" == "0" ]]; then
		icon_name="terminal"
	fi

	previous_command="$(
		history | tail -n 1 |
			sed -E 's/^[[:space:]]*[0-9]+[[:space:]]*//; s/[;&|][[:space:]]*alert$//'
	)"

	command notify-send --urgency=low --icon="${icon_name}" "${previous_command}"
}

# @description Save the current dconf database to Mantle's configured path.
# @exitcode 64 XDG_CONFIG_HOME was unset.
# @exitcode * The status returned by dconf.
mantle_save_dconf() {
	local output_directory=""
	local output_path=""

	if [[ -z "${XDG_CONFIG_HOME:-}" ]]; then
		printf "[mantle:error] XDG_CONFIG_HOME is required to save dconf settings\n" >&2
		return 64
	fi

	output_directory="${XDG_CONFIG_HOME}/dconf"
	output_path="${output_directory}/dconf-settings.ini"
	command mkdir -p -- "${output_directory}" || return 1
	command dconf dump / >"${output_path}"
}

# @description Update supported Linux system package managers.
# @exitcode 0 Every available update operation completed successfully.
# @exitcode 69 No supported package manager was available.
# @exitcode * The status returned by the first failed update operation.
mantle_system_update() {
	local package_manager_found=0

	if command -v apt-get >/dev/null 2>&1; then
		package_manager_found=1
		command sudo apt-get update &&
			command sudo apt-get --yes upgrade &&
			command sudo apt-get --yes autoremove || return $?
	fi

	if command -v snap >/dev/null 2>&1; then
		package_manager_found=1
		command sudo snap refresh || return $?
	fi

	if command -v aptitude >/dev/null 2>&1; then
		package_manager_found=1
		command sudo aptitude --yes safe-upgrade || return $?
	fi

	if ((package_manager_found == 0)); then
		printf "[mantle:error] no supported system package manager is available\n" >&2
		return 69
	fi
}

# ─── Navigation and directory traversal ──────────────────────────────────────

alias .="pwd"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias desktop='builtin cd -- "$HOME/Desktop"'

# ─── Filesystem listing ───────────────────────────────────────────────────────

# Every historical listing style remains available under an explicit name.
# The short aliases select eza when available and otherwise use native ls.
alias ls-native="command ls"
alias ll-classic="command ls -alF"
alias la-classic="command ls -A"

if command ls --version >/dev/null 2>&1; then
	alias ls-gnu="command ls --almost-all --color=always"
	alias ll-gnu="command ls --all --human-readable --color=auto --group-directories-first --format=long"
	alias la-gnu="command ls --almost-all --human-readable --color=auto"
fi

if command -v eza >/dev/null 2>&1; then
	alias ls-eza="command eza --icons=auto --group-directories-first"
	alias ll-eza="command eza --all --long --header --group --icons=auto --git --group-directories-first"
	alias la-eza="command eza --all --icons=auto --group-directories-first"
	alias ls="command eza --icons=auto --group-directories-first"
	alias ll="command eza --all --long --header --group --icons=auto --git --group-directories-first"
	alias la="command eza --all --icons=auto --group-directories-first"
	alias l="command eza --grid --classify --icons=auto --group-directories-first"
	alias lt="command eza --tree --icons=auto --git"
	alias lss="command eza --long --header --total-size --icons=auto --sort=size"
elif command ls --version >/dev/null 2>&1; then
	alias ls="command ls --almost-all --color=always"
	alias ll="command ls --all --human-readable --color=auto --group-directories-first --format=long"
	alias la="command ls --almost-all --human-readable --color=auto"
	alias l="command ls -CF"
else
	alias ll="command ls -alF"
	alias la="command ls -A"
	alias l="command ls -CF"
fi

if command -v dir >/dev/null 2>&1; then
	alias dir="command dir --color=auto"
fi

if command -v vdir >/dev/null 2>&1; then
	alias vdir="command vdir --color=auto"
fi

# ─── File and directory management ───────────────────────────────────────────

alias cpv="command cp -v"
alias rmf="command rm -rf"
alias mkdirp="command mkdir -p"
alias touchn="command touch -c"
alias rmds="mantle_remove_ds_store_files"
alias mkcd="mantle_mkcd"

# These aliases add prompts while changing familiar command behavior, so they
# require explicit consent.
if [[ "${MANTLE_ENABLE_SAFETY_ALIASES:-0}" == "1" ]]; then
	alias cp="command cp -iv"
	alias mv="command mv -iv"
	alias rm="command rm -i"
fi

# ─── Search and text processing ───────────────────────────────────────────────

alias grep="command grep --color=auto"
alias grepv="command grep --invert-match"
alias fgrep="command grep --fixed-strings --color=auto"
alias egrep="command grep --extended-regexp --color=auto"

if command -v python3 >/dev/null 2>&1; then
	alias pretty-json="command python3 -m json.tool --sort-keys --no-ensure-ascii"
elif command -v python >/dev/null 2>&1; then
	alias pretty-json="command python -m json.tool --sort-keys --no-ensure-ascii"
fi

# Global aliases are a Zsh feature and have no Bash equivalent.
if [[ -n "${ZSH_VERSION:-}" ]]; then
	alias -g @="| grep --ignore-case"
fi

# ─── Disk, memory, and system monitoring ─────────────────────────────────────

alias dux="mantle_disk_usage_depth_one"
alias dfx="mantle_disk_free_with_type"
alias dsk="mantle_disk_summary"
alias psg="mantle_process_summary"
alias topc="mantle_top_continuous"
alias historyt="history | tail -n 50"

if command -v dust >/dev/null 2>&1; then
	alias dud="command dust --depth 1"
fi

if command -v free >/dev/null 2>&1; then
	alias mem="command free --human --total"
	alias freeh="command free --human"
fi

if command -v mount >/dev/null 2>&1 && command -v column >/dev/null 2>&1; then
	alias mounts="command mount | command column -t"
fi

# ─── Environment and shell configuration ─────────────────────────────────────

alias environment="command printenv | LC_ALL=C sort"
alias path="mantle_print_path"
alias path-sorted="mantle_print_sorted_path"
alias c="clear"
alias cls="clear"
alias reload="mantle_reload_shell"
alias man="mantle_man"
alias ascii="mantle_man ascii"

# The trailing space intentionally enables alias expansion for the command that
# follows sudo in both Bash and Zsh.
if command -v sudo >/dev/null 2>&1; then
	alias sudo="sudo "
fi

# ─── Networking and web tools ─────────────────────────────────────────────────

alias ports="mantle_list_ports"
alias ipaddr="mantle_local_ip_addresses"
alias public-ip="mantle_public_ip"

# Preserve the historical public-IP `ip` alias only where it cannot shadow the
# operating system's iproute2 command, unless legacy aliases are explicitly on.
if ! command -v ip >/dev/null 2>&1 || [[ "${MANTLE_ENABLE_LEGACY_ALIASES:-0}" == "1" ]]; then
	alias ip="mantle_public_ip"
fi

if command -v curl >/dev/null 2>&1 && [[ -n "${CURLRC:-}" ]]; then
	alias curl='command curl --config "$CURLRC"'
fi

if command -v wget >/dev/null 2>&1 && [[ -n "${XDG_DATA_HOME:-}" ]]; then
	alias wget='command wget --hsts-file="$XDG_DATA_HOME/wget-hsts" --show-progress'
fi

# ─── Time and date ────────────────────────────────────────────────────────────

alias now="command date +%Y-%m-%dT%H:%M:%S"
alias now-iso="mantle_now_iso"
alias unow="command date -u +%Y-%m-%dT%H:%M:%S"
alias nowdate="command date +%Y-%m-%d"
alias unowdate="command date -u +%Y-%m-%d"
alias nowtime="command date +%H:%M:%S"
alias unowtime="command date -u +%H:%M:%S"
alias timestamp="command date -u +%s"
alias uptime="mantle_pretty_uptime"
alias week="command date +%G-W%V"
alias weekday="command date +%u"
alias weekday-number="command date +%u"
alias weekday-name="command date +%A"
alias month="command date +%B"
alias year="command date +%Y"

# ─── Development and version control ─────────────────────────────────────────

alias clone="command git clone"
alias t="./vendor/bin/phpunit"
alias phpunit-project="./vendor/bin/phpunit"

if command -v code >/dev/null 2>&1 &&
	[[ -n "${VS_CODE_EXTENSIONS_DIR:-}" && -n "${VS_CODE_DATA_DIR:-}" ]]; then
	alias code='command code --extensions-dir "$VS_CODE_EXTENSIONS_DIR" --user-data-dir "$VS_CODE_DATA_DIR"'
fi

if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
	if command -v bashdb >/dev/null 2>&1; then
		alias bashdb='command bashdb -x "$XDG_CONFIG_HOME/bashdb/bashdbinit"'
	fi
	if command -v gdb >/dev/null 2>&1; then
		alias gdb='command gdb --nx --command="$XDG_CONFIG_HOME/gdb/init"'
	fi
	if command -v ltrace >/dev/null 2>&1; then
		alias ltrace='command ltrace -F "$XDG_CONFIG_HOME/ltrace/ltrace.conf"'
	fi
	if command -v clang-format >/dev/null 2>&1; then
		alias clang-format='command clang-format --style="file:$XDG_CONFIG_HOME/clang-format/.clang-format"'
	fi
	if command -v netbeans >/dev/null 2>&1; then
		alias netbeans='command netbeans --userdir "$XDG_CONFIG_HOME/netbeans"'
	fi
	if command -v revive >/dev/null 2>&1; then
		alias revive='command revive --config "$XDG_CONFIG_HOME/revive/revive.toml"'
	fi
	if command -v yarn >/dev/null 2>&1; then
		alias yarn='command yarn --use-yarnrc "$XDG_CONFIG_HOME/yarn/yarnrc"'
	fi
fi

if command -v emcc >/dev/null 2>&1 && [[ -n "${XDG_CONFIG_HOME:-}" && -n "${XDG_CACHE_HOME:-}" ]]; then
	alias emcc='command emcc --em-config "$XDG_CONFIG_HOME/emscripten/config" --em-cache "$XDG_CACHE_HOME/emscripten/cache"'
fi

if command -v java >/dev/null 2>&1; then
	alias java-options="command java -XX:+UnlockDiagnosticVMOptions -XX:+PrintFlagsFinal -version"
fi

if command -v mvn >/dev/null 2>&1 && [[ -n "${M2_HOME:-}" ]]; then
	alias mvn='command mvn --settings "$M2_HOME/settings.xml"'
fi

if [[ -n "${XDG_DATA_HOME:-}" ]]; then
	if command -v petite >/dev/null 2>&1; then
		alias petite='command petite --eehistory "$XDG_DATA_HOME/chezscheme/history"'
	fi
	if command -v scheme >/dev/null 2>&1; then
		alias scheme='command scheme --eehistory "$XDG_DATA_HOME/chezscheme/history"'
	fi
fi

if command -v svn >/dev/null 2>&1 && [[ -n "${SVN_CONFIG_DIR:-}" ]]; then
	alias svn='command svn --config-dir "$SVN_CONFIG_DIR"'
fi

# ─── Media, desktop, and applications ────────────────────────────────────────

if command -v abook >/dev/null 2>&1 && [[ -n "${ABOOK_RC:-}" && -n "${ABOOK_DATA:-}" ]]; then
	alias abook='command abook --config "$ABOOK_RC" --datafile "$ABOOK_DATA"'
fi

if command -v anki >/dev/null 2>&1 && [[ -n "${ANKI_DIR:-}" ]]; then
	alias anki='command anki -b "$ANKI_DIR"'
fi

if command -v claws-mail >/dev/null 2>&1 && [[ -n "${CLAWS_MAIL_CONFIG:-}" ]]; then
	alias claws-mail='command claws-mail --alternate-config-dir "$CLAWS_MAIL_CONFIG"'
fi

if command -v conky >/dev/null 2>&1 && [[ -n "${CONKY_CONFIG:-}" ]]; then
	alias conky='command conky --config "$CONKY_CONFIG"'
fi

if command -v dict >/dev/null 2>&1 && [[ -n "${DICTD_RC:-}" ]]; then
	alias dict='command dict --config "$DICTD_RC"'
fi

if command -v feh >/dev/null 2>&1; then
	alias feh="command feh --no-fehbg"
	alias photos="command feh --auto-zoom --image-bg black --randomize --recursive --scale-down ."
fi

if command -v gallery-dl >/dev/null 2>&1 && [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
	alias gallery-dl='command gallery-dl --config "$XDG_CONFIG_HOME/gallery-dl/gallery-dl.conf"'
fi

if command -v getmail >/dev/null 2>&1 &&
	[[ -n "${XDG_CONFIG_HOME:-}" && -n "${XDG_DATA_HOME:-}" ]]; then
	alias getmail='command getmail --rcfile="$XDG_CONFIG_HOME/getmail/getmailrc" --getmaildir="$XDG_DATA_HOME/getmail"'
fi

if command -v gliv >/dev/null 2>&1 && [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
	alias gliv='command gliv --glivrc="$XDG_CONFIG_HOME/gliv/glivrc"'
fi

if command -v irssi >/dev/null 2>&1 &&
	[[ -n "${XDG_CONFIG_HOME:-}" && -n "${XDG_DATA_HOME:-}" ]]; then
	alias irssi='command irssi --config="$XDG_CONFIG_HOME/irssi/config" --home="$XDG_DATA_HOME/irssi"'
fi

if command -v mbsync >/dev/null 2>&1 && [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
	alias mbsync='command mbsync -c "$XDG_CONFIG_HOME/isync/mbsyncrc"'
fi

if command -v mitmproxy >/dev/null 2>&1 && [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
	alias mitmproxy='command mitmproxy --set "confdir=$XDG_CONFIG_HOME/mitmproxy"'
fi

if command -v mitmweb >/dev/null 2>&1 && [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
	alias mitmweb='command mitmweb --set "confdir=$XDG_CONFIG_HOME/mitmproxy"'
fi

if command -v mocp >/dev/null 2>&1 && [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
	alias mocp='command mocp -M "$XDG_CONFIG_HOME/moc"'
fi

if command -v ncmpc >/dev/null 2>&1 && [[ -n "${NCMPC_CONFIG_DIR:-}" ]]; then
	alias ncmpc='command ncmpc -f "$NCMPC_CONFIG_DIR"'
fi

if command -v newsboat >/dev/null 2>&1 &&
	[[ -n "${XDG_CONFIG_HOME:-}" && -n "${XDG_CACHE_HOME:-}" ]]; then
	alias newsboat='command newsboat --url-file="$XDG_CONFIG_HOME/newsboat/urls" --cache-file="$XDG_CACHE_HOME/newsboat/cache" --config-file="$XDG_CONFIG_HOME/newsboat/config"'
fi

if command -v pidgin >/dev/null 2>&1 && [[ -n "${XDG_DATA_HOME:-}" ]]; then
	alias pidgin='command pidgin --config="$XDG_DATA_HOME/purple"'
fi

if command -v vlc >/dev/null 2>&1 && [[ -n "${VLCRC:-}" ]]; then
	alias vlc='command vlc --config "$VLCRC"'
fi

# ─── OS and platform-specific tools ──────────────────────────────────────────

if command -v adb >/dev/null 2>&1 && [[ -n "${ANDROID_USER_HOME:-}" ]]; then
	alias adb='HOME="$ANDROID_USER_HOME" command adb'
fi

if [[ "$(command uname -s)" == "Darwin" ]]; then
	if [[ -x "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" ]]; then
		alias afk='command "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" -suspend'
	fi

	alias show="command defaults write com.apple.finder AppleShowAllFiles -bool true && command killall Finder"
	alias hide="command defaults write com.apple.finder AppleShowAllFiles -bool false && command killall Finder"
	alias show-hidden-files="command defaults write com.apple.finder AppleShowAllFiles -bool true && command killall Finder"
	alias hide-hidden-files="command defaults write com.apple.finder AppleShowAllFiles -bool false && command killall Finder"
	alias spotlightoff="command sudo mdutil -a -i off"
	alias spotlighton="command sudo mdutil -a -i on"
	alias flushdns='command sudo dscacheutil -flushcache && command sudo killall -HUP mDNSResponder && printf "DNS cache flushed.\n"'
fi

if ! command -v md5sum >/dev/null 2>&1 && command -v md5 >/dev/null 2>&1; then
	alias md5sum="command md5"
fi

if ! command -v sha1sum >/dev/null 2>&1 && command -v shasum >/dev/null 2>&1; then
	alias sha1sum="command shasum --algorithm 1"
fi

if command -v nvidia-settings >/dev/null 2>&1 && [[ -n "${NVIDIA_SETTINGS_RC:-}" ]]; then
	alias nvidia-settings='command nvidia-settings --config="$NVIDIA_SETTINGS_RC"'
fi

alias setclip="mantle_set_clipboard"
alias getclip="mantle_get_clipboard"

if command -v xsel >/dev/null 2>&1 && [[ -n "${XSEL_LOGFILE:-}" ]]; then
	alias xsel='command xsel --logfile "$XSEL_LOGFILE"'
fi

if command -v xbindkeys >/dev/null 2>&1 && [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
	alias xbindkeys='command xbindkeys -f "$XDG_CONFIG_HOME/xbindkeys/config"'
fi

if command -v xrdb >/dev/null 2>&1 && [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
	alias xrdb='command xrdb -load "$XDG_CONFIG_HOME/X11/resources"'
fi

# ─── System administration and utilities ─────────────────────────────────────

alias alert='mantle_alert "$?"'

if command -v xxd >/dev/null 2>&1; then
	alias busy="command xxd /dev/urandom | command grep --color=always --line-buffered 'be ef'"
fi

alias clean="command artisan cache:clear && command artisan view:clear && command artisan clear-compiled && command artisan route:clear && command artisan config:clear && command artisan config:cache && command artisan route:cache"
alias laravel-clean="command artisan cache:clear && command artisan view:clear && command artisan clear-compiled && command artisan route:clear && command artisan config:clear && command artisan config:cache && command artisan route:cache"
alias genpass="mantle_generate_password"
alias save-dconf="mantle_save_dconf"
alias update="mantle_system_update"
alias system-update="mantle_system_update"

if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
	if command -v dosbox >/dev/null 2>&1; then
		alias dosbox='command dosbox -conf "$XDG_CONFIG_HOME/dosbox/dosbox.conf"'
	fi
	if command -v ledger >/dev/null 2>&1; then
		alias ledger='command ledger --init-file "$XDG_CONFIG_HOME/ledgerrc"'
	fi
	if command -v x2goclient >/dev/null 2>&1; then
		alias x2goclient='command x2goclient --home="$XDG_CONFIG_HOME/x2goclient"'
	fi
	if command -v xonsh >/dev/null 2>&1; then
		alias xonsh='command xonsh --rc "$XDG_CONFIG_HOME/xonsh/xonshrc"'
	fi
fi

if [[ -n "${XDG_DATA_HOME:-}" ]]; then
	if command -v keychain >/dev/null 2>&1; then
		alias keychain='command keychain --dir "$XDG_DATA_HOME/keychain"'
	fi
	if command -v minecraft >/dev/null 2>&1; then
		alias minecraft='command minecraft --workDir "$XDG_DATA_HOME/minecraft/.minecraft"'
	fi
	if command -v monerod >/dev/null 2>&1; then
		alias monerod='command monerod --data-dir "$XDG_DATA_HOME/bitmonero"'
	fi
	if command -v mysql-workbench >/dev/null 2>&1; then
		alias mysql-workbench='command mysql-workbench --configdir="$XDG_DATA_HOME/mysql/workbench"'
	fi
fi

if command -v units >/dev/null 2>&1 && [[ -n "${UNITS_HISTORY_FILE:-}" ]]; then
	alias units='command units --history "$UNITS_HISTORY_FILE"'
fi

return 0
