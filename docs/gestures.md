# Toucher gesture backends

Toucher keeps gesture input behind the `GestureMonitoring` protocol so hotkeys, window movement, and gesture capture remain separate.

## Raw multitouch backend

`RawMultitouchBackend` is the default v0.5.2 backend. It uses private macOS `MultitouchSupport.framework` to detect exact three-finger horizontal swipes.

Implications:

- Toucher is not App Store compatible.
- The private API may break on future macOS versions.
- Private API calls are isolated in `Sources/WindowGesturesMac/RawMultitouchBackend.swift`.
- The framework is loaded dynamically with `dlopen`/`dlsym`.
- If the framework, symbols, devices, or expected touch data are unavailable, Toucher fails gracefully and hotkeys continue to work.

The raw backend is event-driven. It processes incoming touch callbacks and does not poll, spin, or use timers for input collection.

## Public NSEvent backend

`PublicNSEventSwipeBackend` remains available for diagnostics and fallback. It uses public AppKit APIs:

- `NSEvent.addGlobalMonitorForEvents`
- `NSEvent.addLocalMonitorForEvents`

Observed limitation: public `swipe` events may never arrive for trackpad three-finger swipe settings. Public `scrollWheel` events can arrive for both two-finger and three-finger movement, so `scrollWheel` cannot reliably identify exact three-finger gestures.

Public NSEvent diagnostics are off by default in normal raw mode to reduce idle CPU usage.

## Backend selection

Use Settings or set `WINDOWGESTURES_GESTURE_BACKEND` before launch:

- `raw`: use raw multitouch.
- `public`: use public NSEvent diagnostics.
- `off`: disable gesture monitoring.

Example:

```bash
WINDOWGESTURES_GESTURE_BACKEND=off make run-debug
```

Hotkeys remain active regardless of gesture backend state.

## Troubleshooting

- Quit BetterTouchTool for clean raw gesture testing.
- Disable conflicting macOS Trackpad > More Gestures actions.
- Disable System Settings > Accessibility > Pointer Control > Trackpad Options > Three Finger Drag.
- Confirm the menu shows `Raw multitouch available: yes` and `Raw multitouch active: yes`.
- If raw is unavailable, record `Last raw error`.
- If active touches are not exactly `3`, the recognizer ignores or cancels the gesture.
- Diagnostics mode can increase CPU because it may enable public NSEvent probes and a diagnostics window. Close diagnostics for normal idle checks.
