#!/usr/bin/env bash
# Submits a ZIP, DMG or PKG to Apple's notary service with an App Store Connect
# API key and waits for the result. On failure it prints the notary log and
# exits non-zero. Stapling is left to the caller.
#
# Usage: bash Scripts/notarize.sh <file>
# Env:   NOTARY_KEY_PATH   path to the AuthKey_XXXX.p8 file
#        NOTARY_KEY_ID     App Store Connect API key ID
#        NOTARY_ISSUER_ID  App Store Connect API issuer ID
set -euo pipefail

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "usage: $0 <file-to-notarize>" >&2
  exit 1
fi
for var in NOTARY_KEY_PATH NOTARY_KEY_ID NOTARY_ISSUER_ID; do
  if [[ -z "${!var:-}" ]]; then
    echo "error: $var is not set" >&2
    exit 1
  fi
done

auth=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
result="$(mktemp)"
trap 'rm -f "$result"' EXIT

echo "==> Notarizing $(basename "$FILE")"
rc=0
xcrun notarytool submit "$FILE" "${auth[@]}" --wait --timeout 1h \
  --output-format json > "$result" || rc=$?
cat "$result"
echo

id="$(plutil -extract id raw -o - "$result" 2>/dev/null || true)"
status="$(plutil -extract status raw -o - "$result" 2>/dev/null || true)"

if [[ "$rc" -ne 0 || "$status" != "Accepted" ]]; then
  echo "::error::Notarization of $(basename "$FILE") failed (status: ${status:-unknown}, exit $rc)" >&2
  if [[ -n "$id" ]]; then
    echo "==> Notary log for submission $id"
    xcrun notarytool log "$id" "${auth[@]}" || true
  fi
  exit 1
fi
echo "==> Accepted (submission $id)"
