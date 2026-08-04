function abbrex --description "Expand a Fish abbreviation"
    if test (count $argv) -eq 0
        return 0
    end
    set -l expansion (abbr --show $argv[1] 2>/dev/null | string replace --regex '^abbr .+ -- .+ ' '' | string trim --chars "'")
    if test -n "$expansion"
        printf '%s' "$expansion"
        for argument in $argv[2..]
            printf ' %s' (string escape -- "$argument")
        end
        printf '\n'
    else
        string join ' ' -- $argv
    end
end
