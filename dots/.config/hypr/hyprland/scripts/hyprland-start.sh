#!/usr/bin/env sh
# Single entrypoint for Hyprland session startup on non-systemd setups.
# Owns D-Bus session creation to avoid nested buses and portal breakage.

set -eu

if command -v start-hyprland >/dev/null 2>&1; then
  start_hyprland_bin="start-hyprland"
else
  start_hyprland_bin=""
fi

if command -v Hyprland >/dev/null 2>&1; then
  hyprland_bin="Hyprland"
else
  hyprland_bin=""
fi

if [ -z "${hyprland_bin}" ] && [ -z "${start_hyprland_bin}" ]; then
  echo "hyprland-start: neither Hyprland nor start-hyprland was found in PATH" >&2
  exit 1
fi

export XDG_CURRENT_DESKTOP=Hyprland

# On runit/elogind setups DBUS_SESSION_BUS_ADDRESS is sometimes not exported
# even though the user bus socket exists.
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

if have_working_dbus_session; then
  [ -n "${start_hyprland_bin}" ] && exec "${start_hyprland_bin}" "$@"
  exec "${hyprland_bin}" "$@"
fi

if command -v dbus-run-session >/dev/null 2>&1; then
  [ -n "${start_hyprland_bin}" ] && exec dbus-run-session -- "${start_hyprland_bin}" "$@"
  exec dbus-run-session -- "${hyprland_bin}" "$@"
fi

echo "hyprland-start: no live D-Bus session and dbus-run-session is unavailable" >&2
exit 1
