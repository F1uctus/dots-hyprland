# This script is meant to be sourced.
# It's not for directly running.
# Void Linux (glibc): refresh xbps, add the xbps-hypr repository if missing, then
# install packages from that repo (see ~/xbps-hypr / XBPS_OVERLAY.md).
# Optional: Sunshine + SongRec from this overlay (xbps) when INSTALL_STREAMING_PKGS=true.

if ! command -v xbps-install >/dev/null 2>&1; then
  printf "${STY_RED}[$0]: xbps-install not found. This is not Void Linux.${STY_RST}\n"
  exit 1
fi

# Keep a stable existing cwd even when build dirs are removed/recreated.
x cd "${REPO_ROOT}"

configure_greetd_hyprland_default() {
  if [[ ! -f /etc/greetd/config.toml ]]; then
    return 0
  fi
  local config=/etc/greetd/config.toml
  local launcher="${HOME}/.local/bin/hyprland-start"

  if ! grep -q 'gtkgreet -l' "${config}" 2>/dev/null; then
    printf "${STY_CYAN}[$0]: Configuring greetd to use gtkgreet (Wayland sessions include Hyprland).${STY_RST}\n"
    x sudo sed -i '/^command = "agreety/s/.*/command = "gtkgreet -l"/' "${config}"
  fi

  if grep -q '^command = "start-hyprland"$' "${config}" 2>/dev/null; then
    printf "${STY_CYAN}[$0]: Pointing greetd initial_session to %s.${STY_RST}\n" "${launcher}"
    x sudo sed -i "s|^command = \"start-hyprland\"\$|command = \"${launcher}\"|" "${config}"
  fi

  if [[ ! -e /var/service/greetd ]] && [[ -d /etc/sv/greetd ]]; then
    x sudo ln -sf /etc/sv/greetd /var/service/
  fi
}

void_ensure_xbps_hypr_repo() {
  local conf=/etc/xbps.d/10-xbps-hypr.conf
  # Published HTTPS repo or local build output (override with XBPS_HYPR_REPO=...).
  local url="${XBPS_HYPR_REPO:-file://${HOME}/xbps-hypr/hostdir/binpkgs}"

  if [[ -f "${conf}" ]]; then
    printf "${STY_CYAN}[$0]: %s exists (not overwriting; adjust XBPS_HYPR_REPO or edit by hand).${STY_RST}\n" "${conf}"
    return 0
  fi

  printf "${STY_CYAN}[$0]: Adding xbps-hypr repository: %s -> %s${STY_RST}\n" "${url}" "${conf}"
  x sudo install -d /etc/xbps.d
  printf 'repository=%s\n' "${url}" | x sudo tee "${conf}" >/dev/null
}

#####################################################################################
# Refresh repodata.
v sudo xbps-install -S

case ${SKIP_SYSUPDATE:-false} in
  true) sleep 0 ;;
  *) v sudo xbps-install -Su ;;
esac

x sudo xbps-pkgdb -m unhold hyprutils 2>/dev/null || true

showfun void_ensure_xbps_hypr_repo
v void_ensure_xbps_hypr_repo

# Re-read repodata after adding a repository file.
v sudo xbps-install -S

void_dist_pkgs=(
  matugen
  bc cliphist cmake curl wget jq yq-go ripgrep xdg-user-dirs rsync xdg-utils
  kitty starship fish-shell eza
  wl-clipboard fuzzel wlogout slurp swappy wf-recorder wtype grim ImageMagick
  translate-shell libqalculate upower
  wireplumber pipewire alsa-lib libpulseaudio
  cava pavucontrol-qt playerctl libdbusmenu-gtk3 easyeffects
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-kde
  plasma-nm bluedevil polkit-kde-agent dolphin systemsettings gnome-keyring NetworkManager
  NetworkManager-openvpn NetworkManager-openconnect
  tailscale
  intel-media-driver
  geoclue2 brightnessctl ddcutil
  tesseract-ocr tesseract-ocr-eng
  gtk4 libadwaita libsoup3 libportal-gtk4 gobject-introspection
  python3-devel libffi-devel
  clang gcc ninja pkgconf
  breeze fontconfig nerd-fonts-ttf nerd-fonts-symbols-ttf
  dbus elogind seatd greetd gtkgreet
  polkit polkit-gnome
)

printf "${STY_CYAN}[$0]: Installing dependency packages (xbps).${STY_RST}\n"
v sudo xbps-install -yu "${void_dist_pkgs[@]}"

printf "${STY_CYAN}[$0]: Installing Hypr stack from xbps-hypr (xbps-hypr-meta).${STY_RST}\n"
v sudo xbps-install -yu xbps-hypr-meta

showfun configure_greetd_hyprland_default
v configure_greetd_hyprland_default

if [[ "${INSTALL_STREAMING_PKGS:-false}" == "true" ]]; then
  printf "${STY_CYAN}[$0]: Installing Sunshine + SongRec from xbps (overlay / configured repos).${STY_RST}\n"
  v sudo xbps-install -yu sunshine songrec
fi

printf "\n========================================\n"
printf "${STY_GREEN}[$0]: Void dependency step finished.${STY_RST}\n"
printf "Hyprland, companion tools, hyprpaper, XDPH, quickshell, owl, hyprshot, and\n"
printf "ydotool should come from the xbps-hypr repo (xbps-hypr-meta).\n"
printf "Sunshine + SongRec: build them in ~/xbps-hypr, then set INSTALL_STREAMING_PKGS=true\n"
printf "for this script to xbps-install them (or install xbps-hypr-streaming-meta).\n"
printf "Enable ydotoold with: sudo ln -s /etc/sv/ydotool /var/service/ (runit).\n"
printf "========================================\n"
