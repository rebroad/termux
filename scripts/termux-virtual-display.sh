#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
serial=${ANDROID_SERIAL:-}
display_spec=${TERMUX_VIRTUAL_DISPLAY_SPEC:-900x1200/300}
headless=0

usage() {
    cat <<'EOF'
Usage: termux-virtual-display.sh [--serial SERIAL] [--headless]

Start the customized Termux app on an isolated scrcpy virtual display.
The primary Android display is not used for the app or its input.

Environment:
  TERMUX_VIRTUAL_DISPLAY_SPEC  display geometry/density (default: 900x1200/300)
  SCRCPY_BIN                   scrcpy executable to use
  SCRCPY_SERVER_PATH           matching scrcpy-server path
EOF
}

while (($#)); do
    case "$1" in
        --serial)
            (($# >= 2)) || { echo "--serial needs a value" >&2; exit 2; }
            serial=$2
            shift 2
            ;;
        --headless)
            headless=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

command -v adb >/dev/null || { echo "adb is required" >&2; exit 1; }

choose_device() {
    local choice
    mapfile -t devices < <(adb devices | awk '$2 == "device" {print $1}')
    if [[ -n "$serial" ]]; then
        printf '%s\n' "${devices[@]}" | grep -Fx -- "$serial" >/dev/null || {
            echo "ADB device is not authorised or connected: $serial" >&2
            adb devices >&2
            exit 1
        }
    elif ((${#devices[@]} == 1)); then
        serial=${devices[0]}
    elif ((${#devices[@]} > 1)); then
        echo "Select the Android device:" >&2
        select choice in "${devices[@]}"; do
            [[ -n "$choice" ]] && { serial=$choice; break; }
            echo "Choose a listed entry." >&2
        done
    else
        echo "No authorised ADB device is connected." >&2
        adb devices >&2
        exit 1
    fi
}

find_scrcpy() {
    if [[ -n "${SCRCPY_BIN:-}" ]]; then
        printf '%s\n' "$SCRCPY_BIN"
        return
    fi
    local source_dir external_candidate
    source_dir=$(readlink -f "$HOME/src/scrcpy")
    case "$source_dir" in
        /mnt/kingston/@home/*)
            external_candidate="/mnt/kingston/builds/${source_dir#/mnt/kingston/@home/}.make/app/scrcpy"
            [[ -x "$external_candidate" ]] && { printf '%s\n' "$external_candidate"; return; }
            ;;
    esac
    if command -v scrcpy >/dev/null; then
        command -v scrcpy
        return
    fi
    local candidate
    for candidate in \
        "$HOME/src/scrcpy/build/app/scrcpy" \
        "$HOME/src/scrcpy/app/scrcpy" \
        "/var/tmp/scrcpy-build/app/scrcpy"; do
        [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
    done
    echo "scrcpy is required; install it or set SCRCPY_BIN." >&2
    exit 1
}

choose_device
scrcpy_bin=$(find_scrcpy)
if [[ -z "${SCRCPY_SERVER_PATH:-}" ]]; then
    case "$scrcpy_bin" in
        */app/scrcpy)
            candidate_server=${scrcpy_bin%/app/scrcpy}/server/scrcpy-server
            [[ -f "$candidate_server" ]] && export SCRCPY_SERVER_PATH=$candidate_server
            ;;
    esac
fi
scrcpy_args=("-s" "$serial" "--new-display=$display_spec" "--no-vd-system-decorations" "--no-audio" \
    "--start-app=com.termux" "--pause-on-exit=false")
if ((headless)); then
    scrcpy_args+=(--no-window)
fi

echo "Starting Termux on an isolated virtual display for $serial"
echo "Display specification: $display_spec"
exec "$scrcpy_bin" "${scrcpy_args[@]}"
