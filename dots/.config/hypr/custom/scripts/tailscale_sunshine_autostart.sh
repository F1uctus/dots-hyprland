#!/usr/bin/env bash
# Background Tailscale connect (Headscale) with exponential backoff, then Sunshine.
# Intended for Hyprland exec-once (with trailing &). Does not block session startup.

set -u

readonly MIN_DELAY=5
readonly MAX_DELAY=600
# Headscale / self-hosted control plane: set TAILSCALE_LOGIN_SERVER (e.g. https://headscale.example.com).
# If unset, uses default Tailscale coordination (no --login-server).
readonly UP_TIMEOUT="${TAILSCALE_UP_TIMEOUT:-120}"

notify_err() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -u critical "Tailscale" "$1" 2>/dev/null || true
}

tailscale_up_once() {
  local -a args=(up --accept-routes --accept-dns)
  if [[ -n "${TAILSCALE_LOGIN_SERVER:-}" ]]; then
    args=(up --login-server "$TAILSCALE_LOGIN_SERVER" --accept-routes --accept-dns)
  fi
  if command -v timeout >/dev/null 2>&1; then
    timeout "$UP_TIMEOUT" tailscale "${args[@]}"
  else
    tailscale "${args[@]}"
  fi
}

# After reboot, Wi‑Fi/DHCP often lags Hyprland login; early `tailscale up` then fails until backoff.
# Wait for default route + a quick reachability probe (ICMP) without relying on MagicDNS.
wait_for_local_network() {
  local i
  for ((i = 0; i < 90; i++)); do
    if ip route show default 2>/dev/null | grep -q default; then
      if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 || ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; then
        return 0
      fi
    fi
    sleep 1
  done
  return 0
}

main_bg() {
  local delay=$MIN_DELAY
  local out ec

  # Retry Tailscale in the background. If we block until `tailscale up` succeeds, Sunshine never starts
  # after reboot when the operator bit / auth / control server is not ready yet.
  if command -v tailscale >/dev/null 2>&1; then
    (
      wait_for_local_network
      delay=$MIN_DELAY
      while true; do
        out="$(tailscale_up_once 2>&1)" && ec=0 || ec=$?
        if [[ "$ec" -eq 0 ]]; then
          break
        fi
        local brief="$out"
        [[ ${#brief} -gt 400 ]] && brief="${brief:0:400}…"
        local hint=
        if [[ "$out" == *'prefs write access denied'* ]] || [[ "$out" == *'--operator'* ]]; then
          hint=" Run: sudo tailscale set --operator=\$USER"
        fi
        notify_err "Tailscale failed (exit $ec), retry in ${delay}s.${hint} ${brief}"
        sleep "$delay"
        delay=$((delay * 2))
        [[ "$delay" -gt "$MAX_DELAY" ]] && delay=$MAX_DELAY
      done
    ) &
  else
    notify_err "tailscale CLI not found; install tailscale and enable tailscaled. Sunshine will still start."
  fi

  wait_for_local_network

  # Optional: env SUNSHINE_AUTOSTART_DELAY_SEC=5–15 after local network so portals settle (session loss / black video).
  local sdelay="${SUNSHINE_AUTOSTART_DELAY_SEC:-0}"
  if [[ "${sdelay}" =~ ^[0-9]+$ ]] && [[ "${sdelay}" -gt 0 ]]; then
    sleep "${sdelay}"
  fi

  local sunshine_native_wrap="${HOME}/.config/hypr/custom/scripts/sunshine_native_launch.sh"
  local sunshine_native_bin=
  if [[ -x "${sunshine_native_wrap}" ]]; then
    sunshine_native_bin="${sunshine_native_wrap}"
  elif [[ -x /usr/bin/sunshine ]]; then
    sunshine_native_bin=/usr/bin/sunshine
  elif [[ -x /usr/local/bin/sunshine ]]; then
    sunshine_native_bin=/usr/local/bin/sunshine
  fi
  if [[ -n "${sunshine_native_bin}" ]]; then
    if pgrep -x sunshine >/dev/null 2>&1; then
      return 0
    fi
    "${sunshine_native_bin}" >/dev/null 2>&1 &
    local npid=$!
    sleep 1
    if ! kill -0 "$npid" 2>/dev/null; then
      notify_err "Native Sunshine (${sunshine_native_bin}) exited right after start; check ~/.config/sunshine/sunshine.log"
    fi
    return 0
  fi

  command -v flatpak >/dev/null 2>&1 || return 0
  local app_id="dev.lizardbyte.app.Sunshine"
  flatpak list --app --columns=application 2>/dev/null | grep -qx "$app_id" || return 0
  if pgrep -f "$app_id" >/dev/null 2>&1 || pgrep -x sunshine >/dev/null 2>&1; then
    return 0
  fi
  flatpak run "$app_id" >/dev/null 2>&1 &
  local fpid=$!
  sleep 1
  if ! kill -0 "$fpid" 2>/dev/null; then
    notify_err "Sunshine exited right after start; try: flatpak run $app_id"
  fi
}

main_bg &
exit 0
