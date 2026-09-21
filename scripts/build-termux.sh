#!/usr/bin/env bash
set -euo pipefail

collection_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
app_source_dir="$collection_dir/termux-app"
if [[ -d /mnt/kingston/builds ]]; then
    app_build_dir="/mnt/kingston/builds/rebroad/src/termux-app.build"
else
    app_build_dir="$app_source_dir"
fi
if [[ -d /mnt/kingston/builds ]]; then
    termux_exec_build_dir="/mnt/kingston/builds/rebroad/src/termux-exec-package.build"
else
    termux_exec_build_dir="$collection_dir/termux-exec-package"
fi
keystore="${HOME:?}/.config/rebroad-termux/termux-release.jks"
password_file="${HOME:?}/.config/rebroad-termux/termux-release.pass"
apk="$app_build_dir/app/build/outputs/apk/release/termux-app_apt-android-7-release_universal.apk"
custom_exec_output="$termux_exec_build_dir/build/output/usr"
if [[ -f "$custom_exec_output/lib/libtermux-exec_nos_c_tre.so" ]]; then
    custom_exec_packaging="$termux_exec_build_dir/build/output/packaging/debian"
elif [[ -f "$collection_dir/termux-exec-package/build/output/usr/lib/libtermux-exec_nos_c_tre.so" ]]; then
    custom_exec_output="$collection_dir/termux-exec-package/build/output/usr"
    custom_exec_packaging="$collection_dir/termux-exec-package/build/output/packaging/debian"
fi

[[ -x "$app_source_dir/gradlew" ]] || { echo "Missing Termux Gradle wrapper: $app_source_dir/gradlew" >&2; exit 1; }
[[ -f "$keystore" ]] || { echo "Missing signing keystore: $keystore" >&2; exit 1; }
[[ -f "$password_file" ]] || { echo "Missing signing password file: $password_file" >&2; exit 1; }
[[ -f "$custom_exec_output/lib/libtermux-exec-ld-preload.so" ]] || {
    echo "Missing customized termux-exec build output: $custom_exec_output" >&2
    exit 1
}
[[ -f "$custom_exec_packaging/postinst" ]] || {
    echo "Missing customized termux-exec postinst: $custom_exec_packaging/postinst" >&2
    exit 1
}

command -v cpto >/dev/null || { echo "cpto is required" >&2; exit 1; }
command -v zip >/dev/null || { echo "zip is required" >&2; exit 1; }

echo "Synchronizing Termux app source"
if [[ "$app_build_dir" != "$app_source_dir" ]]; then
    cpto --no-lngit "$app_source_dir" "$app_build_dir"
else
    echo "Build root unavailable; using source directory"
fi

echo "Building signed Termux APK"
pass=$(<"$password_file")
export TERMUX_REBROAD_SIGNING_STORE_FILE="$keystore"
export TERMUX_REBROAD_SIGNING_STORE_PASSWORD="$pass"
export TERMUX_REBROAD_SIGNING_KEY_ALIAS=rebroad-termux
export TERMUX_REBROAD_SIGNING_KEY_PASSWORD="$pass"
unset pass

build_log=$(mktemp /var/tmp/termux-build.XXXXXX.log)
bootstrap_overlay=$(mktemp -d /var/tmp/termux-bootstrap.XXXXXX)
cleanup() {
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
        ./gradlew :app:downloadBootstraps --no-daemon --console=plain >"$build_log" 2>&1
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
