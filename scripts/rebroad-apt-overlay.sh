#!/usr/bin/env bash
set -euo pipefail

# This is included in the app's aarch64 bootstrap ZIP so both apt and pkg use
# the signed ReBroad repository first, while retaining official Termux mirrors.
[[ "$#" -eq 1 ]] || { echo "Usage: $0 BOOTSTRAP_OVERLAY_DIRECTORY" >&2; exit 2; }
overlay="$1"
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pubkey="$repo_dir/assets/rebroad-archive-key.asc"
pubkey_sha256="49f10af5d74a3e79508693d80a4ccaa9f86200ce654b6b853ac0ebade6577bfc"
repo_url="https://raw.githubusercontent.com/rebroad/termux-packages/apt-repo"
prefix="/data/data/com.termux/files/usr"

printf '%s  %s\n' "$pubkey_sha256" "$pubkey" | sha256sum --check --status || {
    echo "Embedded ReBroad archive signing key does not match pinned fingerprint." >&2
    exit 1
}

mkdir -p "$overlay/etc/apt/keyrings" "$overlay/etc/apt/sources.list.d" "$overlay/etc/apt/preferences.d"
install -m 0644 "$pubkey" "$overlay/etc/apt/keyrings/rebroad.asc"
cat > "$overlay/etc/apt/sources.list.d/rebroad.list" <<EOF
deb [arch=aarch64 signed-by=$prefix/etc/apt/keyrings/rebroad.asc] $repo_url stable main
EOF
cat > "$overlay/etc/apt/preferences.d/00-rebroad" <<'EOF'
Package: *
Pin: release o=ReBroad
Pin-Priority: 1001
EOF
echo "Embedded signed ReBroad APT feed with priority 1001 and official-mirror fallback."
