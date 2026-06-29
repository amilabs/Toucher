# AGENTS.md

## Current Baseline

Toucher is a macOS menu bar utility for moving and resizing windows with hotkeys and trackpad gestures. It is distributed outside the App Store.

Supported behavior:

- Control + Shift + Left Arrow -> left half of current visible screen
- Control + Shift + Right Arrow -> right half of current visible screen
- Control + Shift + Up Arrow -> maximize on current visible screen
- Control + Shift + Double Up -> full-height centered one-third width
- Control + Shift + Down Arrow -> restore previous frame
- Three-finger swipe left/right -> left/right half
- Three-finger swipe up -> maximize
- Command modifier with left/right hotkey or gesture -> target other/next screen

Do not add unrelated product features unless explicitly requested:

- no auto-updater
- no launch at login
- no cloud sync
- no gesture editor

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
  - raw MultitouchSupport adapter isolated in `RawMultitouchBackend.swift` or a small dedicated adapter folder

- WindowGesturesApp
  - menu bar app
  - permissions UI
  - Settings and Gesture Diagnostics windows
  - app lifecycle

## Required Abstractions

Use protocols for system boundaries:

- HotKeyRegistering
- PermissionChecking
- WindowControlling
- GestureMonitoring

Core logic must be testable without real macOS permissions.

## Gesture Rules

Raw multitouch is the primary gesture backend.

Private `MultitouchSupport.framework` usage is allowed because Toucher is not App Store compatible, but all private API calls must remain isolated in `WindowGesturesMac/RawMultitouchBackend.swift` or a small dedicated adapter folder.

Public NSEvent gesture diagnostics may remain available, but must not run in normal idle mode unless diagnostics explicitly enable them.

Do not use CGEventTap unless explicitly requested.
Do not record arbitrary keyboard input.
Do not implement key logging.

## Window Rules

Use the visible screen frame, not the full display frame. Account for the menu bar and Dock.

Default snapping must stay on the active window's current screen. Screen selection should prefer the screen containing the window center, then largest intersection, then fallback only as a last resort.

Never pass raw `NSScreen.visibleFrame` directly into Accessibility set-frame calls without using the coordinate conversion layer.

If the active window cannot be controlled, fail gracefully and show status in Settings or Gesture Diagnostics.

## Accessibility

The app must check Accessibility permission before trying to move windows.

Requirements:

- all movement paths live-check trust before AX work
- false -> true Accessibility transitions must recover without app restart
- true -> false Accessibility transitions must update Settings and the status menu without app restart when macOS reports the change
- status menu and Settings must update from live permission checks
- if a real AX action fails with `accessibilityPermissionMissing`, runtime must enter the untrusted state and start recovery monitoring
- do not permanently stop hotkeys or gesture recognition just because Accessibility is missing

If permission is missing:

- do not crash
- do not move windows
- show `⚠ Settings — Accessibility required` in the status menu
- show `Accessibility: Not enabled` in Settings
- provide an `Accessibility Settings…` action in Settings

## CPU

No idle polling.
No spin loops.
No timers while idle except OS callbacks.

Temporary Accessibility trust polling is allowed only while Accessibility is untrusted/waiting or while Settings is open for permission recovery. It must stop after trust returns and Settings is closed.

Diagnostics UI updates should be throttled and only run while the diagnostics window is open.

## Tests

Every behavior change must include tests.

Required areas:

- hotkey mapping
- raw gesture recognition
- screen selection
- coordinate conversion
- restore behavior
- permission denied/no active window paths
- Accessibility false/true recovery
- movement planning
- Settings/menu presentation models

## Commands

Before finishing:

```bash
make check
```

For core-only changes:

```bash
swift test
```

For app bundle verification when local signing is available:

```bash
make debug-verify-bundle
```

## Git Workflow

Do not commit or push without explicit user request.

For git operations, Codex should ask for approval once for the whole git batch, not once per individual git command. After approval, run git commands in one shell block where possible.

Typical approved batch:

```bash
git status
git add ...
git commit -m "..."
git pull --rebase origin main
git push origin main
```

If the Codex client/tooling enforces per-command approval, group commands into one script block where allowed.

Never commit:

- `.build/`
- `*.app`
- `dist/`
- `.DS_Store`
- DerivedData
- logs
