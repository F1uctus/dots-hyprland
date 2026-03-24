# Auto start Hyprland on tty1
if test -z "$DISPLAY" ;and test "$XDG_VTNR" -eq 1
    mkdir -p ~/.cache
    # hyprland-start is the single outer launcher and D-Bus owner.
    exec ~/.local/bin/hyprland-start > ~/.cache/hyprland.log 2>&1
end
