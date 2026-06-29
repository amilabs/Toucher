# Toucher Development Workflow

This document is the canonical workflow for local development, verification, and release preparation.

## Common Commands

Run all unit tests:

```bash
swift test
```

Run the standard project check:

```bash
make check
```

`make check` runs:

```bash
swift test
swift build -c debug
```

Build the app bundle in `.build/<configuration>/Toucher.app`:

```bash
make build
```

Run the signed local app:

```bash
make run-debug
```

Verify the installed debug bundle:

```bash
make debug-verify-bundle
```

Reset Accessibility permission for Toucher:

```bash
make debug-reset-accessibility
```

Inspect signing information:

```bash
make debug-signing-info
```

Clean SwiftPM build output:

```bash
make clean
```

## Makefile Behavior

Current Makefile values:

- `APP_NAME`: `Toucher`
- `BUNDLE_ID`: `com.amilabs.Toucher`
- `APP_VERSION`: `0.5.7`
- `INSTALL_APP`: `$(HOME)/Applications/Toucher.app`
- `SIGN_IDENTITY`: `WindowGestures Local Dev`

`make run-debug` installs Toucher to:

```text
~/Applications/Toucher.app
```

Debug install targets may stop existing processes named:

- `WindowGesturesApp`
- `WindowGestures`
- `Toucher`

`make debug-verify-bundle` is not read-only. It depends on `install-debug`, so it rebuilds, reinstalls, signs, and replaces `~/Applications/Toucher.app` before printing verification output.

## Signing Identity

The default local signing identity is:

```text
WindowGestures Local Dev
```

This is a legacy certificate name kept for local continuity. The current app identity is controlled by:

```text
com.amilabs.Toucher
```

For a one-off local run only, ad-hoc signing can be requested explicitly:

```bash
make run-debug SIGN_IDENTITY=-
```

Do not use ad-hoc signing for normal Accessibility testing because macOS TCC is sensitive to code identity.

## Gesture Backend Overrides

Normal development should use the default backend.

For targeted backend checks:

```bash
WINDOWGESTURES_GESTURE_BACKEND=raw make run-debug
WINDOWGESTURES_GESTURE_BACKEND=public make run-debug
WINDOWGESTURES_GESTURE_BACKEND=off make run-debug
```

Hotkeys remain active regardless of gesture backend state.

## Accessibility Test Flow

When checking real macOS permission behavior:

```bash
make debug-reset-accessibility
make run-debug
```

Then add `~/Applications/Toucher.app` in System Settings > Privacy & Security > Accessibility.

Toucher should update Settings and the status menu without restarting after Accessibility changes.

## Release Preparation

Before a release candidate:

```bash
make check
make debug-verify-bundle
```

Then run the manual checklist in:

```text
docs/manual-test.md
```

There is currently no Makefile target for release archives, Developer ID signing, notarization, stapling, or uploading GitHub Release assets. If release packaging is automated later, add explicit targets and document their side effects here.

Generated archives belong in:

```text
dist/
```

`dist/` is ignored and must not be committed.

## Git Workflow

Do not commit or push without an explicit user request.

When the user explicitly asks to update GitHub, ask for approval once for the whole git batch where tooling allows it. A typical batch is:

```bash
git status
git add ...
git commit -m "..."
git pull --rebase origin main
git push origin main
```

Never commit:

- `.build/`
- `*.app`
- `dist/`
- `.DS_Store`
- DerivedData
- logs

Release archives should be uploaded as GitHub Release assets, not committed to the repository.
