#!/usr/bin/env bash
# Native Sunshine helper: make libcuda discoverable for NVENC (some distros need an explicit path).
# Does not fix missing nvidia-uvm / driver issues; see sunshine.log for CUDA_ERROR_*.

set -eu

BIN="${SUNSHINE_NATIVE_BIN:-}"
if [[ -z "${BIN}" ]]; then
  if [[ -x /usr/bin/sunshine ]]; then
    BIN=/usr/bin/sunshine
  elif [[ -x /usr/local/bin/sunshine ]]; then
    BIN=/usr/local/bin/sunshine
  else
    exit 1
  fi
fi
[[ -x "${BIN}" ]] || exit 1

extra_lp=
for d in /usr/lib64 /usr/lib; do
  if [[ -e "${d}/libcuda.so.1" ]] || compgen -G "${d}/libcuda.so.*" >/dev/null 2>&1; then
    extra_lp="${extra_lp:+${extra_lp}:}${d}"
  fi
done
if [[ -n "${extra_lp}" ]]; then
  export LD_LIBRARY_PATH="${extra_lp}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
fi

exec "${BIN}" "$@"
