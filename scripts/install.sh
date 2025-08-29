#!/usr/bin/env sh
set -euo pipefail
REPO=Nen-Co/nendb
API=https://api.github.com/repos/$REPO/releases/latest
INSTALL_DIR=${INSTALL_DIR:-"$HOME/.local/bin"}
TMP=$(mktemp -d)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$OS" in
  linux)  ASSET=nen-linux-x86_64.tar.gz ;;
  darwin) ASSET=nen-macos-universal.tar.gz ;;
  *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
 esac
if [ "$ARCH" != "x86_64" ] && [ "$OS" != "darwin" ]; then
  echo "Only x86_64 (and macOS universal) builds currently provided" >&2
fi
echo "Fetching latest release metadata..." >&2
URL=$(curl -fsSL $API | grep -o "https:[^"]*$ASSET" | head -n1)
SUMS_URL=$(curl -fsSL $API | grep -o "https:[^"]*SHA256SUMS" | head -n1)
[ -z "$URL" ] && { echo "Asset not found in release metadata" >&2; exit 1; }
mkdir -p "$TMP" "$INSTALL_DIR"
cd "$TMP"
curl -fsSLO "$URL"
curl -fsSLO "$SUMS_URL"
sha256sum -c SHA256SUMS 2>/dev/null | grep "$ASSET" || { echo "Checksum verification failed" >&2; exit 1; }
tar -xzf "$ASSET"
BIN=$(echo nen-*)
chmod +x "$BIN"
mv "$BIN" "$INSTALL_DIR/nen"
echo "Installed to $INSTALL_DIR/nen" >&2
echo "Ensure $INSTALL_DIR is on your PATH" >&2
