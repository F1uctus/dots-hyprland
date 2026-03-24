# Auto start Hyprland on tty1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
  mkdir -p ~/.cache
  # hyprland-start is the single outer launcher and D-Bus owner.
  exec ~/.local/bin/hyprland-start > ~/.cache/hyprland.log 2>&1
fi
