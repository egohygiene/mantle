if not set -q HOME; or test -z "$HOME"
    printf '[mantle:error] Fish environment requires HOME\n' >&2
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

for candidate in "$ASDF_DATA_DIR/bin" "$ASDF_DATA_DIR/shims" "$PYENV_ROOT/bin" "$VOLTA_HOME/bin" "$PIPX_BIN_DIR" "$GOPATH/bin" "$CARGO_HOME/bin" "$PNPM_HOME" "$XDG_BIN_HOME" "$MANTLE_ROOT/bin"
    test -d "$candidate"; and fish_add_path --global --move --prepend "$candidate"
end
return 0
