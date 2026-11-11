#!/usr/bin/env bash
# Packages an already built (and signed) build/Multipaste.app into
# build/Multipaste-<version>.zip and build/Multipaste-<version>.dmg.
# Existing ZIP/DMG files for that version are replaced.
#
# Usage: bash Scripts/package_app.sh <version>
# Called by build_app.sh, and by the release workflow again after the app has
# been notarized and stapled.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Multipaste"
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version>" >&2
  exit 1
fi

BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
ZIP="$BUILD_DIR/$APP_NAME-$VERSION.zip"

if [[ ! -d "$APP" ]]; then
  echo "error: $APP not found; run Scripts/build_app.sh first" >&2
  exit 1
fi

# --- ZIP -------------------------------------------------------------------------
echo "==> Creating $ZIP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# --- DMG -------------------------------------------------------------------------
echo "==> Creating $DMG"
STAGING="$BUILD_DIR/dmg"
rm -rf "$STAGING"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

dmg_ok=0
for attempt in 1 2 3; do
  if hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"; then
    dmg_ok=1
    break
  fi
  echo "warning: hdiutil failed (attempt $attempt); retrying" >&2
  sleep 3
done
rm -rf "$STAGING"
if [[ "$dmg_ok" != "1" ]]; then
  echo "error: could not create the DMG" >&2
  exit 1
fi
