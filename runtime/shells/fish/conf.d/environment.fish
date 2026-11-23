# Wrapped in a function so that `return` works in fish < 3.4 (e.g. Ubuntu 22.04
# ships fish 3.3.1 which disallows `return` outside a function definition).
function __mantle_fish_environment
    if not set -q HOME; or test -z "$HOME"; or not string match --quiet --regex '^/' -- "$HOME"
        printf '[mantle:error] Fish environment requires an absolute HOME\n' >&2
        return 1
    end

    # Diagnostics describe this activation, not the parent shell's old paths.
    set --erase --global MANTLE_XDG_MIGRATION_WARNINGS
    function __mantle_fish_xdg_root --argument-names root_name root_value root_default
        if test -z "$root_value"
            set -gx $root_name "$root_default"
        else if not string match --quiet --regex '^/' -- "$root_value"
            printf '[mantle:warn] %s must be absolute; using %s\n' "$root_name" "$root_default" >&2
            set -gx $root_name "$root_default"
        end
    end
    __mantle_fish_xdg_root XDG_CONFIG_HOME "$XDG_CONFIG_HOME" "$HOME/.config"
    __mantle_fish_xdg_root XDG_CACHE_HOME "$XDG_CACHE_HOME" "$HOME/.cache"
    __mantle_fish_xdg_root XDG_DATA_HOME "$XDG_DATA_HOME" "$HOME/.local/share"
    __mantle_fish_xdg_root XDG_STATE_HOME "$XDG_STATE_HOME" "$HOME/.local/state"
    __mantle_fish_xdg_root XDG_BIN_HOME "$XDG_BIN_HOME" "$HOME/.local/bin"
    functions --erase __mantle_fish_xdg_root
    set -q XDG_CONFIG_DIRS; or set -gx XDG_CONFIG_DIRS /etc/xdg
    set -q XDG_DATA_DIRS; or set -gx XDG_DATA_DIRS /usr/local/share:/usr/share

    # A real, private runtime directory remains mandatory under the ordinary
    # directory-creation opt-out, matching the Bash/Zsh runtime contract.
    if test -n "$XDG_RUNTIME_DIR"; and not string match --quiet --regex '^/' -- "$XDG_RUNTIME_DIR"
        printf '[mantle:warn] XDG_RUNTIME_DIR must be absolute; selecting a secure fallback\n' >&2
        set --erase --global XDG_RUNTIME_DIR
    end
    set -l user_id (command id -u 2>/dev/null)
    if test -z "$user_id"
        printf '[mantle:error] Fish environment cannot determine the current user ID\n' >&2
        return 1
    end
    if test -z "$XDG_RUNTIME_DIR"
        if test -d "/run/user/$user_id"; and test -w "/run/user/$user_id"; and test -O "/run/user/$user_id"
            set -gx XDG_RUNTIME_DIR "/run/user/$user_id"
        else if test -n "$TMPDIR"; and string match --quiet --regex '^/' -- "$TMPDIR"; and test -d "$TMPDIR"
            set -l temporary_root (string replace --regex '/+$' '' -- "$TMPDIR")
            set -gx XDG_RUNTIME_DIR "$temporary_root/mantle-runtime-$user_id"
        else
            set -gx XDG_RUNTIME_DIR "/tmp/mantle-runtime-$user_id"
        end
    end
    if test -L "$XDG_RUNTIME_DIR"
        printf '[mantle:error] XDG_RUNTIME_DIR must not be a symbolic link: %s\n' "$XDG_RUNTIME_DIR" >&2
        return 1
    end
    if test -e "$XDG_RUNTIME_DIR"; and not test -d "$XDG_RUNTIME_DIR"
        printf '[mantle:error] XDG_RUNTIME_DIR exists but is not a directory: %s\n' "$XDG_RUNTIME_DIR" >&2
        return 1
    end
    if not test -d "$XDG_RUNTIME_DIR"
        command mkdir -p -- "$XDG_RUNTIME_DIR"; or return 1
    end
    if test -L "$XDG_RUNTIME_DIR"; or not test -O "$XDG_RUNTIME_DIR"
        printf '[mantle:error] XDG_RUNTIME_DIR must be a user-owned directory: %s\n' "$XDG_RUNTIME_DIR" >&2
        return 1
    end
    command chmod 700 "$XDG_RUNTIME_DIR"; or return 1

    set -q LANG; or set -gx LANG en_US.UTF-8

    if not set -q EDITOR
        if command -q nvim
            set -gx EDITOR nvim
        else if command -q vim
            set -gx EDITOR vim
        else
            set -gx EDITOR vi
        end
    end
    set -q VISUAL; or set -gx VISUAL "$EDITOR"

    if not set -q MANTLE_CREATE_XDG_DIRECTORIES; or test "$MANTLE_CREATE_XDG_DIRECTORIES" = 1
        command mkdir -p -- "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_BIN_HOME"; or return 1
    end

    function __mantle_fish_path_prepend --argument-names candidate
        test -n "$candidate"; or return 64
        contains -- "$candidate" $PATH; and return 0
        set -gx PATH "$candidate" $PATH
    end

    # Minimal profiles expose Mantle and user executables without activating
    # language managers or probing RubyGems during container/CI startup.
    if functions --query mantle_profile_has; and not mantle_profile_has tooling
        for candidate in "$XDG_BIN_HOME" "$MANTLE_ROOT/bin"
            if test -d "$candidate"
                __mantle_fish_path_prepend "$candidate"
            end
        end
        functions --erase __mantle_fish_path_prepend
        return 0
    end

    function __mantle_fish_record_migration_warning --argument-names variable_name
        set -l previous_warnings "$MANTLE_XDG_MIGRATION_WARNINGS"
        if contains -- "$variable_name" (string split ':' -- "$previous_warnings")
            return 0
        end
        if test -n "$previous_warnings"
            set -gx MANTLE_XDG_MIGRATION_WARNINGS "$previous_warnings:$variable_name"
        else
            set -gx MANTLE_XDG_MIGRATION_WARNINGS "$variable_name"
        end
    end

    function __mantle_fish_set_xdg --argument-names variable_name xdg_path legacy_path
        set -q $variable_name; and return 0
        if test -e "$legacy_path"; or test -L "$legacy_path"
            __mantle_fish_record_migration_warning "$variable_name"
        else
            set -gx $variable_name "$xdg_path"
        end
    end

    __mantle_fish_set_xdg CARGO_HOME "$XDG_DATA_HOME/cargo" "$HOME/.cargo"
    __mantle_fish_set_xdg ASDF_DATA_DIR "$XDG_DATA_HOME/asdf" "$HOME/.asdf"
    __mantle_fish_set_xdg RUSTUP_HOME "$XDG_DATA_HOME/rustup" "$HOME/.rustup"
    __mantle_fish_set_xdg GOPATH "$XDG_DATA_HOME/go" "$HOME/go"
    set -q PNPM_HOME; or set -gx PNPM_HOME "$XDG_DATA_HOME/pnpm"
    __mantle_fish_set_xdg PYENV_ROOT "$XDG_DATA_HOME/pyenv" "$HOME/.pyenv"
    __mantle_fish_set_xdg VOLTA_HOME "$XDG_DATA_HOME/volta" "$HOME/.volta"
    set -q PIPX_HOME; or set -gx PIPX_HOME "$XDG_DATA_HOME/pipx"
    set -q PIPX_BIN_DIR; or set -gx PIPX_BIN_DIR "$PIPX_HOME/bin"
    set -q GEM_HOME; or set -gx GEM_HOME "$XDG_DATA_HOME/gem"
    __mantle_fish_set_xdg GEM_SPEC_CACHE "$XDG_CACHE_HOME/gem/specs" "$HOME/.gem/specs"
    set -l gem_home_path "$GEM_HOME"
    set -l gem_home_absolute 1
    if not string match --quiet --regex '^/' -- "$gem_home_path"
        set gem_home_absolute 0
    end
    if test "$gem_home_path" != /
        set gem_home_path (string replace -r '/+$' '' -- "$gem_home_path")
    end

    if not set -q GEM_PATH
        if test "$gem_home_absolute" != 1
            printf '[mantle:warn] GEM_HOME must be absolute for automatic GEM_PATH management; preserving the caller-provided value\n' >&2
        else if command -q gem
            set -l gem_path_separator :
            if command -q ruby
                set -l ruby_path_separator (command ruby -e 'print File::PATH_SEPARATOR' 2>/dev/null)
                if test -n "$ruby_path_separator"
                    set gem_path_separator "$ruby_path_separator"
                end
            end
            set -l gem_path (command gem env path 2>/dev/null)
            if test -n "$gem_path"
                set -l gem_path_list (string split -- "$gem_path_separator" "$gem_path")
                set -l normalized_gem_path_list
                set -l gem_path_seen 0
                for gem_path_entry in $gem_path_list
                    set -l normalized_gem_path_entry "$gem_path_entry"
                    if test "$normalized_gem_path_entry" != /
                        set normalized_gem_path_entry (string replace -r '/+$' '' -- "$normalized_gem_path_entry")
                    end
                    set normalized_gem_path_list $normalized_gem_path_list "$normalized_gem_path_entry"
                    if test "$normalized_gem_path_entry" = "$gem_home_path"
                        set gem_path_seen 1
                    end
                end
                test "$gem_path_seen" = 1; or set normalized_gem_path_list $normalized_gem_path_list "$gem_home_path"
                set -gx GEM_PATH (string join -- "$gem_path_separator" $normalized_gem_path_list)
            else
                printf '[mantle:warn] unable to determine GEM_PATH from the active RubyGems; leaving GEM_PATH unset\n' >&2
            end
        else
            set -l ruby_manager_hint 0
            if set -q ASDF_DATA_DIR; or set -q RBENV_ROOT; or set -q MISE_DATA_DIR; or set -q MISE_INSTALL_PATH
                set ruby_manager_hint 1
            end
            if test "$ruby_manager_hint" = 1
                printf '[mantle:warn] unable to determine GEM_PATH because no active RubyGems command is available; initialize your Ruby manager first or set GEM_PATH explicitly\n' >&2
            end
        end
    end

    if test "$gem_home_absolute" = 1
        __mantle_fish_path_prepend "$gem_home_path/bin"
    else
        printf '[mantle:warn] GEM_HOME must be absolute for automatic PATH management; preserving the caller-provided value\n' >&2
    end

    set -l asdf_root "$HOME/.asdf"
    set -q ASDF_DATA_DIR; and set asdf_root "$ASDF_DATA_DIR"
    set -l pyenv_root "$HOME/.pyenv"
    set -q PYENV_ROOT; and set pyenv_root "$PYENV_ROOT"
    set -l volta_root "$HOME/.volta"
    set -q VOLTA_HOME; and set volta_root "$VOLTA_HOME"
    set -l go_root "$HOME/go"
    set -q GOPATH; and set go_root "$GOPATH"
    set -l cargo_root "$HOME/.cargo"
    set -q CARGO_HOME; and set cargo_root "$CARGO_HOME"

    for candidate in "$asdf_root/bin" "$asdf_root/shims" "$pyenv_root/bin" "$volta_root/bin" "$PIPX_BIN_DIR" "$go_root/bin" "$cargo_root/bin" "$PNPM_HOME" "$XDG_BIN_HOME" "$MANTLE_ROOT/bin"
        if test -d "$candidate"
            __mantle_fish_path_prepend "$candidate"
        end
    end
    functions --erase __mantle_fish_path_prepend __mantle_fish_set_xdg __mantle_fish_record_migration_warning
    return 0
end
__mantle_fish_environment
set -l __mantle_s $status
functions --erase __mantle_fish_environment
test $__mantle_s -eq 0
