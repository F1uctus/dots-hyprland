#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/opendrop/receiver.lock"
mkdir -p "$(dirname "$LOCK_FILE")"

if [[ -f "$LOCK_FILE" ]]; then
  notify-send "OpenDrop" "Receiver prompt already active" -a "Shell"
  exit 0
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

if ! command -v opendrop >/dev/null 2>&1; then
  notify-send "OpenDrop" "opendrop is not installed" -a "Shell" -u critical
  exit 1
fi

action="$(notify-send "OpenDrop incoming mode" "Accept one incoming transfer?" -A "accept=Accept" -A "reject=Reject" -a "Shell" || true)"
if [[ "$action" != "accept" ]]; then
  notify-send "OpenDrop" "Incoming transfer declined" -a "Shell"
  exit 0
fi

notify-send "OpenDrop" "Waiting for one incoming transfer..." -a "Shell"
if timeout 120 opendrop receive; then
  notify-send "OpenDrop" "Incoming transfer completed" -a "Shell"
else
  notify-send "OpenDrop" "Receive timed out or failed" -a "Shell" -u critical
  exit 1
fi
