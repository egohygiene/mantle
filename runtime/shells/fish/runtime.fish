# Mantle's canonical Fish entrypoint. Source from config.fish after setting
# MANTLE_ROOT to the absolute path of the Mantle repository.

# Wrapped in a function so that `return` works in fish < 3.4 (e.g. Ubuntu 22.04
# ships fish 3.3.1 which disallows `return` outside a function definition).
function __mantle_fish_runtime
    if set -q MANTLE_FISH_INITIALIZATION_STATE; and test "$MANTLE_FISH_INITIALIZATION_STATE" = initialized
        return 0
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

    set -g MANTLE_FISH_INITIALIZATION_STATE initializing
    set -gx MANTLE_SHELL_NAME fish
    set -gx MANTLE_INTERACTIVE 0
    status is-interactive; and set -gx MANTLE_INTERACTIVE 1
    set -l runtime_root "$MANTLE_ROOT/runtime/shells/fish"

    for directory in "$runtime_root/functions" "$runtime_root/completions"
        test -d "$directory"; or continue
        if string match --quiet '*/functions' -- "$directory"
            contains -- "$directory" $fish_function_path; or set -g --prepend fish_function_path "$directory"
        else
            contains -- "$directory" $fish_complete_path; or set -g --prepend fish_complete_path "$directory"
        end
    end

    for fragment in environment.fish privacy.fish abbreviations.fish
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

    set -g MANTLE_FISH_INITIALIZATION_STATE initialized
    return 0
end
__mantle_fish_runtime; set -l __mantle_s $status
functions --erase __mantle_fish_runtime
test $__mantle_s -eq 0
