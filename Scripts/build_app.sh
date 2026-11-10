#!/usr/bin/env bash
# Builds Multipaste.app (universal: arm64 + x86_64), ad-hoc signs it and
# packages a DMG and a ZIP into ./build.
#
# Usage: bash Scripts/build_app.sh
# Env:   REQUIRE_UNIVERSAL=1  fail instead of falling back to a host-only build
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Multipaste"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
if [[ -z "$VERSION" ]]; then
  echo "error: VERSION file is empty" >&2
  exit 1
fi

BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
ZIP="$BUILD_DIR/$APP_NAME-$VERSION.zip"

echo "==> Building $APP_NAME $VERSION"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Compile -----------------------------------------------------------------
ARCH_FLAGS="--arch arm64 --arch x86_64"
# shellcheck disable=SC2086
if ! swift build -c release $ARCH_FLAGS; then
  if [[ "${REQUIRE_UNIVERSAL:-0}" == "1" ]]; then
    echo "error: universal build failed" >&2
    exit 1
  fi
  echo "warning: universal build failed; building for this Mac's architecture only" >&2
  ARCH_FLAGS=""
  swift build -c release
fi
# shellcheck disable=SC2086
BIN_DIR="$(swift build -c release $ARCH_FLAGS --show-bin-path)"
BINARY="$BIN_DIR/$APP_NAME"
if [[ ! -f "$BINARY" ]]; then
  echo "error: built binary not found at $BINARY" >&2
  exit 1
fi

# --- Assemble the bundle -------------------------------------------------------
echo "==> Assembling $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"
chmod 755 "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# VERSION is the single source of truth for the marketing version.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# --- App icon (optional: the build continues without it) ----------------------
make_icon() {
  local work="$BUILD_DIR/icon"
  mkdir -p "$work" &&
    swiftc -O -o "$work/make_icon" "$ROOT/Scripts/make_icon.swift" &&
    "$work/make_icon" "$work/AppIcon.iconset" &&
    iconutil -c icns "$work/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
}
echo "==> Generating app icon"
if make_icon; then
  echo "    icon ok"
else
  echo "warning: icon generation failed; continuing without a custom icon" >&2
fi
rm -rf "$BUILD_DIR/icon"

# --- Sign and verify -----------------------------------------------------------
echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"
lipo -info "$APP/Contents/MacOS/$APP_NAME"
codesign -v "$APP"
codesign -dv "$APP" 2>&1 | sed 's/^/    /' || true

# --- ZIP -------------------------------------------------------------------------
echo "==> Creating $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# --- DMG -------------------------------------------------------------------------
echo "==> Creating $DMG"
STAGING="$BUILD_DIR/dmg"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
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

echo "==> Done"
ls -lh "$BUILD_DIR"
