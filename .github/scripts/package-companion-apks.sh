#!/usr/bin/env bash
set -euo pipefail

mkdir -p dist
expected_certificate="b6da01480eefd5fbf2cd3771b8d1021ec791304bdd6c4bf41d3faabad48ee5e1"
verifier="$ANDROID_SDK_ROOT/build-tools/35.0.0/apksigner"

for kind in api boot; do
  apk_dir="termux-${kind}/app/build/outputs/apk/release"
  metadata="$apk_dir/output-metadata.json"
  [[ -s "$metadata" ]] || { echo "Missing Gradle output metadata: $metadata" >&2; exit 1; }

  mapfile -t details < <(python3 - "$metadata" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
outputs = metadata.get("elements", [])
if len(outputs) != 1:
    raise SystemExit(f"Expected one release APK: {sys.argv[1]}")
item = outputs[0]
for field in ("outputFile", "versionName", "versionCode"):
    print(item[field])
PY
)
  [[ "${#details[@]}" -eq 3 ]] || { echo "Invalid Gradle APK metadata for $kind" >&2; exit 1; }
  apk="$apk_dir/${details[0]}"
  version_name="${details[1]}"
  version_code="${details[2]}"
  [[ -s "$apk" ]] || { echo "Missing APK: $apk" >&2; exit 1; }
  [[ "$version_name" =~ ^[0-9A-Za-z.+-]+$ ]] || { echo "Unsafe $kind version: $version_name" >&2; exit 1; }
  [[ "$version_code" =~ ^[0-9]+$ ]] || { echo "Invalid $kind versionCode: $version_code" >&2; exit 1; }
  out="termux-${kind}-${version_name}.apk"
  cp -- "$apk" "dist/$out"

  report=$("$verifier" verify --verbose --print-certs "dist/$out")
  echo "$report"
  certificate=$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<< "$report" | head -n 1)
  [[ "${certificate,,}" == "$expected_certificate" ]] || { echo "$kind APK signed with incorrect key" >&2; exit 1; }
  echo "Verified $kind version $version_name (versionCode $version_code) signed with matching test key."
done

(cd dist && sha256sum termux-api-*.apk termux-boot-*.apk > SHA256SUMS-companions.txt)
