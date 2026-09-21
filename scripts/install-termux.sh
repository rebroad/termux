#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
serial="${ANDROID_SERIAL:-}"
copy_to=""
declare -a requested_apks=()

usage() {
    cat <<'EOF'
Usage: install-termux.sh [APK...]

Find the newest APKs under the Termux tree, select a connected ADB device,
and install them while preserving application data. Existing USB and Wi-Fi
ADB transports are handled identically. If no ADB device is available, copy
the APKs to mounted phone storage for manual installation.

Options:
  --serial SERIAL       select an ADB device without prompting
  --copy-to DIRECTORY   copy to this mounted phone directory if ADB fails
  -h, --help            show this help
EOF
}

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
            requested_apks+=("$1")
            shift
            ;;
    esac
done

declare -a apks=()
if ((${#requested_apks[@]})); then
    apks=("${requested_apks[@]}")
else
    declare -A newest_by_name=()
    while read -r _ apk; do
        name=${apk##*/}
        [[ -v "newest_by_name[$name]" ]] || newest_by_name["$name"]=$apk
    done < <(find -L "$script_dir" -type f -name '*.apk' -printf '%T@ %p\n' 2>/dev/null | sort -rn)
    while read -r apk; do
        [[ -n "$apk" ]] && apks+=("$apk")
    done < <(printf '%s\n' "${newest_by_name[@]}" | sort)
fi

((${#apks[@]})) || {
    echo "No APKs found under $script_dir. Build the desired APKs first." >&2
    exit 1
}
for apk in "${apks[@]}"; do
    [[ -f "$apk" ]] || { echo "APK not found: $apk" >&2; exit 1; }
done

choose_from() {
    local prompt=$1 choice
    shift
    if (($# == 1)); then
        printf '%s\n' "$1"
        return
    fi
    echo "$prompt" >&2
    select choice in "$@"; do
        [[ -n "$choice" ]] && { printf '%s\n' "$choice"; return; }
        echo "Choose a listed entry." >&2
    done
}

if command -v adb >/dev/null; then
    if command -v timeout >/dev/null; then
        mdns_services=$(timeout 3s adb mdns services 2>/dev/null || true)
    else
        mdns_services=$(adb mdns services 2>/dev/null || true)
    fi
    while read -r endpoint; do
        [[ -n "$endpoint" ]] && adb connect "$endpoint" >/dev/null 2>&1 || true
    done < <(printf '%s\n' "$mdns_services" | awk '$0 ~ /_adb-tls-connect/ {print $NF}' | sed 's/[[:space:]]//g')

    mapfile -t devices < <(adb devices | awk '$2 == "device" {print $1}')
    if [[ -n "$serial" ]]; then
        printf '%s\n' "${devices[@]}" | grep -Fx -- "$serial" >/dev/null || {
            echo "ADB device is not authorised or connected: $serial" >&2
            adb devices >&2
            exit 1
        }
    elif ((${#devices[@]})); then
        serial=$(choose_from "Select the Android device:" "${devices[@]}")
    fi

    if [[ -n "$serial" ]]; then
        for apk in "${apks[@]}"; do
            echo "Installing ${apk##*/} on $serial"
            adb -s "$serial" install -r "$apk"
        done
        exit 0
    fi
fi

if [[ -z "$copy_to" ]]; then
    declare -a copy_candidates=()
    while read -r directory; do
        [[ -n "$directory" ]] && copy_candidates+=("$directory")
    done < <(find "/run/user/$(id -u)/gvfs" "/media/$USER" /media -maxdepth 8 \
        -type d \( -iname Download -o -iname Downloads \) -print 2>/dev/null | sort -u)
    if ((${#copy_candidates[@]})); then
        copy_to=$(choose_from "No ADB device is available. Select mounted phone storage:" "${copy_candidates[@]}")
    else
        echo "No ADB device or mounted phone storage was found." >&2
        echo "Enable USB/Wi-Fi debugging, or mount the phone's storage and rerun." >&2
        exit 1
    fi
fi

[[ -d "$copy_to" ]] || { echo "Copy destination is not a directory: $copy_to" >&2; exit 1; }
for apk in "${apks[@]}"; do
    cp -- "$apk" "$copy_to/"
    echo "Copied ${apk##*/} to $copy_to"
done
echo "Open the copied APK on the phone to complete installation."
