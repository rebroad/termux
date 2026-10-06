#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
collection_dir=$(cd -- "${script_dir}/.." && pwd -P)
api_source_dir="${collection_dir}/termux-api"
if [[ "$api_source_dir" == *"/@home/"* ]]; then
    api_build_dir="${api_source_dir/\/\@home\//\/builds\/}.build"
else
    api_build_dir="${api_source_dir}.build"
fi
api_build_dir="${TERMUX_API_BUILD_DIR:-$api_build_dir}"
remote_host="${TERMUX_API_SSH_TARGET:-flip7}"
remote_downloads="/storage/emulated/0/Download"
android_sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${HOME}/Android/Sdk}}"
if [[ ! -d "$android_sdk" ]]; then
    echo "Android SDK directory not found: $android_sdk" >&2
    exit 1
fi
export ANDROID_HOME="$android_sdk"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$android_sdk}"
keystore="${HOME:?}/.config/rebroad-termux/termux-release.jks"
password_file="${HOME:?}/.config/rebroad-termux/termux-release.pass"

for command in cpto rsync ssh sha256sum; do
    command -v "$command" >/dev/null || {
        echo "Required command is missing: $command" >&2
        exit 1
    }
done
[[ -x "$api_source_dir/gradlew" ]] || {
    echo "Termux API source checkout not found: $api_source_dir" >&2
    exit 1
}
[[ -f "$keystore" && -r "$keystore" ]] || {
    echo "Termux signing keystore is not readable: $keystore" >&2
    exit 1
}
[[ -f "$password_file" && -r "$password_file" ]] || {
    echo "Termux signing password file is not readable: $password_file" >&2
    exit 1
}

if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$remote_host" \
    "test -d '$remote_downloads' && test -w '$remote_downloads' && command -v rsync >/dev/null && command -v sha256sum >/dev/null"; then
    echo "Flip 7 Downloads directory or remote rsync is unavailable" >&2
    exit 1
fi

mkdir -p "$api_build_dir"
sync_log=$(mktemp /var/tmp/termux-api-sync.XXXXXX.log)
if ! cpto --no-lngit "$api_source_dir" "$api_build_dir" >"$sync_log" 2>&1; then
    tail -n 40 "$sync_log" >&2
    echo "Source sync log: $sync_log" >&2
    exit 1
fi

build_log=$(mktemp /var/tmp/termux-api-build.XXXXXX.log)
IFS= read -r signing_password < "$password_file"
if [[ -z "$signing_password" ]]; then
    echo "Termux signing password file is empty: $password_file" >&2
    exit 1
fi
export TERMUX_REBROAD_SIGNING_STORE_FILE="$keystore"
export TERMUX_REBROAD_SIGNING_STORE_PASSWORD="$signing_password"
export TERMUX_REBROAD_SIGNING_KEY_ALIAS=rebroad-termux
export TERMUX_REBROAD_SIGNING_KEY_PASSWORD="$signing_password"
api_git_commit=$(git -C "$api_source_dir" rev-parse HEAD)
export TERMUX_GIT_COMMIT="${api_git_commit:0:10}"
unset signing_password

if ! (cd -- "$api_build_dir" && ./gradlew :app:assembleRelease --no-daemon --console=plain) >"$build_log" 2>&1; then
    tail -n 80 "$build_log" >&2
    echo "Build log: $build_log" >&2
    exit 1
fi

mapfile -t apks < <(find "$api_build_dir/app/build/outputs/apk/release" -maxdepth 1 -type f -name '*.apk' -print)
if [[ ${#apks[@]} -ne 1 ]]; then
    echo "Expected one release APK, found ${#apks[@]}" >&2
    echo "Build log: $build_log" >&2
    exit 1
fi
apk=${apks[0]}
apk_name=$(basename -- "$apk")
if [[ ! "$apk_name" =~ ^[A-Za-z0-9._+-]+\.apk$ ]]; then
    echo "Unexpected APK filename: $apk_name" >&2
    exit 1
fi

rsync --archive --human-readable --info=progress2 --protect-args -- \
    "$apk" "$remote_host:$remote_downloads/"
local_hash=$(sha256sum "$apk" | awk '{print $1}')
remote_hash=$(ssh -o BatchMode=yes "$remote_host" \
    "sha256sum '$remote_downloads/$apk_name'" | awk '{print $1}')
if [[ "$local_hash" != "$remote_hash" ]]; then
    echo "Remote APK checksum mismatch: local=$local_hash remote=$remote_hash" >&2
    exit 1
fi

printf 'Copied %s to %s:%s/%s\nSHA-256: %s\n' \
    "$apk" "$remote_host" "$remote_downloads" "$apk_name" "$local_hash"
printf 'Gradle log: %s\n' "$build_log"
