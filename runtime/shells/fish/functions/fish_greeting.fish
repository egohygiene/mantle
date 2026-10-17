function fish_greeting --description "Render Mantle's explicitly enabled startup display"
    if not set -q MANTLE_FISH_INITIALIZATION_STATE; or test "$MANTLE_FISH_INITIALIZATION_STATE" != initialized
        return 0
    end
    status is-interactive; or return 0
    mantle_profile_has interactive; or return 0
    if not set -q MANTLE_STARTUP_DISPLAY; or test "$MANTLE_STARTUP_DISPLAY" != 1
        return 0
    end
    if command "$MANTLE_ROOT/bin/mantle" startup --check
        command "$MANTLE_ROOT/bin/mantle" startup; or true
        set -gx MANTLE_STARTUP_SHOWN 1
    end
    return 0
end
