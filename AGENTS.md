# AGENTS.md

## Current Baseline

Toucher is a small macOS menu bar app for personal/public non-App-Store distribution.

v0.5 supports:

- Control + Shift + Left Arrow -> left half of current visible screen
- Control + Shift + Right Arrow -> right half of current visible screen
- Control + Shift + Up Arrow -> maximize on current visible screen
- Control + Shift + Double Up -> full-height centered one-third width
- Control + Shift + Down Arrow -> restore previous frame
- Three-finger raw multitouch swipe left/right -> left/right half
- Command modifier with left/right hotkey or gesture -> target other/next screen

No App Store support.
No sandbox requirement.
No auto-updater.
No launch at login.
No notarization yet.

## Architecture

Keep the app split into these layers:

- WindowGesturesCore
  - pure Swift logic
  - no AppKit
  - no Accessibility API
  - no Carbon
  - no private MultitouchSupport calls
  - no CoreGraphics event taps

- WindowGesturesMac
  - macOS adapters
  - Accessibility API
  - hotkey registration
  - active-window detection
  - raw MultitouchSupport backend isolated in `RawMultitouchBackend.swift`

- WindowGesturesApp
  - menu bar app
  - permissions UI
  - settings and diagnostics windows
  - app lifecycle

## Required Abstractions

Use protocols for system boundaries:

- HotKeyRegistering
- PermissionChecking
- WindowControlling
- GestureMonitoring

Core logic must be testable without real macOS permissions.

## Gesture Rules

Raw multitouch is the primary gesture backend for v0.5.

Private `MultitouchSupport.framework` usage is allowed because Toucher is not for the App Store, but all private API calls must remain isolated in `WindowGesturesMac/RawMultitouchBackend.swift` or a small dedicated adapter folder.

Public NSEvent gesture diagnostics should stay available but must not run in normal idle mode unless selected or diagnostics explicitly enable them.

Do not use CGEventTap unless explicitly requested.
Do not record arbitrary keyboard input.
Do not implement key logging.

## Window Rules

Use the visible screen frame, not the full display frame.
Account for menu bar and Dock.

Default snapping must stay on the active window's current screen.
Screen selection should prefer the screen containing the window center, then largest intersection, then fallback only as a last resort.

If the active window cannot be controlled, fail gracefully and show a menu status message or diagnostic state.

## Permissions

The app must check Accessibility permission before trying to move windows.

If permission is missing:

- do not crash
- show a clear status in Settings and diagnostics
- provide an `Accessibility Settings…` action in Settings
- recover when `AXIsProcessTrusted()` changes from false to true without requiring an app restart

## CPU

No polling.
No spin loops.
No timers while idle except OS callbacks.
Diagnostics UI updates should be throttled and only run while the diagnostics window is open.

## Tests

Every behavior change must include tests.

Required areas:

- hotkey mapping
- raw gesture recognition
- screen selection
- restore behavior
- permission denied/no active window paths
- animation planning

## Commands

Before finishing:

```bash
make check
```

For core-only changes:

```bash
swift test
```

## Git Workflow

Do not commit or push without explicit user request.

For git operations, Codex should ask for approval once for the whole git batch, not once per individual git command. After approval, run git commands in one shell block where possible.

Typical approved batch:

```bash
git status
git add ...
git commit ...
git pull --rebase origin main
git push
```

If the Codex client/tooling enforces per-command approval, group commands into one script block where allowed.

Never commit:

- `.build/`
- `*.app`
- `.DS_Store`
- derived data
- logs
