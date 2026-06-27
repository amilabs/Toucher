# AGENTS.md

## Current MVP

Build a small macOS menu bar app for personal/public non-App-Store distribution.

v1 supports only two global hotkeys:

- Control + Shift + Left Arrow -> move active window to left half of visible screen
- Control + Shift + Right Arrow -> move active window to right half of visible screen

No gestures in v1.
No App Store support in v1.
No sandbox requirement in v1.
No auto-updater in v1.

## Architecture

Keep the app split into these layers:

- WindowGesturesCore
  - pure Swift logic
  - no AppKit
  - no Accessibility API
  - no Carbon
  - no CoreGraphics event taps

- WindowGesturesMac
  - macOS adapters
  - Accessibility API
  - hotkey registration
  - active-window detection

- WindowGesturesApp
  - menu bar app
  - permissions UI
  - app lifecycle

## Required abstractions

Use protocols for system boundaries:

- HotKeyRegistering
- PermissionChecking
- WindowControlling

Core logic must be testable without real macOS permissions.

## Hotkey rules

For v1, register these shortcuts:

- Control + Shift + Left Arrow
- Control + Shift + Right Arrow

Prefer RegisterEventHotKey for v1.

Do not use CGEventTap unless absolutely necessary.
Do not record arbitrary keyboard input.
Do not implement key logging.
Do not use private APIs.

## Window rules

Use the visible screen frame, not the full display frame.
Account for menu bar and Dock.

If the active window cannot be controlled, fail gracefully and show a menu bar status message or log.

## Permissions

The app must check Accessibility permission before trying to move windows.

If permission is missing:
- do not crash
- show a clear status
- provide an "Open Accessibility Settings" action

## Tests

Every change to behavior must include tests.

Required tests:
- Control + Shift + Left maps to leftHalf
- Control + Shift + Right maps to rightHalf
- leftHalf frame calculation
- rightHalf frame calculation
- visible screen frame is used
- permission denied path does not crash
- no action is executed if no active window exists

## Commands

Before finishing, run:

```bash
make check