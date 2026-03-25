#!/usr/bin/env bash
# Download Sparkle tools and print SUPublicEDKey for Info.plist; export private key for CI.
set -euo pipefail
TAG="${SPARKLE_TAG:-2.6.4}"
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

curl -sL -o "$TMP/sparkle.tar.xz" "https://github.com/sparkle-project/Sparkle/releases/download/${TAG}/Sparkle-${TAG}.tar.xz"
tar -xf "$TMP/sparkle.tar.xz" -C "$TMP" bin/generate_keys
chmod +x "$TMP/bin/generate_keys"

echo "==> Generating EdDSA keypair (private key saved to login keychain)…"
"$TMP/bin/generate_keys"

echo ""
echo "==> Add the SUPublicEDKey line above to App/Info.plist"
echo "==> Export private key for GitHub Actions:"
echo "    $TMP/bin/generate_keys -x sparkle_private_key.txt"
echo "    # Then: gh secret set SPARKLE_ED_PRIVATE_KEY < sparkle_private_key.txt"
