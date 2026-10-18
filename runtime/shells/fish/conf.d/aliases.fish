# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Native opt-in counterparts to Mantle's focused interactive alias groups.
# Legacy Fish abbreviations remain separate and retain their existing defaults.

if status is-interactive; and mantle_profile_has interactive
    if test "$MANTLE_POLICY_ALIASES_SAFE" = true
        function mantle_mkcd --description "Create a directory and enter it"
            test (count $argv) -eq 1; or return 64
            command mkdir -p -- "$argv[1]"; and builtin cd -- "$argv[1]"
        end
        function mantle_print_path --description "Print executable search paths in order"
            printf "%s\n" $PATH
        end
        function mantle_print_sorted_path --description "Print executable search paths in stable sort order"
            mantle_print_path | command env LC_ALL=C sort
        end
        function mantle_reload_shell --description "Replace this shell with a fresh login shell"
            if test -n "$SHELL"; and test -x "$SHELL"
                exec "$SHELL" --login
            end
            printf "[mantle:error] cannot reload an unavailable shell\n" >&2
            return 64
        end
        function mantle_now_iso --description "Print the local ISO timestamp including its UTC offset"
            command date "+%Y-%m-%dT%H:%M:%S%z" | command sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/'
        end
        function mantle_set_clipboard --description "Copy standard input to the system clipboard"
            if command --query pbcopy
                command pbcopy
            else if command --query wl-copy
                command wl-copy
            else if command --query xclip
                command xclip -selection clipboard
            else if command --query xsel
                command xsel --clipboard --input
            else
                printf "[mantle:error] no supported clipboard command is available\n" >&2
                return 69
            end
        end
        function mantle_get_clipboard --description "Print the system clipboard"
            if command --query pbpaste
                command pbpaste
            else if command --query wl-paste
                command wl-paste
            else if command --query xclip
                command xclip -selection clipboard -out
            else if command --query xsel
                command xsel --clipboard --output
            else
                printf "[mantle:error] no supported clipboard command is available\n" >&2
                return 69
            end
        end
        function .
            pwd
        end
        function ..
            builtin cd ..
        end
        function ...
            builtin cd ../..
        end
        function ....
            builtin cd ../../..
        end
        function mkcd
            mantle_mkcd $argv
        end
        function mkdirp
            command mkdir -p $argv
        end
        function path
            mantle_print_path $argv
        end
        function path-sorted
            mantle_print_sorted_path $argv
        end
        function reload
            mantle_reload_shell $argv
        end
        function now
            command date +%Y-%m-%dT%H:%M:%S
        end
        function now-iso
            mantle_now_iso $argv
        end
        function unow
            command date -u +%Y-%m-%dT%H:%M:%S
        end
        function nowdate
            command date +%Y-%m-%d
        end
        function timestamp
            command date -u +%s
        end
        function setclip
            mantle_set_clipboard $argv
        end
        function getclip
            mantle_get_clipboard $argv
        end
        if command --query eza
            function ll
                command eza --all --long --header --group --icons=auto --git --group-directories-first $argv
            end
            function la
                command eza --all --icons=auto --group-directories-first $argv
            end
            function l
                command eza --grid --classify --icons=auto --group-directories-first $argv
            end
        else
            function ll
                command ls -alF $argv
            end
            function la
                command ls -A $argv
            end
            function l
                command ls -CF $argv
            end
        end
        if command --query adb; and test -n "$ANDROID_USER_HOME"
            function adb
                command env HOME="$ANDROID_USER_HOME" adb $argv
            end
        end
        if command --query feh
            function feh
                command feh --no-fehbg $argv
            end
        end
    end

    if test "$MANTLE_POLICY_ALIASES_NETWORK" = true
        function mantle_list_ports --description "List listening local TCP and UDP ports"
            if command --query ss
                command ss --listening --numeric --tcp --udp
            else if command --query lsof
                command lsof -nP -iTCP -sTCP:LISTEN -iUDP
            else if command --query netstat
                command netstat -an
            else
                printf "[mantle:error] no supported port-listing command is available\n" >&2
                return 69
            end
        end
        function mantle_local_ip_addresses --description "Print non-loopback local IP addresses"
            if command hostname -I >/dev/null 2>&1
                command hostname -I | command tr " " "\n" | command sed "/^\$/d"
            else if command --query ip
                command ip -o -4 address show scope global | command awk '{print $4}' | command cut -d/ -f1
            else if command --query ifconfig
                command ifconfig | command awk '/inet / && $2 != "127.0.0.1" {print $2}'
            else
                printf "[mantle:error] no supported local-address command is available\n" >&2
                return 69
            end
        end
        function mantle_public_ip --description "Request the public IP address through DNS or HTTPS"
            if command --query dig
                command dig +short myip.opendns.com @resolver1.opendns.com
            else if command --query curl
                command curl --fail --silent --show-error https://api.ipify.org
                printf "\n"
            else
                printf "[mantle:error] dig or curl is required to resolve the public IP address\n" >&2
                return 69
            end
        end
        function ports
            mantle_list_ports $argv
        end
        function ipaddr
            mantle_local_ip_addresses $argv
        end
        function public-ip
            mantle_public_ip $argv
        end
    end

    if test "$MANTLE_POLICY_ALIASES_SYSTEM" = true
        function mantle_system_update --description "Explicitly update available system package managers"
            set -l found 0
            if test (command uname -s) = Darwin; and command --query brew
                set found 1
                command brew update; and command brew upgrade; or return $status
            end
            if command --query apt-get
                set found 1
                command sudo apt-get update; and command sudo apt-get --yes upgrade; and command sudo apt-get --yes autoremove; or return $status
            end
            if command --query snap
                set found 1
                command sudo snap refresh; or return $status
            end
            if command --query aptitude
                set found 1
                command sudo aptitude --yes safe-upgrade; or return $status
            end
            test "$found" = 1; and return 0
            printf "[mantle:error] no supported system package manager is available\n" >&2
            return 69
        end
        function system-update
            mantle_system_update $argv
        end
    end

    if test "$MANTLE_POLICY_ALIASES_SAFETY" = true
        function cp
            command cp -iv $argv
        end
        function mv
            command mv -iv $argv
        end
        function rm
            command rm -i $argv
        end
    end
end
