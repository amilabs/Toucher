# Toucher Gestures and Hotkeys

Toucher supports both keyboard shortcuts and trackpad gestures. Hotkeys remain available even if gesture monitoring is disabled or unavailable.

## User-Facing Gesture Behavior

Trackpad gestures:

- Three-finger swipe left: move the active window to the left half of the current visible screen.
- Three-finger swipe right: move the active window to the right half of the current visible screen.
- Three-finger swipe up: maximize the active window on the current visible screen.

Three-finger swipe down is not implemented.

## Hotkey Behavior

Keyboard shortcuts:

- Control + Shift + Left Arrow: left half.
- Control + Shift + Right Arrow: right half.
- Control + Shift + Up Arrow: maximize.
- Control + Shift + Up Arrow twice quickly: full-height centered one-third width.
- Control + Shift + Down Arrow: restore previous frame.

## Command Modifier Behavior

Holding Command with a left/right hotkey or gesture targets another screen:

- With two screens, Toucher targets the other screen.
- With more than two screens, Toucher targets the next screen in deterministic frame order.
- With one screen, Toucher stays on the current screen.

## Raw Multitouch Backend Notes

The primary gesture backend uses macOS `MultitouchSupport.framework` to detect exact three-finger gestures.

Implementation constraints:

- private API calls are isolated in `Sources/WindowGesturesMac/RawMultitouchBackend.swift`
- the framework is loaded dynamically
- the backend is event-driven
- hotkeys continue to work if raw multitouch is unavailable

This private API is the reason Toucher is not App Store compatible.

## Public NSEvent Diagnostics

Toucher also contains a public AppKit NSEvent backend for diagnostics and fallback investigation.

Public AppKit gesture events may not reliably expose exact three-finger swipes. Public scroll events can arrive for both two-finger and three-finger movement, so they are not used as the primary gesture source.

Public NSEvent diagnostics are off by default in normal use.

## Backend Selection for Development

Normal Settings does not expose backend selection.

For development:

```bash
WINDOWGESTURES_GESTURE_BACKEND=raw make run-debug
WINDOWGESTURES_GESTURE_BACKEND=public make run-debug
WINDOWGESTURES_GESTURE_BACKEND=off make run-debug
```

## Troubleshooting

If gestures do not work:

1. Confirm `Enable trackpad gestures` is enabled in Settings.
2. Confirm Toucher has Accessibility permission.
3. Quit BetterTouchTool while testing.
4. Disable conflicting macOS Trackpad > More Gestures actions.
5. Disable System Settings > Accessibility > Pointer Control > Trackpad Options > Three Finger Drag.
6. Open Gesture Diagnostics from Settings and check backend status.

If hotkeys work but gestures do not, window movement is working and the problem is gesture input.
