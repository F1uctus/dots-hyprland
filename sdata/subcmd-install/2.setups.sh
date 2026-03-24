# This script is meant to be sourced.
# It's not for directly running.

function prepare_systemd_user_service(){
  if [[ ! -e "/usr/lib/systemd/user/ydotool.service" ]]; then
    x sudo ln -s /usr/lib/systemd/{system,user}/ydotool.service
  fi
}

function setup_user_group(){
  if [[ -z $(getent group i2c) ]] && [[ "$OS_GROUP_ID" != "fedora" ]]; then
    # On Fedora this is not needed. Tested with desktop computer with NVIDIA video card.
    x sudo groupadd i2c
  fi

  # Add user to all relevant local-control groups that exist on this distro.
  # This keeps behavior consistent across distros/reinstalls.
  local desired_groups=(wheel sudo video input audio network storage plugdev users bluetooth _seatd adm i2c)
  local existing_groups=()
  local g
  for g in "${desired_groups[@]}"; do
    if getent group "$g" >/dev/null 2>&1; then
      existing_groups+=("$g")
    fi
  done
  if [[ ${#existing_groups[@]} -gt 0 ]]; then
    x sudo usermod -aG "$(IFS=,; echo "${existing_groups[*]}")" "$(whoami)"
  fi
}

function setup_passwordless_root_for_f1uctus(){
  v bash -c "echo 'f1uctus ALL=(ALL:ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/00-f1uctus-nopasswd >/dev/null"
  v sudo chmod 0440 /etc/sudoers.d/00-f1uctus-nopasswd
  v sudo visudo -cf /etc/sudoers.d/00-f1uctus-nopasswd

  v sudo mkdir -p /etc/polkit-1/rules.d
  v bash -c "cat <<'EOF' | sudo tee /etc/polkit-1/rules.d/49-f1uctus-no-password.rules >/dev/null
polkit.addRule(function(action, subject) {
    if (subject.user == \"f1uctus\") {
        return polkit.Result.YES;
    }
});
EOF"
  v sudo chmod 0644 /etc/polkit-1/rules.d/49-f1uctus-no-password.rules
}

function setup_material_symbols_font_for_user(){
  if fc-list | grep -q "Material Symbols Rounded"; then
    return 0
  fi

  local fonts_dir="${HOME}/.local/share/fonts"
  v mkdir -p "${fonts_dir}"

  if command -v curl >/dev/null 2>&1; then
    v curl -fL "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf" -o "${fonts_dir}/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
    v curl -fL "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL,GRAD,opsz,wght%5D.ttf" -o "${fonts_dir}/MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].ttf"
  elif command -v wget >/dev/null 2>&1; then
    v wget -qO "${fonts_dir}/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf" "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
    v wget -qO "${fonts_dir}/MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].ttf" "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL,GRAD,opsz,wght%5D.ttf"
  else
    printf "${STY_YELLOW}[$0]: Neither curl nor wget found. Skipping Material Symbols font bootstrap.${STY_RST}\n"
    return 0
  fi

  v fc-cache -f "${fonts_dir}"
}

function setup_yandex_music_flatpak_for_system(){
  if ! command -v flatpak >/dev/null 2>&1; then
    return 0
  fi

  # Use the maintained Linux Yandex Music client from Flathub.
  local app_id="space.rirusha.Cassette"
  if flatpak list --system --app --columns=application | grep -qx "${app_id}"; then
    return 0
  fi

  if ! flatpak remotes --system --columns=name | grep -qx "flathub"; then
    v sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  v sudo flatpak install -y flathub "${app_id}"
}

function setup_sunshine_flatpak_for_user(){
  if ! command -v flatpak >/dev/null 2>&1; then
    printf "${STY_YELLOW}[$0]: flatpak not found. Skipping Sunshine setup.${STY_RST}\n"
    return 0
  fi

  local app_id="dev.lizardbyte.app.Sunshine"
  if ! flatpak remotes --columns=name | rg -qx "flathub"; then
    v flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  if ! flatpak list --app --columns=application | rg -qx "${app_id}"; then
    v flatpak install -y flathub "${app_id}"
  fi

  # Hyprland starts Tailscale + Sunshine via execs.conf (tailscale_sunshine_autostart.sh).
  # Remove legacy autostart that launched Sunshine without Tailscale.
  v rm -f "${HOME}/.config/autostart/sunshine.desktop"
  local repo_script="${REPO_ROOT:-}/dots/.config/hypr/custom/scripts/tailscale_sunshine_autostart.sh"
  local launch_src="${REPO_ROOT:-}/dots/.config/hypr/custom/scripts/sunshine_native_launch.sh"
  local script_dir="${HOME}/.config/hypr/custom/scripts"
  local script_path="${script_dir}/tailscale_sunshine_autostart.sh"
  if [[ -f "$repo_script" ]]; then
    v mkdir -p "${script_dir}"
    v install -m0755 "$repo_script" "$script_path"
  fi
  if [[ -f "${launch_src}" ]]; then
    v mkdir -p "${script_dir}"
    v install -m0755 "${launch_src}" "${script_dir}/sunshine_native_launch.sh"
  fi

  # uinput: default perms are root-only; Sunshine cannot inject kb/mouse without this.
  local udev_src="${REPO_ROOT:-}/sdata/assets/udev/99-sunshine-uinput.rules"
  local udev_dst="/etc/udev/rules.d/99-sunshine-uinput.rules"
  if [[ -f "$udev_src" ]] && command -v sudo >/dev/null 2>&1; then
    v sudo mkdir -p /etc/udev/rules.d
    v sudo install -m0644 "$udev_src" "$udev_dst"
    v sudo udevadm control --reload-rules
    v sudo udevadm trigger -c add /dev/uinput 2>/dev/null || v sudo udevadm trigger
  fi

  # Hardware encode inside Flatpak: NVENC (NVIDIA) vs VAAPI (Intel/AMD) vs libx264 fallback.
  # Sunshine is typically a system Flatpak; overrides need sudo.
  #
  # Hybrid laptops: if org.freedesktop.Platform.GL.nvidia-* is installed, set FLATPAK_GL_DRIVER
  # and LD_LIBRARY_PATH=.../GL/<driver>/lib so the dynamic linker finds libcuda before FFmpeg
  # initializes NVENC (FLATPAK_GL_DRIVER alone can still yield CUDA_ERROR_UNKNOWN). Unset Intel
  # LIBVA_* vars so they do not override NVIDIA VAAPI fallback.
  #
  # Intel-only: LIBVA_DRIVER_NAME=iHD + LIBVA_DRIVERS_PATH (iHD lives under intel-vaapi-driver/).
  local rt_branch
  rt_branch="$(flatpak info --show-runtime "${app_id}" 2>/dev/null | awk -F/ '{print $NF}')"
  local nvidia_gl_id
  nvidia_gl_id="$(flatpak list --runtime --columns=application 2>/dev/null | rg 'org\.freedesktop\.Platform\.GL\.nvidia-' | head -1 || true)"
  local flatpak_gl_driver=""
  if [[ -n "${nvidia_gl_id}" ]]; then
    flatpak_gl_driver="${nvidia_gl_id#org.freedesktop.Platform.GL.}"
  fi

  if [[ -n "${rt_branch}" ]]; then
    flatpak install -y flathub "org.freedesktop.Platform.VAAPI.Intel//${rt_branch}" 2>/dev/null || true
    if [[ -n "${flatpak_gl_driver}" ]]; then
      flatpak install -y flathub "org.freedesktop.Platform.VAAPI.nvidia//${rt_branch}" 2>/dev/null || true
    fi
  fi

  if command -v sudo >/dev/null 2>&1; then
    if [[ -n "${flatpak_gl_driver}" ]]; then
      v sudo flatpak override --system \
        --unset-env=LIBVA_DRIVER_NAME \
        --unset-env=LIBVA_DRIVERS_PATH \
        --env="FLATPAK_GL_DRIVER=${flatpak_gl_driver}" \
        --env="LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/GL/${flatpak_gl_driver}/lib" \
        --env=NVIDIA_DRIVER_CAPABILITIES=all,video,compute,utility \
        --env=NVIDIA_VISIBLE_DEVICES=all \
        "${app_id}"
    else
      v sudo flatpak override --system \
        --env=LIBVA_DRIVER_NAME=iHD \
        --env=LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri/intel-vaapi-driver \
        --env=NVIDIA_DRIVER_CAPABILITIES=all,video,compute,utility \
        --env=NVIDIA_VISIBLE_DEVICES=all \
        "${app_id}"
    fi
  fi

  # Default sunshine.conf when missing/empty: NVENC if NVIDIA GL extension present, else Intel VAAPI template.
  local sunshine_conf_dst="${HOME}/.var/app/${app_id}/config/sunshine/sunshine.conf"
  local sunshine_conf_repo="${REPO_ROOT:-}/sdata/assets/sunshine/sunshine-hyprland-vaapi.conf"
  if [[ -n "${flatpak_gl_driver}" && -f "${REPO_ROOT:-}/sdata/assets/sunshine/sunshine-hyprland-nvenc.conf" ]]; then
    sunshine_conf_repo="${REPO_ROOT:-}/sdata/assets/sunshine/sunshine-hyprland-nvenc.conf"
  elif [[ "${SUNSHINE_USE_KMS_CAPTURE:-false}" == "true" ]] && [[ -f "${REPO_ROOT:-}/sdata/assets/sunshine/sunshine-hyprland-vaapi-kms.conf" ]]; then
    sunshine_conf_repo="${REPO_ROOT:-}/sdata/assets/sunshine/sunshine-hyprland-vaapi-kms.conf"
  fi
  if [[ -f "${sunshine_conf_repo}" ]]; then
    v mkdir -p "$(dirname "${sunshine_conf_dst}")"
    if [[ ! -s "${sunshine_conf_dst}" ]]; then
      v install -m0600 "${sunshine_conf_repo}" "${sunshine_conf_dst}"
    fi
  fi

  # Native Sunshine (xbps package /usr/bin/sunshine or legacy /usr/local build) uses ~/.config/sunshine/, not Flatpak paths.
  local sunshine_conf_native="${HOME}/.config/sunshine/sunshine.conf"
  local sunshine_nvenc_repo="${REPO_ROOT:-}/sdata/assets/sunshine/sunshine-hyprland-nvenc.conf"
  local sunshine_vaapi_repo="${REPO_ROOT:-}/sdata/assets/sunshine/sunshine-hyprland-vaapi.conf"
  if [[ "${SUNSHINE_USE_KMS_CAPTURE:-false}" == "true" ]] && [[ -f "${REPO_ROOT:-}/sdata/assets/sunshine/sunshine-hyprland-vaapi-kms.conf" ]]; then
    sunshine_vaapi_repo="${REPO_ROOT:-}/sdata/assets/sunshine/sunshine-hyprland-vaapi-kms.conf"
  fi
  local native_use_nvenc=false
  if [[ -f "${sunshine_nvenc_repo}" ]]; then
    if [[ -n "${flatpak_gl_driver}" ]]; then
      native_use_nvenc=true
    elif command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L &>/dev/null; then
      native_use_nvenc=true
    fi
  fi
  if [[ -x /usr/bin/sunshine ]] || [[ -x /usr/local/bin/sunshine ]]; then
    v mkdir -p "$(dirname "${sunshine_conf_native}")"
    if [[ "${SUNSHINE_USE_RELIABLE_ENCODER:-false}" == "true" ]] || [[ "${SUNSHINE_NATIVE_ENCODER:-}" == "reliable" ]]; then
      # Intel VAAPI encode + H.264-first: avoids broken native NVENC when cuInit returns CUDA_ERROR_UNKNOWN.
      if [[ -f "${sunshine_vaapi_repo}" ]]; then
        if [[ -s "${sunshine_conf_native}" ]]; then
          v cp -a "${sunshine_conf_native}" "${sunshine_conf_native}.bak.$(date +%Y%m%d%H%M%S)"
        fi
        printf "${STY_CYAN}[$0]: Native Sunshine: installing reliable VAAPI config (encoder=vaapi; SUNSHINE_USE_KMS_CAPTURE for capture=kms).${STY_RST}\n"
        v install -m0600 "${sunshine_vaapi_repo}" "${sunshine_conf_native}"
      fi
    elif [[ "${native_use_nvenc}" == true ]]; then
      # First-time seed OR fix mistaken VAAPI template: setup only copied nvenc when the file was empty,
      # so an older vaapi.conf survives forever and Sunshine keeps using Intel encode after native install.
      if [[ ! -s "${sunshine_conf_native}" ]]; then
        v install -m0600 "${sunshine_nvenc_repo}" "${sunshine_conf_native}"
      elif grep -qiE '^[[:space:]]*encoder[[:space:]]*=[[:space:]]*vaapi([[:space:]]|$|#)' "${sunshine_conf_native}"; then
        printf "${STY_YELLOW}[$0]: Native Sunshine + NVIDIA: %s still had encoder=vaapi; installing NVENC template (timestamped .bak).${STY_RST}\n" "${sunshine_conf_native}"
        v cp -a "${sunshine_conf_native}" "${sunshine_conf_native}.bak.$(date +%Y%m%d%H%M%S)"
        v install -m0600 "${sunshine_nvenc_repo}" "${sunshine_conf_native}"
      fi
    elif [[ ! -s "${sunshine_conf_native}" ]] && [[ -f "${sunshine_vaapi_repo}" ]]; then
      v install -m0600 "${sunshine_vaapi_repo}" "${sunshine_conf_native}"
    fi
  fi

  # Stock Sunshine apps.json includes "Low Res Desktop" with X11 xrandr on HDMI-1 — fails on Hyprland/Wayland.
  local apps_hypr="${REPO_ROOT:-}/sdata/assets/sunshine/apps-hyprland.json"
  if [[ -f "${apps_hypr}" ]] && { [[ -x /usr/bin/sunshine ]] || [[ -x /usr/local/bin/sunshine ]]; }; then
    local apps_native="${HOME}/.config/sunshine/apps.json"
    if [[ "${SUNSHINE_REFRESH_APPS_JSON:-false}" == "true" ]] || [[ ! -s "${apps_native}" ]] || grep -qF 'xrandr' "${apps_native}" 2>/dev/null; then
      v mkdir -p "$(dirname "${apps_native}")"
      if [[ -s "${apps_native}" ]]; then
        v cp -a "${apps_native}" "${apps_native}.bak.$(date +%Y%m%d%H%M%S)"
      fi
      printf "${STY_CYAN}[$0]: Installing Hyprland-friendly Sunshine apps.json (Desktop + Steam; no xrandr).${STY_RST}\n"
      v install -m0644 "${apps_hypr}" "${apps_native}"
    fi
  fi
  if [[ -f "${apps_hypr}" ]] && flatpak list --app --columns=application 2>/dev/null | grep -qx "${app_id}"; then
    local apps_flat="${HOME}/.var/app/${app_id}/config/sunshine/apps.json"
    if [[ "${SUNSHINE_REFRESH_APPS_JSON:-false}" == "true" ]] || [[ ! -s "${apps_flat}" ]] || grep -qF 'xrandr' "${apps_flat}" 2>/dev/null; then
      v mkdir -p "$(dirname "${apps_flat}")"
      if [[ -s "${apps_flat}" ]]; then
        v cp -a "${apps_flat}" "${apps_flat}.bak.$(date +%Y%m%d%H%M%S)"
      fi
      printf "${STY_CYAN}[$0]: Installing Hyprland-friendly Sunshine apps.json for Flatpak.${STY_RST}\n"
      v install -m0644 "${apps_hypr}" "${apps_flat}"
    fi
  fi

  # Sunshine defaults to origin_web_ui_allowed=lan; Tailscale / phone browsers then fail pairing or PIN flows.
  if [[ -f "${sunshine_conf_dst}" ]] && ! grep -qiE '^[[:space:]]*origin_web_ui_allowed[[:space:]]*=' "${sunshine_conf_dst}"; then
    printf '\n# Dotfiles: pairing from Tailscale / non-LAN clients\norigin_web_ui_allowed = wan\n' >> "${sunshine_conf_dst}"
  fi
  if [[ -f "${sunshine_conf_native}" ]] && ! grep -qiE '^[[:space:]]*origin_web_ui_allowed[[:space:]]*=' "${sunshine_conf_native}"; then
    printf '\n# Dotfiles: pairing from Tailscale / non-LAN clients\norigin_web_ui_allowed = wan\n' >> "${sunshine_conf_native}"
  fi
}

function setup_rquickshare_for_user(){
  # rquickshare is not packaged on all distros (e.g. Void), so install AppImage for user.
  local appimage_url_main="https://github.com/Martichou/rquickshare/releases/download/v0.11.5/r-quick-share-main_v0.11.5_glibc-2.39_amd64.AppImage"
  local appimage_url_legacy="https://github.com/Martichou/rquickshare/releases/download/v0.11.5/r-quick-share-legacy_v0.11.5_glibc-2.31_amd64.AppImage"
  local bin_dir="${HOME}/.local/bin"
  local appimage_path="${bin_dir}/rquickshare.AppImage"
  local wrapper_path="${bin_dir}/rquickshare"
  local desktop_dir="${HOME}/.local/share/applications"
  local desktop_path="${desktop_dir}/rquickshare.desktop"

  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    printf "${STY_YELLOW}[$0]: Neither curl nor wget found. Skipping rquickshare install.${STY_RST}\n"
    return 0
  fi

  v mkdir -p "${bin_dir}" "${desktop_dir}"
  if command -v curl >/dev/null 2>&1; then
    if ! v curl -fL "${appimage_url_main}" -o "${appimage_path}"; then
      v curl -fL "${appimage_url_legacy}" -o "${appimage_path}"
    fi
  else
    if ! v wget -qO "${appimage_path}" "${appimage_url_main}"; then
      v wget -qO "${appimage_path}" "${appimage_url_legacy}"
    fi
  fi
  v chmod +x "${appimage_path}"

  v bash -c "cat <<'EOF' > '${wrapper_path}'
#!/usr/bin/env bash
exec \"\${HOME}/.local/bin/rquickshare.AppImage\" \"\$@\"
EOF"
  v chmod +x "${wrapper_path}"

  v bash -c "cat <<'EOF' > '${desktop_path}'
[Desktop Entry]
Type=Application
Name=RQuickShare
Comment=Nearby Share / Quick Share for Linux
Exec=${HOME}/.local/bin/rquickshare
Icon=network-wireless
Terminal=false
Categories=Network;FileTransfer;Utility;
StartupNotify=true
EOF"
}

function setup_cursor_appimage_for_user(){
  # Keep Cursor AppImage in a stable per-user app directory.
  local install_dir="${HOME}/.local/opt/cursor"
  local appimage_path="${install_dir}/Cursor.AppImage"
  local bin_dir="${HOME}/.local/bin"
  local wrapper_path="${bin_dir}/cursor"
  local desktop_dir="${HOME}/.local/share/applications"
  local desktop_path="${desktop_dir}/cursor.desktop"
  local appimage_url="https://downloads.cursor.com/production/linux/x64/Cursor.AppImage"

  v mkdir -p "${install_dir}" "${bin_dir}" "${desktop_dir}"

  # Download Cursor only when it is missing from the install directory.
  if [[ ! -f "${appimage_path}" ]]; then
    if command -v curl >/dev/null 2>&1; then
      v curl -fL "${appimage_url}" -o "${appimage_path}"
    elif command -v wget >/dev/null 2>&1; then
      v wget -qO "${appimage_path}" "${appimage_url}"
    else
      printf "${STY_YELLOW}[$0]: Neither curl nor wget found. Skipping Cursor AppImage download.${STY_RST}\n"
      return 0
    fi
  fi

  # If AppImage exists in install dir, wire launcher + desktop entry.
  if [[ -f "${appimage_path}" ]]; then
    v chmod +x "${appimage_path}"
    v bash -c "cat <<'EOF' > '${wrapper_path}'
#!/usr/bin/env bash
exec \"\${HOME}/.local/opt/cursor/Cursor.AppImage\" \"\$@\"
EOF"
    v chmod +x "${wrapper_path}"

    v bash -c "cat <<'EOF' > '${desktop_path}'
[Desktop Entry]
Type=Application
Name=Cursor
Comment=AI-first code editor
Exec=${HOME}/.local/bin/cursor --no-sandbox %U
Icon=cursor
Terminal=false
Categories=Development;IDE;TextEditor;
StartupNotify=true
MimeType=text/plain;inode/directory;
EOF"
  fi
}

function setup_amnezia_vpn_for_system(){
  local amnezia_gui_cmd=""
  local c
  for c in AmneziaVPN amnezia-vpn amnezia; do
    if command -v "$c" >/dev/null 2>&1; then
      amnezia_gui_cmd="$c"
      break
    fi
  done

  # Install AmneziaVPN when possible, but do not hard-fail when package names differ by distro/repo.
  if [[ -z "${amnezia_gui_cmd}" ]]; then
    case "${OS_GROUP_ID}" in
      arch)
        if command -v yay >/dev/null 2>&1; then
          local arch_pkg
          for arch_pkg in amnezia-vpn-bin amnezia-vpn; do
            if yay -Si "${arch_pkg}" >/dev/null 2>&1; then
              v yay -S --needed --noconfirm "${arch_pkg}"
              break
            fi
          done
        fi
        ;;
      fedora)
        local fedora_pkg
        for fedora_pkg in amnezia-vpn amneziavpn; do
          if dnf list --available "${fedora_pkg}" >/dev/null 2>&1; then
            v sudo dnf install -y "${fedora_pkg}"
            break
          fi
        done
        ;;
      void)
        local void_pkg
        for void_pkg in amnezia-vpn amneziavpn; do
          if xbps-query -Rs "^${void_pkg}$" >/dev/null 2>&1; then
            v sudo xbps-install -y "${void_pkg}"
            break
          fi
        done
        ;;
    esac
  fi

  # Refresh detection after optional install attempt.
  if [[ -z "${amnezia_gui_cmd}" ]]; then
    for c in AmneziaVPN amnezia-vpn amnezia; do
      if command -v "$c" >/dev/null 2>&1; then
        amnezia_gui_cmd="$c"
        break
      fi
    done
  fi

  if [[ -z "${amnezia_gui_cmd}" ]]; then
    printf "${STY_YELLOW}[$0]: AmneziaVPN client binary was not found and no known package is available. Skipping VPN setup.${STY_RST}\n"
    return 0
  fi

  # Void/runit: enable and start matching service under /etc/sv.
  if [[ "${OS_GROUP_ID}" == "void" ]] && [[ -d /etc/sv ]] && [[ -d /var/service ]]; then
    local runit_sv=()
    local runit_name
    while IFS= read -r runit_name; do
      [[ -n "${runit_name}" ]] && runit_sv+=("${runit_name}")
    done < <(ls -1 /etc/sv 2>/dev/null | rg -i 'amnezia|amneziawg|awg')

    if [[ ${#runit_sv[@]} -eq 0 ]]; then
      printf "${STY_YELLOW}[$0]: AmneziaVPN is installed, but no Amnezia-related runit service was found under /etc/sv.${STY_RST}\n"
      return 0
    fi

    local preferred_runit_sv=(amnezia-vpn amnezia-vpn-service amneziavpn amneziawg awg)
    local runit_to_enable="${runit_sv[0]}"
    local preferred
    local existing
    for preferred in "${preferred_runit_sv[@]}"; do
      for existing in "${runit_sv[@]}"; do
        if [[ "${existing}" == "${preferred}" ]]; then
          runit_to_enable="${existing}"
          break 2
        fi
      done
    done

    v sudo ln -sf "/etc/sv/${runit_to_enable}" "/var/service/${runit_to_enable}"
    x sudo sv start "${runit_to_enable}"
    return 0
  fi

  if command -v systemctl >/dev/null 2>&1; then
    local units=()
    local detected
    while IFS= read -r detected; do
      [[ -n "${detected}" ]] && units+=("${detected}")
    done < <(systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | rg -i 'amnezia|amneziawg|awg')

    if [[ ${#units[@]} -eq 0 ]]; then
      printf "${STY_YELLOW}[$0]: AmneziaVPN is installed, but no Amnezia-related systemd service unit was found.${STY_RST}\n"
      return 0
    fi

    local preferred_units=(
      amnezia-vpn.service
      amnezia-vpn-service.service
      amneziavpn.service
      amneziawg.service
      amneziawg-go.service
      awg.service
    )
    local unit_to_enable="${units[0]}"
    local preferred
    local existing
    for preferred in "${preferred_units[@]}"; do
      for existing in "${units[@]}"; do
        if [[ "${existing}" == "${preferred}" ]]; then
          unit_to_enable="${existing}"
          break 2
        fi
      done
    done

    v sudo systemctl enable "${unit_to_enable}" --now
    v sudo systemctl restart "${unit_to_enable}"
    return 0
  fi

  printf "${STY_YELLOW}[$0]: Neither runit nor systemd service manager was detected for AmneziaVPN autostart.${STY_RST}\n"
}

function setup_tailscale_for_system(){
  if ! command -v tailscaled >/dev/null 2>&1 || ! command -v tailscale >/dev/null 2>&1; then
    printf "${STY_YELLOW}[$0]: tailscale binaries not found. Skipping tailscale setup.${STY_RST}\n"
    return 0
  fi

  if [[ "${OS_GROUP_ID}" == "void" ]] && [[ -d /etc/sv/tailscaled ]] && [[ -d /var/service ]]; then
    v sudo ln -sf /etc/sv/tailscaled /var/service/tailscaled
    x sudo sv start tailscaled
    # Without this, `tailscale up` as the logged-in user fails with "prefs write access denied"
    # and GUI autostart never reaches Sunshine — Moonlight then shows the PC offline.
    v sudo tailscale set --operator="$(whoami)"
    return 0
  fi

  if command -v systemctl >/dev/null 2>&1; then
    v sudo systemctl enable tailscaled --now
    v sudo tailscale set --operator="$(whoami)"
    return 0
  fi

  printf "${STY_YELLOW}[$0]: No supported init integration found for tailscaled autostart.${STY_RST}\n"
}

function setup_default_timezone_utc_plus_3_for_system(){
  # Use a fixed UTC+3 zone without DST jumps.
  local target_tz="Europe/Moscow"
  if command -v timedatectl >/dev/null 2>&1; then
    v sudo timedatectl set-timezone "${target_tz}"
  elif [[ -f "/usr/share/zoneinfo/${target_tz}" ]]; then
    v sudo ln -sf "/usr/share/zoneinfo/${target_tz}" /etc/localtime
    v bash -c "echo '${target_tz}' | sudo tee /etc/timezone >/dev/null"
  else
    printf "${STY_YELLOW}[$0]: Could not find timezone data for ${target_tz}. Skipping timezone setup.${STY_RST}\n"
    return 0
  fi

  # Persist hardware clock in local settings after timezone change when available.
  if command -v hwclock >/dev/null 2>&1; then
    try v sudo hwclock --systohc
  fi
}

function fix_bluetooth_message_bus_for_void_runit(){
  if [[ "${OS_GROUP_ID}" != "void" ]] || [[ ! -d /etc/sv ]] || [[ ! -d /var/service ]]; then
    return 0
  fi

  # The bluetooth "message bus disconnected" error usually means dbus service
  # is not supervised/healthy before bluetoothd starts.
  if [[ -d /etc/sv/dbus ]]; then
    v sudo ln -sf /etc/sv/dbus /var/service/dbus
    x sudo sv start dbus
  fi

  if [[ -d /etc/sv/bluetoothd ]]; then
    v sudo ln -sf /etc/sv/bluetoothd /var/service/bluetoothd
    x sudo sv restart bluetoothd
  fi
}

function setup_nvidia_hyprland_recommended(){
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    return 0
  fi

  v sudo mkdir -p /etc/modprobe.d
  v bash -c "cat <<'EOF' | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null
options nvidia_drm modeset=1
EOF"

  # Rebuild initramfs when available so this survives reboots.
  if command -v mkinitcpio >/dev/null 2>&1; then
    v sudo mkinitcpio -P
  elif command -v dracut >/dev/null 2>&1; then
    v sudo dracut --regenerate-all --force
  fi
}

#####################################################################################
# These python packages are installed using uv into the venv (virtual environment). Once the folder of the venv gets deleted, they are all gone cleanly. So it's considered as setups, not dependencies.
if ! command -v uv >/dev/null 2>&1; then
  showfun install-uv
  v install-uv
fi
export PATH="${HOME}/.local/bin:${PATH}"
showfun install-python-packages
v install-python-packages

showfun setup_user_group
v setup_user_group

showfun setup_passwordless_root_for_f1uctus
v setup_passwordless_root_for_f1uctus

showfun setup_material_symbols_font_for_user
v setup_material_symbols_font_for_user

showfun setup_nvidia_hyprland_recommended
v setup_nvidia_hyprland_recommended

showfun setup_yandex_music_flatpak_for_system
v setup_yandex_music_flatpak_for_system

showfun setup_sunshine_flatpak_for_user
v setup_sunshine_flatpak_for_user

showfun setup_rquickshare_for_user
v setup_rquickshare_for_user

showfun setup_cursor_appimage_for_user
v setup_cursor_appimage_for_user

showfun setup_amnezia_vpn_for_system
v setup_amnezia_vpn_for_system

showfun setup_tailscale_for_system
v setup_tailscale_for_system

showfun setup_default_timezone_utc_plus_3_for_system
v setup_default_timezone_utc_plus_3_for_system

showfun fix_bluetooth_message_bus_for_void_runit
v fix_bluetooth_message_bus_for_void_runit

if command -v systemctl >/dev/null 2>&1; then
  # For Fedora, uinput is required for the virtual keyboard to function, and udev rules enable input group users to utilize it.
  if [[ "$OS_GROUP_ID" == "fedora" ]]; then
    v bash -c "echo uinput | sudo tee /etc/modules-load.d/uinput.conf"
    v bash -c 'echo SUBSYSTEM==\"misc\", KERNEL==\"uinput\", MODE=\"0660\", GROUP=\"input\" | sudo tee /etc/udev/rules.d/99-uinput.rules'
  else
    v bash -c "echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf"
  fi
  # TODO: find a proper way for enable Nix installed ydotool. When running `systemctl --user enable ydotool, it errors "Failed to enable unit: Unit ydotool.service does not exist".
  if [[ ! "${INSTALL_VIA_NIX}" == true ]]; then
    if [[ "$OS_GROUP_ID" == "fedora" ]]; then
      v prepare_systemd_user_service
    fi
    # When $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR are empty, it commonly means that the current user has been logged in with `su - user` or `ssh user@hostname`. In such case `systemctl --user enable <service>` is not usable. It should be `sudo systemctl --machine=$(whoami)@.host --user enable <service>` instead.
    if [[ ! -z "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
      v systemctl --user enable ydotool --now
    else
      v sudo systemctl --machine=$(whoami)@.host --user enable ydotool --now
    fi
  fi
  v sudo systemctl enable bluetooth --now
elif command -v openrc >/dev/null 2>&1; then
  v bash -c "echo 'modules=i2c-dev' | sudo tee -a /etc/conf.d/modules"
  v sudo rc-update add modules boot
  v sudo rc-update add ydotool default
  v sudo rc-update add bluetooth default

  x sudo rc-service ydotool start
  x sudo rc-service bluetooth start
elif [[ "${OS_GROUP_ID}" == "void" ]] && [[ -d /etc/sv ]]; then
  if [[ -f /etc/modules-load.d/i2c-dev.conf ]]; then
    sleep 0
  else
    v bash -c "echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf"
  fi
  if [[ -d /etc/sv/ydotool ]]; then
    x sudo ln -sf /etc/sv/ydotool /var/service/ydotool
    # runsvdir may not have created supervise/control yet right after ln(1)
    for _i in 1 2 3 4 5 6 7 8 9 10; do
      [[ -p /etc/sv/ydotool/supervise/control ]] && break
      sleep 1
    done
    x sudo sv start ydotool
  fi
  if [[ -d /etc/sv/bluetoothd ]]; then
    x sudo ln -sf /etc/sv/bluetoothd /var/service/bluetoothd
    x sudo sv start bluetoothd
  fi
else
  printf "${STY_RED}"
  printf "====================INIT SYSTEM NOT FOUND====================\n"
  printf "${STY_RST}"
  pause
fi

if [[ "$OS_GROUP_ID" == "gentoo" ]]; then
  v sudo chown -R $(whoami):$(whoami) ~/.local/
fi

if command -v gsettings >/dev/null 2>&1; then
  v gsettings set org.gnome.desktop.interface font-name 'Google Sans Flex Medium 11 @opsz=11,wght=500'
  v gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
fi
if command -v kwriteconfig6 >/dev/null 2>&1; then
  v kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly
fi
