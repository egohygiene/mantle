# Wrapped in a function so that `return` works in fish < 3.4 (e.g. Ubuntu 22.04
# ships fish 3.3.1 which disallows `return` outside a function definition).
function __mantle_fish_environment
    function __mantle_fish_path_prepend --argument-names candidate
        test -n "$candidate"; or return 64
        string match --quiet --regex ':' -- "$candidate"; and return 64
        contains -- "$candidate" $PATH; and return 0
        set -gx PATH "$candidate" $PATH
    end

    if not set -q HOME; or test -z "$HOME"
        printf '[mantle:error] Fish environment requires HOME\n' >&2
        functions --erase __mantle_fish_path_prepend
        return 1
    end

    set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME "$HOME/.config"
    set -q XDG_CACHE_HOME; or set -gx XDG_CACHE_HOME "$HOME/.cache"
    set -q XDG_DATA_HOME; or set -gx XDG_DATA_HOME "$HOME/.local/share"
    set -q XDG_STATE_HOME; or set -gx XDG_STATE_HOME "$HOME/.local/state"
    set -q XDG_BIN_HOME; or set -gx XDG_BIN_HOME "$HOME/.local/bin"
    set -q XDG_CONFIG_DIRS; or set -gx XDG_CONFIG_DIRS /etc/xdg
    set -q XDG_DATA_DIRS; or set -gx XDG_DATA_DIRS /usr/local/share /usr/share
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

    set -q CARGO_HOME; or set -gx CARGO_HOME "$XDG_DATA_HOME/cargo"
    set -q ASDF_DATA_DIR; or set -gx ASDF_DATA_DIR "$XDG_DATA_HOME/asdf"
    set -q RUSTUP_HOME; or set -gx RUSTUP_HOME "$XDG_DATA_HOME/rustup"
    set -q GOPATH; or set -gx GOPATH "$XDG_DATA_HOME/go"
    set -q PNPM_HOME; or set -gx PNPM_HOME "$XDG_DATA_HOME/pnpm"
    set -q PYENV_ROOT; or set -gx PYENV_ROOT "$XDG_DATA_HOME/pyenv"
    set -q VOLTA_HOME; or set -gx VOLTA_HOME "$XDG_DATA_HOME/volta"
    set -q PIPX_HOME; or set -gx PIPX_HOME "$XDG_DATA_HOME/pipx"
    set -q PIPX_BIN_DIR; or set -gx PIPX_BIN_DIR "$PIPX_HOME/bin"
    set -q GEM_HOME; or set -gx GEM_HOME "$XDG_DATA_HOME/gem"
    set -q GEM_SPEC_CACHE; or set -gx GEM_SPEC_CACHE "$XDG_CACHE_HOME/gem/specs"
    set -l gem_home_path "$GEM_HOME"
    if test "$gem_home_path" != /
        set gem_home_path (string replace -r '/+$' '' -- "$gem_home_path")
    end

    if not set -q GEM_PATH
        if command -q gem
            set -l gem_path (command gem env path 2>/dev/null)
            if test -n "$gem_path"
                set -l gem_path_list (string split : -- "$gem_path")
                contains -- "$GEM_HOME" $gem_path_list; or set gem_path_list $gem_path_list "$GEM_HOME"
                set -gx GEM_PATH (string join : -- $gem_path_list)
            else
                printf '[mantle:warn] unable to determine GEM_PATH from the active RubyGems; leaving GEM_PATH unset\n' >&2
            end
        else if set -q ASDF_DATA_DIR; or set -q RBENV_ROOT; or set -q MISE_DATA_DIR; or set -q MISE_INSTALL_PATH
            printf '[mantle:warn] unable to determine GEM_PATH because no active RubyGems command is available; initialize your Ruby manager first or set GEM_PATH explicitly\n' >&2
        end
    end

    if string match --quiet --regex '^/' -- "$gem_home_path"
        __mantle_fish_path_prepend "$gem_home_path/bin"; or begin
            printf '[mantle:error] invalid RubyGems PATH candidate: %s\n' "$gem_home_path/bin" >&2
            functions --erase __mantle_fish_path_prepend
            return 1
        end
    end

    for candidate in "$ASDF_DATA_DIR/bin" "$ASDF_DATA_DIR/shims" "$PYENV_ROOT/bin" "$VOLTA_HOME/bin" "$PIPX_BIN_DIR" "$GOPATH/bin" "$CARGO_HOME/bin" "$PNPM_HOME" "$XDG_BIN_HOME" "$MANTLE_ROOT/bin"
        test -d "$candidate"; and __mantle_fish_path_prepend "$candidate"; or true
    end
    functions --erase __mantle_fish_path_prepend
    return 0
end
__mantle_fish_environment; set -l __mantle_s $status
functions --erase __mantle_fish_environment
test $__mantle_s -eq 0
