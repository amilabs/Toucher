# WindowGestures gesture backends

WindowGestures keeps gesture input behind the `GestureMonitoring` protocol so hotkeys, window movement, and gesture capture remain separate.

## Public NSEvent backend

`PublicNSEventSwipeBackend` uses public AppKit APIs:

- `NSEvent.addGlobalMonitorForEvents`
- `NSEvent.addLocalMonitorForEvents`

It listens for public gesture-like events, including `swipe`, `scrollWheel`, `beginGesture`, `endGesture`, `magnify`, `rotate`, and `smartMagnify`.

Observed limitation: public `swipe` events may never arrive for trackpad three-finger swipe settings. Public `scrollWheel` events can arrive for both two-finger and three-finger movement, so `scrollWheel` cannot reliably identify exact three-finger gestures.

## RawMultitouchBackend

`RawMultitouchBackend` is experimental and uses private macOS `MultitouchSupport.framework`.

Implications:

- It is not App Store compatible.
- It may break on future macOS versions.
- Private API calls are isolated in `Sources/WindowGesturesMac/RawMultitouchBackend.swift`.
- The framework is loaded dynamically with `dlopen`/`dlsym`.
- If the framework, symbols, devices, or expected touch data are unavailable, the backend fails gracefully and hotkeys continue to work.

The raw backend is event-driven. It processes incoming touch callbacks and does not poll, spin, or use timers for input collection.

## Backend selection

Set `WINDOWGESTURES_GESTURE_BACKEND` before launching the app:

- `raw`: use only the raw multitouch backend.
- `public`: use only the public NSEvent backend.
- `off`: disable gesture monitoring.

Default behavior is automatic:

1. Try raw multitouch.
2. Fall back to public NSEvent if raw cannot start.
3. Keep hotkeys active regardless of gesture backend state.

Example:

```bash
WINDOWGESTURES_GESTURE_BACKEND=off make run-debug
```

## Troubleshooting

- Quit BetterTouchTool for clean raw gesture testing.
- Disable conflicting macOS Trackpad > More Gestures actions.
- Disable System Settings > Accessibility > Pointer Control > Trackpad Options > Three Finger Drag.
- Confirm the menu shows `Raw multitouch available: yes` and `Raw multitouch active: yes`.
- If raw is unavailable, record `Last raw error`.
- If raw active touches are not exactly `3`, the recognizer will ignore or cancel the gesture.
