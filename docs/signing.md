# Toucher local signing

macOS Accessibility/TCC trust is sensitive to the app's code identity. Ad-hoc signing is useful for quick experiments, but it is unstable for local Accessibility development because each rebuild can look like a different app to TCC.

For local debug builds, sign Toucher with a stable local Code Signing certificate. The current Makefile default is:

`WindowGestures Local Dev`

The certificate name is intentionally unchanged for now to avoid requiring a new local signing identity. The app identity is controlled by the bundle id:

`com.amilabs.Toucher`

## Create the certificate

1. Open Keychain Access.
2. Choose Certificate Assistant > Create a Certificate.
3. Set the certificate name to `WindowGestures Local Dev`.
4. Set Identity Type to `Self Signed Root`.
5. Set Certificate Type to `Code Signing`.
6. Create the certificate in your login keychain.

Confirm the identity is available:

```bash
security find-identity -v -p codesigning
```

## Install and run debug

```bash
make run-debug
```

This installs and signs:

`~/Applications/Toucher.app`

To intentionally use ad-hoc signing for a one-off debug run:

```bash
make run-debug SIGN_IDENTITY=-
```

Do not use ad-hoc signing for normal Accessibility/TCC testing.

## Reset Accessibility after rename

The v0.5 rename changes the bundle id from `com.amilabs.WindowGestures` to:

`com.amilabs.Toucher`

Reset TCC once:

```bash
tccutil reset Accessibility com.amilabs.Toucher
```

Then open System Settings > Privacy & Security > Accessibility:

1. Remove old WindowGestures entries.
2. Remove entries pointing to `.build/debug/WindowGestures.app`, `/Applications/WindowGestures.app`, or `~/Applications/WindowGestures.app`.
3. Add `~/Applications/Toucher.app`.
4. Toucher should recover without a restart after Accessibility is enabled. If macOS still reports stale TCC state, quit and reopen Toucher as a fallback.

## Inspect signing

```bash
make debug-signing-info
make debug-verify-bundle
```
