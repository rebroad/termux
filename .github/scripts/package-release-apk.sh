#!/usr/bin/env bash
set -euo pipefail

metadata="termux-app/app/build/outputs/apk/release/output-metadata.json"
apk="termux-app/app/build/outputs/apk/release/termux-app_apt-android-7-release_universal.apk"
test -s "$metadata"
test -s "$apk"

# Use the Android Gradle output rather than duplicating versions in CI.
read -r version_name version_code < <(python3 - "$metadata" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    metadata = json.load(handle)
outputs = [
    item for item in metadata.get("elements", [])
    if item.get("outputFile") == "termux-app_apt-android-7-release_universal.apk"
]
if len(outputs) != 1:
    raise SystemExit("Expected one universal release APK in Gradle metadata")
item = outputs[0]
print(item["versionName"], item["versionCode"])
PY
)

[[ "$version_name" =~ ^[0-9A-Za-z.+-]+$ ]] || { echo "Unsafe APK version name: $version_name" >&2; exit 1; }
[[ "$version_code" =~ ^[0-9]+$ ]] || { echo "Invalid version code: $version_code" >&2; exit 1; }
(( 10#$version_code > 1022 )) || { echo "App version code must exceed upstream beta (1022)" >&2; exit 1; }

mkdir -p dist
apk_name="termux-app-${version_name}.apk"
cp -- "$apk" "dist/$apk_name"

# A release package must already have been signed by the pinned fork using
# its committed, publicly shared Termux test keystore.
verifier="$ANDROID_SDK_ROOT/build-tools/36.0.0/apksigner"
"$verifier" verify --verbose --print-certs "dist/$apk_name" | tee "$RUNNER_TEMP/termux-apk-signature.txt"
expected_fingerprint="b6da01480eefd5fbf2cd3771b8d1021ec791304bdd6c4bf41d3faabad48ee5e1"
actual_fingerprint=$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' "$RUNNER_TEMP/termux-apk-signature.txt" | head -n 1)
[[ "${actual_fingerprint,,}" == "$expected_fingerprint" ]] || { echo "APK not signed by the expected public test key" >&2; exit 1; }

(cd dist && sha256sum "$apk_name" > SHA256SUMS.txt)

{
  echo "version_name=$version_name"
  echo "version_code=$version_code"
  echo "apk_path=dist/$apk_name"
  echo "artifact_name=termux-app-$version_name"
  echo "release_tag=rebroad-v${version_name}-${GITHUB_SHA:0:7}"
} >> "$GITHUB_OUTPUT"
