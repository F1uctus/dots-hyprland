#!/usr/bin/env bash
set -u

config_name="${1:-ii}"

# On runit/elogind setups DBUS_SESSION_BUS_ADDRESS may be absent while the
# user bus is available at $XDG_RUNTIME_DIR/bus.
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "${XDG_RUNTIME_DIR}/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi

have_working_dbus_session() {
    [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || return 1
    command -v dbus-send >/dev/null 2>&1 || return 1
    dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
        --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames \
        >/dev/null 2>&1
}

wait_for_pipewire() {
    [ -n "${XDG_RUNTIME_DIR:-}" ] || return 0
    local sock="${XDG_RUNTIME_DIR}/pipewire-0"
    local i
    for i in $(seq 1 50); do
        if [ -S "${sock}" ] && command -v pw-cli >/dev/null 2>&1 && pw-cli info 0 >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
    done
    return 0
}

# Ensure we do not keep stale shell instances around after reloads.
pkill -x qs >/dev/null 2>&1 || true
pkill -x quickshell >/dev/null 2>&1 || true

if [ -x /usr/local/bin/quickshell ]; then
    quickshell_cmd=(/usr/local/bin/quickshell -c "$config_name")
elif command -v quickshell >/dev/null 2>&1; then
    quickshell_cmd=(quickshell -c "$config_name")
elif command -v qs >/dev/null 2>&1; then
    quickshell_cmd=(qs -c "$config_name")
else
    notify-send "QuickShell not found" "Install quickshell/qs to start widgets." -u critical >/dev/null 2>&1 || true
    exit 1
fi

if ! have_working_dbus_session; then
    notify-send "QuickShell startup blocked" "No working D-Bus session. Start Hyprland through hyprland-start." -u critical >/dev/null 2>&1 || true
    echo "start_quickshell: no working D-Bus session; start Hyprland through hyprland-start" >&2
    exit 1
fi

wait_for_pipewire

# Optional stagger so portals/pipewire settle before Qt QuickShell runs (reduces races with
# xdg-desktop-portal teardown during Moonlight). In Hypr env: QUICKSHELL_START_DELAY_SEC=3
if [[ "${QUICKSHELL_START_DELAY_SEC:-0}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  sleep "${QUICKSHELL_START_DELAY_SEC}"
fi

exec "${quickshell_cmd[@]}"
