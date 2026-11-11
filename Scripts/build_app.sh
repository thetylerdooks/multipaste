#!/usr/bin/env bash
# Builds Multipaste.app (universal: arm64 + x86_64), signs it (ad-hoc by
# default) and packages a DMG and a ZIP into ./build.
#
# Usage: bash Scripts/build_app.sh
# Env:   REQUIRE_UNIVERSAL=1  fail instead of falling back to a host-only build
#        VERSION=1.2.3        override the marketing version (default: VERSION file)
#        SIGN_IDENTITY=...    codesign identity (default "-", ad-hoc). Any other
#                             value signs with the hardened runtime and a secure
#                             timestamp, as needed for notarization.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Multipaste"
if [[ -n "${VERSION:-}" ]]; then
  VERSION="$(printf '%s' "$VERSION" | tr -d '[:space:]')"
else
  VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
fi
if [[ -z "$VERSION" ]]; then
  echo "error: VERSION file is empty" >&2
  exit 1
fi
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "error: version '$VERSION' is not of the form 1.2.3" >&2
  exit 1
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"

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
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "==> Ad-hoc signing"
  codesign --force --deep --sign - "$APP"
else
  # Inside out: the only nested code is the main executable. No entitlements
  # are needed: Accessibility, CGEvent posting and SMAppService all work under
  # the hardened runtime.
  echo "==> Signing with hardened runtime"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
    "$APP/Contents/MacOS/$APP_NAME"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
lipo -info "$APP/Contents/MacOS/$APP_NAME"
codesign --verify --strict --deep --verbose=2 "$APP"
codesign -dv "$APP" 2>&1 | sed 's/^/    /' || true

# --- ZIP and DMG -----------------------------------------------------------------
bash "$ROOT/Scripts/package_app.sh" "$VERSION"

echo "==> Done"
ls -lh "$BUILD_DIR"
