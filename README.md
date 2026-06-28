# Toucher

Toucher is a personal macOS menu bar app for fast window movement with hotkeys and experimental raw trackpad gestures.

Current v0.5.2 behavior:

- Control + Shift + Left Arrow: move active window to left half of current visible screen.
- Control + Shift + Right Arrow: move active window to right half of current visible screen.
- Control + Shift + Up Arrow: maximize to the current visible screen.
- Control + Shift + Up Arrow twice quickly: full-height centered one-third width.
- Control + Shift + Down Arrow: restore previous frame.
- Three-finger swipe left/right: move active window left/right using the raw multitouch backend.
- Command with left/right hotkey or gesture: snap to the other or next screen.
- Animation is experimental and disabled by default.

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
