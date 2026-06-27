# WindowGestures local signing

macOS Accessibility/TCC trust is sensitive to the app's code identity. Ad-hoc signing is useful for quick experiments, but it is unstable for local Accessibility development because each rebuild can look like a different app to TCC even when the bundle id and path stay the same.

For local debug builds, sign WindowGestures with a stable local Code Signing certificate named:

`WindowGestures Local Dev`

## Create the certificate

1. Open Keychain Access.
2. Choose Certificate Assistant > Create a Certificate.
3. Set the certificate name to `WindowGestures Local Dev`.
4. Set Identity Type to `Self Signed Root`.
5. Set Certificate Type to `Code Signing`.
6. Create the certificate in your login keychain.
7. If macOS asks for trust settings, keep the default settings unless signing fails.

Confirm the identity is available:

```bash
security find-identity -v -p codesigning
```

The output must list `WindowGestures Local Dev` as a valid identity. If it reports `0 valid identities found`, `make run-debug` will fail until the certificate exists and is trusted for code signing.

## Install and run debug

Run:

```bash
make run-debug
```

This installs the debug app to:

`~/Applications/WindowGestures.app`

and signs it with:

`WindowGestures Local Dev`

To intentionally use ad-hoc signing for a one-off debug run, pass it explicitly:

```bash
make run-debug SIGN_IDENTITY=-
```

Do not use ad-hoc signing for normal Accessibility/TCC testing.

## Reset Accessibility once

After switching from ad-hoc signing or changing the local certificate, reset TCC once:

```bash
tccutil reset Accessibility com.amilabs.WindowGestures
```

Then open System Settings > Privacy & Security > Accessibility, remove stale WindowGestures entries, and re-add:

`~/Applications/WindowGestures.app`

After that, Accessibility trust should survive rebuilds as long as the bundle id, app path, and signing identity remain stable.

## Inspect signing

Run:

```bash
make debug-signing-info
```

It prints available code signing identities, the installed app's signing details, and strict codesign verification.
