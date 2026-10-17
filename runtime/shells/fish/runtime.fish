# Mantle's canonical Fish entrypoint. Source from config.fish after setting
# MANTLE_ROOT to the absolute path of the Mantle repository.

# Wrapped in a function so that `return` works in fish < 3.4 (e.g. Ubuntu 22.04
# ships fish 3.3.1 which disallows `return` outside a function definition).
function __mantle_fish_runtime
    # The current invocation keeps its body after removing this private helper.
    functions --erase __mantle_fish_runtime
    set -l requested_profile workstation
    if set -q MANTLE_PROFILE; and test -n "$MANTLE_PROFILE"
        set requested_profile "$MANTLE_PROFILE"
    end
    switch "$requested_profile"
        case core interactive workstation container ci full
        case '*'
            printf '[mantle:error] unknown Mantle profile; choose core, interactive, workstation, container, ci, or full\n' >&2
            return 64
    end
    if set -q MANTLE_FISH_INITIALIZATION_STATE; and test "$MANTLE_FISH_INITIALIZATION_STATE" = initialized
        if test "$requested_profile" = "$MANTLE_ACTIVE_PROFILE"
            return 0
        end
        printf '[mantle:error] Mantle profile cannot change after initialization; start a new shell\n' >&2
        return 78
    end
    if set -q MANTLE_FISH_INITIALIZATION_STATE; and test "$MANTLE_FISH_INITIALIZATION_STATE" = initializing
        printf '[mantle:error] recursive Fish initialization detected\n' >&2
        return 70
    end
    if not set -q MANTLE_ROOT; or not string match --quiet --regex '^/' -- "$MANTLE_ROOT"; or not test -d "$MANTLE_ROOT"
        printf '[mantle:error] Fish runtime requires an absolute, readable MANTLE_ROOT\n' >&2
        set -g MANTLE_FISH_INITIALIZATION_STATE failed
        return 1
    end

    # Use the same bounded, data-only graph resolver as Bash and Zsh. No Bash
    # or Python process participates in native Fish initialization.
    if not test -r "$MANTLE_ROOT/config/profiles.tsv"; or not test -r "$MANTLE_ROOT/lib/core/profiles.awk"
        printf '[mantle:error] Mantle profile configuration is missing or unreadable\n' >&2
        return 64
    end
    if not command --query awk
        printf '[mantle:error] profile selection requires awk\n' >&2
        return 69
    end
    set -l profile_capabilities (command awk -v selected="$requested_profile" -f "$MANTLE_ROOT/lib/core/profiles.awk" "$MANTLE_ROOT/config/profiles.tsv")
    set -l profile_status $status
    if test "$profile_status" -ne 0
        printf '%s\n' "$profile_capabilities" >&2
        return 64
    end

    set -l requested_extensions
    set -l invalid_extension_selection 0
    if set -q MANTLE_EXTENSIONS; and test -n "$MANTLE_EXTENSIONS"
        if string match --quiet --regex '^[a-z][a-z0-9-]*(:[a-z][a-z0-9-]*)*$' -- "$MANTLE_EXTENSIONS"
            set requested_extensions (string split : -- "$MANTLE_EXTENSIONS")
            if test (count $requested_extensions) -gt 32
                set invalid_extension_selection 1
                set requested_extensions
            end
        else
            set invalid_extension_selection 1
        end
    end

    set -g MANTLE_FISH_INITIALIZATION_STATE initializing
    set -gx MANTLE_PROFILE "$requested_profile"
    set -gx MANTLE_ACTIVE_PROFILE "$requested_profile"
    set -gx MANTLE_PROFILE_CAPABILITIES "$profile_capabilities"
    set -gx MANTLE_SHELL_NAME fish
    set -gx MANTLE_INTERACTIVE 0
    status is-interactive; and set -gx MANTLE_INTERACTIVE 1
    set -l runtime_root "$MANTLE_ROOT/runtime/shells/fish"

    function mantle_profile_has --description "Test whether Mantle's active profile supplies a capability"
        test (count $argv) -eq 1; or return 64
        switch "$argv[1]"
            case core interactive tooling workstation container ci
            case '*'
                return 64
        end
        contains -- "$argv[1]" (string split : -- "$MANTLE_PROFILE_CAPABILITIES")
    end

    for fragment in environment.fish privacy.fish
        set -l fragment_path "$runtime_root/conf.d/$fragment"
        if not test -r "$fragment_path"
            printf '[mantle:error] missing Fish configuration fragment: %s\n' "$fragment_path" >&2
            set -g MANTLE_FISH_INITIALIZATION_STATE failed
            return 1
        end
        source "$fragment_path"; or begin
            set -l fragment_status $status
            printf '[mantle:error] Fish configuration failed with status %d: %s\n' "$fragment_status" "$fragment_path" >&2
            set -g MANTLE_FISH_INITIALIZATION_STATE failed
            return $fragment_status
        end
    end

    # The optional libraries are Bash/Zsh adapters. Record requested failures
    # without executing them or making the required Fish runtime fail.
    set -g MANTLE_LOADED_EXTENSIONS ""
    set -g MANTLE_FAILED_EXTENSIONS ""
    if test "$invalid_extension_selection" = 1
        printf '[mantle:warn] invalid MANTLE_EXTENSIONS selection; optional extensions were skipped\n' >&2
        set -g MANTLE_FAILED_EXTENSIONS invalid-selection
    end
    for extension in $requested_extensions
        set -l failed_extensions (string split : -- "$MANTLE_FAILED_EXTENSIONS")
        contains -- "$extension" $failed_extensions; and continue
        printf '[mantle:warn] optional extension %s is unsupported by the native Fish adapter\n' "$extension" >&2
        if test -n "$MANTLE_FAILED_EXTENSIONS"
            set -g MANTLE_FAILED_EXTENSIONS "$MANTLE_FAILED_EXTENSIONS:$extension"
        else
            set -g MANTLE_FAILED_EXTENSIONS "$extension"
        end
    end

    if test "$MANTLE_INTERACTIVE" = 1; and mantle_profile_has interactive
        for directory in "$runtime_root/functions" "$runtime_root/completions"
            test -d "$directory"; or continue
            if string match --quiet '*/functions' -- "$directory"
                contains -- "$directory" $fish_function_path; or set -g --prepend fish_function_path "$directory"
            else
                contains -- "$directory" $fish_complete_path; or set -g --prepend fish_complete_path "$directory"
            end
        end
        set -l fragment_path "$runtime_root/conf.d/abbreviations.fish"
        if not test -r "$fragment_path"
            printf '[mantle:error] missing Fish configuration fragment: %s\n' "$fragment_path" >&2
            set -g MANTLE_FISH_INITIALIZATION_STATE failed
            return 1
        end
        source "$fragment_path"; or begin
            set -l fragment_status $status
            printf '[mantle:error] Fish configuration failed with status %d: %s\n' "$fragment_status" "$fragment_path" >&2
            set -g MANTLE_FISH_INITIALIZATION_STATE failed
            return $fragment_status
        end
    end

    set -g MANTLE_FISH_INITIALIZATION_STATE initialized
    return 0
end
# Keep the function call last so source preserves meaningful status codes on
# Fish 3.3 as well as newer versions, which permit top-level `return`.
__mantle_fish_runtime
