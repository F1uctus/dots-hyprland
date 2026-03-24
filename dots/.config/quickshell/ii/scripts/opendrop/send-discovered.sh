#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/opendrop"
PEERS_FILE="${CACHE_DIR}/peers.json"

mkdir -p "$CACHE_DIR"

if ! command -v opendrop >/dev/null 2>&1; then
  notify-send "OpenDrop" "opendrop is not installed" -a "Shell"
  exit 1
fi

if [[ ! -s "$PEERS_FILE" ]]; then
  notify-send "OpenDrop" "No discovered peers yet. Enable discovery first." -a "Shell"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  notify-send "OpenDrop" "jq is required for peer selection" -a "Shell"
  exit 1
fi

peer_list="$(jq -r '.[] | "\(.index)\t\(.name)\t\(.id)"' "$PEERS_FILE" 2>/dev/null || true)"
if [[ -z "$peer_list" ]]; then
  notify-send "OpenDrop" "No discovered peers available" -a "Shell"
  exit 1
fi

selected="$(printf '%s\n' "$peer_list" | fuzzel --dmenu --prompt 'OpenDrop peer: ' --match-mode fzf || true)"
if [[ -z "$selected" ]]; then
  exit 0
fi

receiver_index="$(printf '%s' "$selected" | cut -f1)"
receiver_name="$(printf '%s' "$selected" | cut -f2)"

file_path=""
if command -v kdialog >/dev/null 2>&1; then
  file_path="$(kdialog --getopenfilename "$HOME" 2>/dev/null || true)"
elif command -v zenity >/dev/null 2>&1; then
  file_path="$(zenity --file-selection 2>/dev/null || true)"
else
  file_path="$(printf '' | fuzzel --dmenu --prompt 'Path to send: ' || true)"
fi

if [[ -z "$file_path" ]]; then
  exit 0
fi

if [[ ! -e "$file_path" ]]; then
  notify-send "OpenDrop" "Selected path does not exist: $file_path" -a "Shell"
  exit 1
fi

notify-send "OpenDrop" "Sending to ${receiver_name}..." -a "Shell"
if opendrop send -r "$receiver_index" -f "$file_path"; then
  notify-send "OpenDrop" "Sent $(basename "$file_path") to ${receiver_name}" -a "Shell"
else
  notify-send "OpenDrop" "Send failed to ${receiver_name}" -a "Shell" -u critical
  exit 1
fi
