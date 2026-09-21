#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: install-termux.sh [--serial SERIAL] APK...
       install-termux.sh --copy-to DIRECTORY APK...

Install APKs over ADB, or copy them to a mounted phone directory when ADB
debugging is unavailable. APKs are installed with -r, preserving app data.
EOF
}

serial="${ANDROID_SERIAL:-}"
copy_to=""
apks=()

while (($#)); do
    case "$1" in
        --serial)
            (($# >= 2)) || { echo "--serial needs a value" >&2; exit 2; }
            serial=$2
            shift 2
            ;;
        --copy-to)
            (($# >= 2)) || { echo "--copy-to needs a directory" >&2; exit 2; }
            copy_to=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -* )
            echo "unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            apks+=("$1")
            shift
            ;;
    esac
done

((${#apks[@]})) || { echo "at least one APK is required" >&2; usage >&2; exit 2; }
for apk in "${apks[@]}"; do
    [[ -f "$apk" ]] || { echo "APK not found: $apk" >&2; exit 1; }
done

if [[ -n "$copy_to" ]]; then
    [[ -d "$copy_to" ]] || { echo "copy destination is not a directory: $copy_to" >&2; exit 1; }
    for apk in "${apks[@]}"; do
        cp -- "$apk" "$copy_to/"
        echo "Copied $(basename "$apk") to $copy_to"
    done
    echo "Open the copied APK on the phone to complete installation."
    exit 0
fi

command -v adb >/dev/null || { echo "adb is required for USB installation" >&2; exit 1; }
mapfile -t devices < <(adb devices | awk '$2 == "device" {print $1}')
if [[ -z "$serial" ]]; then
    ((${#devices[@]} == 1)) || {
        echo "Select exactly one authorised ADB device, or pass --serial SERIAL." >&2
        adb devices >&2
        exit 1
    }
    serial=${devices[0]}
else
    printf '%s\n' "${devices[@]}" | grep -Fx -- "$serial" >/dev/null || {
        echo "ADB device is not authorised or connected: $serial" >&2
        adb devices >&2
        exit 1
    }
fi

for apk in "${apks[@]}"; do
    echo "Installing $(basename "$apk") on $serial"
    adb -s "$serial" install -r -- "$apk"
done
