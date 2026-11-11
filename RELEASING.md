# Releasing Multipaste

Releases are built, signed with a Developer ID certificate, notarized by Apple
and published by GitHub Actions (`.github/workflows/release.yml`). Nothing is
signed or uploaded from a developer Mac.

## Cut a release

1. Optional but recommended: bump `VERSION` (and the version mentioned in
   `README.md`), commit and push to `main`. The tag decides the version that
   ships; if it differs from `VERSION` the workflow builds the tag's version and
   prints a warning.
2. Tag the commit and push the tag:

   ```sh
   git tag v1.6.0
   git push origin v1.6.0      # or: git push --tags
   ```

3. Watch **Actions > Release**. When it finishes, the release appears under
   **Releases** with `Multipaste-<version>.dmg`, `Multipaste-<version>.zip` and
   `Multipaste-<version>-SHA256SUMS.txt`.

Tags must look like `v1.2.3` (`v` followed by one to three dot-separated
numbers). The leading `v` is stripped and the rest becomes
`CFBundleShortVersionString`.

## What the workflow does

On `macos-15`:

1. Fails early if any of the secrets below is missing.
2. Works out the version: the tag without its `v`, or the `VERSION` file when
   run by hand from a branch.
3. Creates a temporary keychain with a random password, imports the Developer
   ID Application certificate into it, makes it the default keychain and
   allows `codesign` to use the key without a prompt. The identity is picked
   with `security find-identity -v -p codesigning` and must belong to
   `APPLE_TEAM_ID`.
4. Decodes the App Store Connect API key into `$RUNNER_TEMP`.
5. Runs `Scripts/build_app.sh` with `REQUIRE_UNIVERSAL=1` (arm64 + x86_64) and
   `SIGN_IDENTITY` set, so the executable and then the app are signed with
   `--options runtime --timestamp`. No entitlements are needed.
6. Submits the app ZIP with `xcrun notarytool submit --wait`
   (`Scripts/notarize.sh`). If Apple rejects it, the notary log is printed and
   the run fails. Otherwise the ticket is stapled to the app and checked with
   `stapler validate`, `codesign --verify --strict --deep` and `spctl -a`.
7. Re-creates the ZIP and DMG from the stapled app (`Scripts/package_app.sh`),
   signs the DMG, notarizes it, staples it and checks it with `spctl`.
8. Writes SHA-256 checksums for the DMG and ZIP.
9. Uploads the DMG, ZIP and checksums as workflow artifacts (every run).
10. Publishes a GitHub release with those files, only when the run is for a
    `refs/tags/v*` ref.
11. Always deletes the temporary keychain and the decoded certificate and API
    key, and restores the default keychain.

`.github/workflows/build.yml` is only the CI build (ad-hoc signed) for `main`,
pull requests and manual runs. It does not publish anything.

## Dry run

**Actions > Release > Run workflow**, pick a branch (for example `main`) and
run it. It does everything above, including real notarization, but skips the
publish step. Download the `Multipaste-<version>-notarized` artifact from the
run page to inspect the DMG and ZIP.

Do not pick a tag in the "Use workflow from" menu unless you want to publish:
a manual run on a `v*` tag publishes a release for that tag.

## Secrets

Set these under **Settings > Secrets and variables > Actions > Repository
secrets**. Never commit any of them, or the files they come from, to this
public repository.

| Secret | What it is |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | The "Developer ID Application" certificate with its private key, exported from Keychain Access as a `.p12`, base64 encoded (`base64 -i cert.p12 \| pbcopy`). |
| `MACOS_CERTIFICATE_PASSWORD` | The password chosen when exporting that `.p12`. |
| `APPLE_TEAM_ID` | The 10-character Apple Developer Team ID that owns the certificate (shown in the certificate name and at developer.apple.com > Membership). |
| `APPSTORE_API_KEY_P8_BASE64` | An App Store Connect API key (`AuthKey_<KEYID>.p8`), base64 encoded (`base64 -i AuthKey_XXXX.p8 \| pbcopy`). Used only for notarization. |
| `APPSTORE_API_KEY_ID` | The Key ID of that API key. |
| `APPSTORE_API_ISSUER_ID` | The Issuer ID shown above the key list in App Store Connect. |

The workflow passes secrets to steps through environment variables only and
masks the values it derives from them (keychain password, team ID, identity
hash).

## Rotating the certificate

Developer ID Application certificates are valid for five years. Apps that were
signed with a secure timestamp keep working after the certificate expires.

1. Create a new Developer ID Application certificate (Xcode > Settings >
   Accounts > Manage Certificates, or developer.apple.com > Certificates).
2. In Keychain Access, export the certificate together with its private key as
   a `.p12` with a strong password.
3. Update `MACOS_CERTIFICATE_P12_BASE64` and `MACOS_CERTIFICATE_PASSWORD`.
   `APPLE_TEAM_ID` stays the same unless the team changes.
4. Run a dry run (see above) and check that it signs and notarizes.
5. Delete the local `.p12` export. Only revoke the old certificate if it was
   compromised: revoking a Developer ID certificate can stop copies that are
   already installed from launching.

## Rotating the App Store Connect API key

1. App Store Connect > Users and Access > Integrations > App Store Connect API
   > Team Keys: generate a new key (the Developer role is enough for
   notarization) and download the `.p8`. It can only be downloaded once.
2. Update `APPSTORE_API_KEY_P8_BASE64` and `APPSTORE_API_KEY_ID`.
   `APPSTORE_API_ISSUER_ID` does not change.
3. Run a dry run to confirm notarization works.
4. Revoke the old key in App Store Connect and delete the local `.p8`.

## Building locally

`bash Scripts/build_app.sh` still makes an ad-hoc signed build for testing.
To sign locally with your own Developer ID certificate (from your login
keychain), set `SIGN_IDENTITY`:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" bash Scripts/build_app.sh
```

Notarizing locally works with the same script the workflow uses:

```sh
NOTARY_KEY_PATH=~/keys/AuthKey_XXXX.p8 NOTARY_KEY_ID=XXXX NOTARY_ISSUER_ID=... \
  bash Scripts/notarize.sh build/Multipaste-<version>.zip
xcrun stapler staple build/Multipaste.app
```
