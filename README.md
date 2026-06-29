# Toucher

Toucher is a personal macOS menu bar app for fast window movement with hotkeys and experimental raw trackpad gestures.

Current v0.5.7 behavior:

- Control + Shift + Left Arrow: move active window to left half of current visible screen.
- Control + Shift + Right Arrow: move active window to right half of current visible screen.
- Control + Shift + Up Arrow: maximize to the current visible screen.
- Control + Shift + Up Arrow twice quickly: full-height centered one-third width.
- Control + Shift + Down Arrow: restore previous frame.
- Three-finger swipe left/right: move active window left/right using the raw multitouch backend.
- Three-finger swipe up: maximize to the current visible screen.
- Command with left/right hotkey or gesture: snap to the other or next screen.
- Window movement can use discrete AX set-frame animation. The default is enabled with 32 steps and a 0.10 second requested duration.

Toucher is not intended for the App Store. The raw gesture backend uses private macOS `MultitouchSupport.framework`, isolated in `WindowGesturesMac`.

## Local debug

```bash
make check
make run-debug
```

The debug app installs to:

`~/Applications/Toucher.app`

Bundle id:

`com.amilabs.Toucher`

Accessibility permission must be granted to `~/Applications/Toucher.app`.

Status bar menu:

- About Toucher
- Settings
- Quit Toucher

Settings contains the user-facing controls for gestures and movement, plus buttons for `Accessibility Settings…` and `Gesture Diagnostics…`.

If Accessibility access is toggled off and then back on, Toucher re-checks `AXIsProcessTrusted()` live and should recover without an app restart.

## Gesture backend selection

```bash
WINDOWGESTURES_GESTURE_BACKEND=raw make run-debug
WINDOWGESTURES_GESTURE_BACKEND=public make run-debug
WINDOWGESTURES_GESTURE_BACKEND=off make run-debug
```

Raw multitouch is the default backend. Public NSEvent diagnostics are inactive by default in normal raw mode.

## Docs

- `docs/manual-test.md`
- `docs/gestures.md`
- `docs/signing.md`
- `docs/dev-workflow.md`
