#!/usr/bin/env bash
set -euo pipefail

collection_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
app_source_dir="$collection_dir/termux-app"
build_root="${TERMUX_BUILD_ROOT:-$HOME/src/termux.build}"
app_build_dir="$build_root/termux-app"
termux_exec_build_dir="${TERMUX_EXEC_BUILD_DIR:-$build_root/termux-exec-package}"
keystore="${HOME:?}/.config/rebroad-termux/termux-release.jks"
password_file="${HOME:?}/.config/rebroad-termux/termux-release.pass"
apk="$app_build_dir/app/build/outputs/apk/release/termux-app_apt-android-7-release_universal.apk"
custom_exec_output="$termux_exec_build_dir/build/output/usr"
custom_exec_packaging="$termux_exec_build_dir/build/output/packaging/debian"
[[ -x "$app_source_dir/gradlew" ]] || { echo "Missing Termux Gradle wrapper: $app_source_dir/gradlew" >&2; exit 1; }
signing_enabled=0
if [[ -f "$keystore" && -f "$password_file" ]]; then
    signing_enabled=1
elif [[ "${TERMUX_ALLOW_UNSIGNED_BUILD:-0}" != 1 ]]; then
    echo "Missing signing keystore or password file; set TERMUX_ALLOW_UNSIGNED_BUILD=1 only for a build that will be signed locally" >&2
    exit 1
fi
[[ -f "$custom_exec_output/lib/libtermux-exec-ld-preload.so" ]] || {
    echo "Missing customized termux-exec build output: $custom_exec_output" >&2
    exit 1
}
[[ -f "$custom_exec_packaging/postinst" ]] || {
    echo "Missing customized termux-exec postinst: $custom_exec_packaging/postinst" >&2
    exit 1
}

command -v zip >/dev/null || { echo "zip is required" >&2; exit 1; }

if [[ -d "$app_build_dir" && "$app_build_dir" -ef "$app_source_dir" ]]; then
    app_build_dir="$app_source_dir"
    echo "Building Termux app in its source tree"
else
    command -v cpto >/dev/null || { echo "cpto is required" >&2; exit 1; }
    echo "Synchronizing Termux app source into $app_build_dir"
    mkdir -p "$app_build_dir"
    cpto --no-lngit "$app_source_dir" "$app_build_dir"
fi

if [[ "$signing_enabled" == 1 ]]; then
    echo "Building signed Termux APK"
    pass=$(<"$password_file")
    export TERMUX_REBROAD_SIGNING_STORE_FILE="$keystore"
    export TERMUX_REBROAD_SIGNING_STORE_PASSWORD="$pass"
    export TERMUX_REBROAD_SIGNING_KEY_ALIAS=rebroad-termux
    export TERMUX_REBROAD_SIGNING_KEY_PASSWORD="$pass"
    unset pass
else
    if [[ "${TERMUX_CI_TEST_KEY_SIGNING:-0}" == 1 ]]; then
        echo "Building Termux APK with public untrusted test-key signing"
    else
        echo "Building unsigned Termux APK for local signing"
    fi
fi
app_git_commit=$(git -C "$app_source_dir" rev-parse HEAD | cut -c1-10)
export TERMUX_GIT_COMMIT="$app_git_commit"

if [[ -n "${PREFIX:-}" && -d "$PREFIX/tmp" ]]; then
    temp_dir="$PREFIX/tmp"
else
    temp_dir=/var/tmp
fi
bootstrap_archive="$app_build_dir/app/src/main/cpp/bootstrap-aarch64.zip"
archive_backup=
if [[ -e "$bootstrap_archive" ]]; then
    archive_backup=$(mktemp "$temp_dir/termux-bootstrap-original.XXXXXX.zip")
    cp -p -- "$bootstrap_archive" "$archive_backup"
fi
build_log=$(mktemp "$temp_dir/termux-build.XXXXXX.log")
bootstrap_overlay=$(mktemp -d "$temp_dir/termux-bootstrap.XXXXXX")
cleanup() {
    if [[ -n "$archive_backup" ]]; then
        cp -p -- "$archive_backup" "$bootstrap_archive"
        rm -f -- "$archive_backup"
    else
        rm -f -- "$bootstrap_archive"
    fi
    rm -rf -- "$bootstrap_overlay"
    rm -f -- "$build_log"
}
trap cleanup EXIT

(
    cd "$app_build_dir"
    if unzip -p app/src/main/cpp/bootstrap-aarch64.zip var/lib/dpkg/info/termux-exec.postinst 2>/dev/null \
        | grep -q 'create_default_hostname_file'; then
        echo "Customized bootstrap already present" >"$build_log"
    else
        if ! ./gradlew :app:downloadBootstraps --no-daemon --console=plain >"$build_log" 2>&1; then
            tail -80 "$build_log" >&2
            exit 1
        fi
    fi
)

mkdir -p "$bootstrap_overlay/lib" "$bootstrap_overlay/bin" "$bootstrap_overlay/var/lib/dpkg/info"
for file in \
    lib/libtermux-exec-ld-preload.so \
    lib/libtermux-exec-direct-ld-preload.so \
    lib/libtermux-exec-linker-ld-preload.so \
    lib/libtermux-exec_nos_c_tre.so \
    bin/termux-exec-ld-preload-lib \
    bin/termux-exec-system-linker-exec; do
    cp -- "$custom_exec_output/$file" "$bootstrap_overlay/$file"
done
cp -- "$custom_exec_packaging/postinst" \
    "$bootstrap_overlay/var/lib/dpkg/info/termux-exec.postinst"
sed 's|@TERMUX__PREFIX@|/data/data/com.termux/files/usr|g' \
    "$collection_dir/termux-exec-package/app/main/scripts/termux-identity.in" \
    > "$bootstrap_overlay/bin/termux-identity"
chmod 700 "$bootstrap_overlay/bin/termux-identity"

echo "Embedding customized aarch64 termux-exec preload"
(cd "$bootstrap_overlay" && zip -q "$app_build_dir/app/src/main/cpp/bootstrap-aarch64.zip" \
    lib/libtermux-exec-ld-preload.so \
    lib/libtermux-exec-direct-ld-preload.so \
    lib/libtermux-exec-linker-ld-preload.so \
    lib/libtermux-exec_nos_c_tre.so \
    bin/termux-exec-ld-preload-lib \
    bin/termux-exec-system-linker-exec \
    bin/termux-identity \
    var/lib/dpkg/info/termux-exec.postinst)

# ndk-build does not track the .incbin archive as a dependency. Remove only
# the generated release native objects so the updated archive is embedded.
rm -rf -- \
    "$app_build_dir/app/build/intermediates/cxx/Release" \
    "$app_build_dir/app/build/intermediates/stripped_native_libs/release"

(
    cd "$app_build_dir"
    if ! ./gradlew :app:assembleRelease --no-daemon --console=plain -x :app:downloadBootstraps >"$build_log" 2>&1; then
        tail -80 "$build_log" >&2
        exit 1
    fi
)

[[ -f "$apk" ]] || { echo "Build completed without producing $apk" >&2; exit 1; }
echo "Built: $apk"
stat -c 'Size: %s bytes  Modified: %y' "$apk"
