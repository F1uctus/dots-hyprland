# Use the generated color scheme

if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt; then
    cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
fi

# Android SDK from asdf (flutter/android toolchain)
if command -v asdf >/dev/null 2>&1; then
    _asdf_android_sdk_path="$(asdf where android-sdk 2>/dev/null)"
    if [[ -n "${_asdf_android_sdk_path}" ]]; then
        export ANDROID_HOME="${_asdf_android_sdk_path}"
        export ANDROID_SDK_ROOT="${_asdf_android_sdk_path}"
        export PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"
    fi
    unset _asdf_android_sdk_path
fi
