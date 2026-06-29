# Toucher Signing and Distribution

Toucher is distributed outside the App Store. Signing and notarization are separate from Accessibility permission: users still need to enable Accessibility access after installing Toucher.

## Local Development Signing

macOS TCC/Accessibility trust is sensitive to code identity. For reliable local testing, Toucher should be signed with a stable local Code Signing certificate.

The Makefile default is:

```text
SIGN_IDENTITY ?= WindowGestures Local Dev
```

This is a legacy certificate name kept for existing local machines. The current app bundle id is:

```text
com.amilabs.Toucher
```

### Create the Local Certificate

1. Open Keychain Access.
2. Choose Certificate Assistant > Create a Certificate.
3. Set the certificate name to `WindowGestures Local Dev`.
4. Set Identity Type to `Self Signed Root`.
5. Set Certificate Type to `Code Signing`.
6. Create the certificate in the login keychain.

Confirm the identity is available:

```bash
security find-identity -v -p codesigning
```

### Run and Verify

Install, sign, and launch the local debug app:

```bash
make run-debug
```

Verify the installed bundle:

```bash
make debug-verify-bundle
make debug-signing-info
```

The debug app installs to:

```text
~/Applications/Toucher.app
```

### Ad-Hoc Signing

Ad-hoc signing can be used for a one-off debug run:

```bash
make run-debug SIGN_IDENTITY=-
```

Do not use ad-hoc signing for normal Accessibility testing. Rebuilt ad-hoc apps may not preserve macOS TCC trust reliably.

### Accessibility Reset

If Accessibility permission needs to be reset during testing:

```bash
make debug-reset-accessibility
```

Then re-add:

```text
~/Applications/Toucher.app
```

in System Settings > Privacy & Security > Accessibility.

## Public Distribution Outside the App Store

A public macOS build should use Apple Developer ID distribution:

1. Sign with a `Developer ID Application` certificate.
2. Enable Hardened Runtime.
3. Submit the signed app or archive for notarization with `notarytool`.
4. Staple the notarization ticket.
5. Package the final app as a zip, DMG, or PKG.
6. Upload the package as a GitHub Release asset.

Do not store Apple credentials, team secrets, notary passwords, or API keys in the repository.

Suggested final verification:

```bash
codesign --verify --deep --strict --verbose=2 Toucher.app
spctl --assess --type execute --verbose Toucher.app
xcrun stapler validate Toucher.app
```

Accessibility permission is still required after Developer ID signing and notarization.

## Legacy Migration Note

Older local builds used the WindowGestures name and bundle id. Current builds should use:

```text
Toucher.app
com.amilabs.Toucher
```

Remove old Accessibility entries only if they point to obsolete WindowGestures app copies or old debug paths.
