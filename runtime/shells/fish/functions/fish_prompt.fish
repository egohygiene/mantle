function fish_prompt --description "Display Mantle's minimal Fish prompt"
    set -l previous_status $status
    set -l prompt_color (set_color blue)
    set -l error_color (set_color red)
    set -l normal_color (set_color normal)

    printf '%s%s%s' "$prompt_color" (prompt_pwd) "$normal_color"
    if test $previous_status -ne 0
        printf ' %s[%d]%s' "$error_color" $previous_status "$normal_color"
    end

    set -l git_context (__fish_git_prompt ' (%s)' 2>/dev/null)
    test -n "$git_context"; and printf '%s' "$git_context"
    printf '\n❯ '
end
