# Wrapped in a function so that `return` works in fish < 3.4 (e.g. Ubuntu 22.04
# ships fish 3.3.1 which disallows `return` outside a function definition).
function __mantle_fish_abbreviations
    status is-interactive; or return 0

    abbr --add -- g git
    abbr --add -- ga 'git add'
    abbr --add -- gc 'git commit'
    abbr --add -- gco 'git checkout'
    abbr --add -- gd 'git diff'
    abbr --add -- gf 'git fetch'
    abbr --add -- gm 'git pull --ff-only'
    abbr --add -- gp 'git push'
    abbr --add -- gr 'git rebase FETCH_HEAD'
    abbr --add -- gs 'git status'
    abbr --add -- ll 'ls -lhA'
    return 0
end
__mantle_fish_abbreviations; set -l __mantle_s $status
functions --erase __mantle_fish_abbreviations
test $__mantle_s -eq 0
