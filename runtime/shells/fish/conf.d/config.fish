# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Native Fish adapter for Mantle's literal, versioned settings contract.
# User configuration is parsed as data and is never sourced or evaluated.

function __mantle_fish_config_suffix --argument-names setting
    switch "$setting"
        case aliases.safe
            printf "ALIASES_SAFE\n"
        case aliases.network
            printf "ALIASES_NETWORK\n"
        case aliases.system
            printf "ALIASES_SYSTEM\n"
        case aliases.legacy
            printf "ALIASES_LEGACY\n"
        case aliases.safety
            printf "ALIASES_SAFETY\n"
        case history
            printf "HISTORY\n"
        case updates.suppress_checks
            printf "SUPPRESS_UPDATE_CHECKS\n"
        case experimental
            printf "EXPERIMENTAL\n"
        case presentation
            printf "PRESENTATION\n"
        case '*'
            return 64
    end
end

function mantle_config_boolean_normalize --description "Normalize a literal Mantle boolean"
    test (count $argv) -eq 1; or return 64
    switch "$argv[1]"
        case 1 true yes on
            printf "true\n"
        case 0 false no off
            printf "false\n"
        case '*'
            return 64
    end
end

function __mantle_fish_config_normalize --argument-names suffix value
    if test "$suffix" = PRESENTATION
        contains -- "$value" private share-safe ci off; or return 64
        printf "%s\n" "$value"
    else
        set -l normalized (mantle_config_boolean_normalize "$value"); or return 64
        if test "$suffix" = EXPERIMENTAL; and test "$normalized" = true
            printf "[mantle:error] experimental behavior is unavailable\n" >&2
            return 78
        end
        printf "%s\n" "$normalized"
    end
end

function mantle_config_get_policy_value --description "Print one supported effective policy value"
    test (count $argv) -eq 1; or return 64
    contains -- "$argv[1]" ALIASES_SAFE ALIASES_NETWORK ALIASES_SYSTEM ALIASES_LEGACY ALIASES_SAFETY HISTORY SUPPRESS_UPDATE_CHECKS EXPERIMENTAL PRESENTATION; or return 64
    set -l variable "MANTLE_POLICY_$argv[1]"
    printf "%s\n" $$variable
end

function mantle_config_get_policy_source --description "Print one supported policy value's provenance"
    test (count $argv) -eq 1; or return 64
    contains -- "$argv[1]" ALIASES_SAFE ALIASES_NETWORK ALIASES_SYSTEM ALIASES_LEGACY ALIASES_SAFETY HISTORY SUPPRESS_UPDATE_CHECKS EXPERIMENTAL PRESENTATION; or return 64
    set -l variable "MANTLE_POLICY_SOURCE_$argv[1]"
    printf "%s\n" $$variable
end

function mantle_config_resolve --description "Resolve profile defaults, literal configuration, and explicit environment policy"
    set -l environment_profile "$MANTLE_PROFILE"
    if test "$MANTLE_CONFIG_RESOLVED" = 1
        if test "$MANTLE_PROFILE_SOURCE" = default; or string match --quiet "config:*" -- "$MANTLE_PROFILE_SOURCE"
            if test "$environment_profile" = "$MANTLE_PROFILE_RESOLVED_VALUE"
                set environment_profile ""
            end
        end
    end
    set -l config_path
    if test -n "$MANTLE_CONFIG_FILE"
        set config_path "$MANTLE_CONFIG_FILE"
    else if string match --quiet "/*" -- "$XDG_CONFIG_HOME"
        set config_path "$XDG_CONFIG_HOME/mantle/config.conf"
    else if string match --quiet "/*" -- "$HOME"
        set config_path "$HOME/.config/mantle/config.conf"
    else
        printf "[mantle:error] HOME must be absolute when no config path is set\n" >&2
        return 78
    end
    string match --quiet "/*" -- "$config_path"; or begin
        printf "[mantle:error] Mantle config path must be absolute\n" >&2
        return 78
    end

    set -l setting_names
    set -l suffixes
    set -l environment_names
    set -l file_values
    while read --line setting_line
        set -l fields (string split \t -- "$setting_line")
        test "$fields[1]" = setting; and continue
        test (count $fields) -eq 6; or return 78
        set -l suffix (__mantle_fish_config_suffix "$fields[1]"); or return 78
        contains -- "$fields[3]" MANTLE_ENABLE_SAFE_ALIASES MANTLE_ENABLE_NETWORK_ALIASES MANTLE_ENABLE_SYSTEM_ALIASES MANTLE_ENABLE_LEGACY_ALIASES MANTLE_ENABLE_SAFETY_ALIASES MANTLE_ENABLE_HISTORY MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS MANTLE_ENABLE_EXPERIMENTAL MANTLE_PRESENTATION_MODE; or return 78
        contains -- "$fields[1]" $setting_names; and return 78
        set --append setting_names "$fields[1]"
        set --append suffixes "$suffix"
        set --append environment_names "$fields[3]"
        set --append file_values ""
    end <"$MANTLE_ROOT/config/settings.tsv"
    test (count $suffixes) -eq 9; or return 78

    set -l file_profile ""
    set -l schema ""
    set -l config_status absent
    set -l seen_keys
    if test -e "$config_path"
        if not test -f "$config_path"; or not test -r "$config_path"
            printf "[mantle:error] configured Mantle file must be readable and regular\n" >&2
            return 66
        end
        while read --line config_line
            set config_line (string replace --regex '\r$' "" -- "$config_line")
            test -z "$config_line"; and continue
            string match --quiet "#*" -- "$config_line"; and continue
            set -l fields (string split --max 1 -- "=" "$config_line")
            if test (count $fields) -ne 2; or test -z "$fields[1]"; or string match --quiet --regex '[[:space:]]' -- "$fields[1]$fields[2]"
                printf "[mantle:error] Mantle config requires literal key=value lines without whitespace\n" >&2
                return 78
            end
            set -l key "$fields[1]"
            set -l value "$fields[2]"
            if contains -- "$key" $seen_keys
                printf "[mantle:error] duplicate Mantle config key\n" >&2
                return 78
            end
            set --append seen_keys "$key"
            switch "$key"
                case schema_version
                    set schema "$value"
                case profile
                    contains -- "$value" core interactive workstation container ci full; or begin
                        printf "[mantle:error] configured profile must name an existing Mantle base profile\n" >&2
                        return 78
                    end
                    set file_profile "$value"
                case '*'
                    set -l index (contains --index -- "$key" $setting_names)
                    if test -z "$index"
                        printf "[mantle:error] unknown Mantle config key\n" >&2
                        return 78
                    end
                    set -l normalized (__mantle_fish_config_normalize "$suffixes[$index]" "$value"); or begin
                        set -l normalization_status $status
                        if test "$normalization_status" -ne 78
                            printf "[mantle:error] invalid typed Mantle config value\n" >&2
                        end
                        return 78
                    end
                    set file_values[$index] "$normalized"
            end
        end <"$config_path"
        if test "$schema" != 1
            printf "[mantle:error] config schema_version must be 1\n" >&2
            return 78
        end
        set config_status loaded
    else if test -n "$MANTLE_CONFIG_FILE"
        printf "[mantle:error] configured Mantle config file is unavailable\n" >&2
        return 66
    end

    set -l selected_profile workstation
    set -l profile_source default
    if test -n "$file_profile"
        set selected_profile "$file_profile"
        set profile_source "config:$config_path"
    end
    if test -n "$environment_profile"
        set selected_profile "$environment_profile"
        set profile_source environment:MANTLE_PROFILE
    end
    contains -- "$selected_profile" core interactive workstation container ci full; or begin
        printf "[mantle:error] unknown Mantle profile; choose core, interactive, workstation, container, ci, or full\n" >&2
        return 64
    end
    if test "$MANTLE_FISH_INITIALIZATION_STATE" = initialized; and test "$selected_profile" != "$MANTLE_ACTIVE_PROFILE"
        printf "[mantle:error] Mantle profile cannot change after initialization; start a new shell\n" >&2
        return 78
    end
    if not test -r "$MANTLE_ROOT/config/profiles.tsv"; or not test -r "$MANTLE_ROOT/lib/core/profiles.awk"
        printf "[mantle:error] Mantle profile configuration is missing or unreadable\n" >&2
        return 64
    end
    command --query awk; or begin
        printf "[mantle:error] profile selection requires awk\n" >&2
        return 69
    end
    set -l capabilities (command awk -v selected="$selected_profile" -f "$MANTLE_ROOT/lib/core/profiles.awk" "$MANTLE_ROOT/config/profiles.tsv")
    if test "$status" -ne 0
        printf "%s\n" "$capabilities" >&2
        return 64
    end
    set -l policies
    set -l sources
    for suffix in $suffixes
        set -l index (contains --index -- "$suffix" $suffixes)
        set -l value false
        if test "$suffix" = PRESENTATION
            set value private
        else if contains -- "$suffix" ALIASES_LEGACY HISTORY; and contains -- interactive (string split : -- "$capabilities")
            set value true
        end
        set -l source "profile:$selected_profile"
        if test -n "$file_values[$index]"
            set value "$file_values[$index]"
            set source "config:$config_path"
        end
        set -l environment_name "$environment_names[$index]"
        if set --query "$environment_name"; and test -n "$$environment_name"
            set value (__mantle_fish_config_normalize "$suffix" "$$environment_name"); or begin
                set -l normalization_status $status
                if test "$normalization_status" -ne 78
                    printf "[mantle:error] invalid typed Mantle environment override\n" >&2
                end
                return 78
            end
            set source "environment:$environment_name"
        end
        set --append policies "$value"
        set --append sources "$source"
    end

    set -gx MANTLE_PROFILE "$selected_profile"
    set -gx MANTLE_ACTIVE_PROFILE "$selected_profile"
    set -gx MANTLE_PROFILE_CAPABILITIES "$capabilities"
    set -gx MANTLE_PROFILE_SOURCE "$profile_source"
    set -gx MANTLE_PROFILE_RESOLVED_VALUE "$selected_profile"
    set -gx MANTLE_CONFIG_FILE_RESOLVED "$config_path"
    set -gx MANTLE_CONFIG_FILE_STATUS "$config_status"
    set -gx MANTLE_CONFIG_SCHEMA_VERSION 1
    set -gx MANTLE_CONFIG_RESOLVED 1
    for suffix in $suffixes
        set -l index (contains --index -- "$suffix" $suffixes)
        set -gx "MANTLE_POLICY_$suffix" "$policies[$index]"
        set -g "MANTLE_POLICY_SOURCE_$suffix" "$sources[$index]"
    end
    return 0
end

function mantle_config_print_effective --description "Print typed Mantle settings with their provenance"
    printf "setting\ttype\tvalue\tsource\tapplicability\n"
    printf "profile\tprofile\t%s\t%s\tall\n" "$MANTLE_PROFILE" "$MANTLE_PROFILE_SOURCE"
    while read --line setting_line
        set -l fields (string split \t -- "$setting_line")
        test "$fields[1]" = setting; and continue
        if test (count $argv) -gt 0; and test "$argv[1]" != "$fields[1]"
            continue
        end
        set -l suffix (__mantle_fish_config_suffix "$fields[1]"); or return 78
        printf "%s\t%s\t%s\t%s\t%s\n" "$fields[1]" "$fields[2]" (mantle_config_get_policy_value "$suffix") (mantle_config_get_policy_source "$suffix") "$fields[5]"
    end <"$MANTLE_ROOT/config/settings.tsv"
end
