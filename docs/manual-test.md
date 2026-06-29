# Toucher manual test

## v0.5.6 smoke test

Fresh start:

```bash
pkill -x Toucher || true
defaults delete com.amilabs.Toucher || true
make run-debug
```

Expected menu state:

- `Toucher version: 0.5.6`
- `Accessibility trusted: yes`
- `App bundle id: com.amilabs.Toucher`
- `App bundle path: ~/Applications/Toucher.app`
- `Gesture backend: raw multitouch`
- `Raw multitouch active: yes`
- `Last movement mode: immediate`
- no animation setting is visible in Settings

If Accessibility is not trusted, run:

```bash
tccutil reset Accessibility com.amilabs.Toucher
```

Then remove old WindowGestures entries and add `~/Applications/Toucher.app` in System Settings > Privacy & Security > Accessibility. Quit and reopen Toucher after granting permission.

## Settings stability

1. Open Settings.
2. Close Settings.
3. Open Settings again.
4. App must not crash.
5. Change every visible setting one by one.
6. App must not crash.
7. Close and reopen Settings again.
8. App must not crash.

Visible settings:

- Enable gestures
- Gesture backend
- Enable diagnostics/probe
- Invert gesture direction
- Raw gesture minimum distance
- Raw gesture dominance ratio
- Raw gesture cooldown

## Gesture and hotkey test

1. Open a normal resizable app window, such as TextEdit or Finder.
2. Press Control + Shift + Left Arrow.
3. Confirm the active window moves immediately to the left half.
4. Press Control + Shift + Right Arrow.
5. Confirm the active window moves immediately to the right half.
6. Press Control + Shift + Up Arrow once.
7. Confirm the active window maximizes to the visible frame.
8. Press Control + Shift + Up Arrow twice quickly.
9. Confirm the window becomes full visible height and centered at one third visible width.
10. Press Control + Shift + Down Arrow.
11. Confirm the window restores to its original frame.
12. Swipe exactly three fingers left.
13. Confirm the active window moves immediately to the left half.
14. Swipe exactly three fingers right.
15. Confirm the active window moves immediately to the right half.
16. Swipe exactly three fingers up.
17. Confirm the window maximizes to the full visible screen.

Note: three-finger up and Control + Shift + Up both maximize. Control + Shift + Up twice quickly is the separate centered one-third-width action.

## Raw gesture rejection

1. Quit BetterTouchTool for clean testing.
2. Disable conflicting macOS Trackpad > More Gestures actions.
3. Disable System Settings > Accessibility > Pointer Control > Trackpad Options > Three Finger Drag.
4. Try two fingers left, right, and up.
5. Confirm the window does not move.
6. Try four fingers left, right, and up.
7. Confirm the window does not move.

## Multi-monitor and Cmd modifier

1. Place a test window on a secondary monitor.
2. Press Control + Shift + Left Arrow.
3. Confirm the window snaps on the secondary monitor and does not jump to the main monitor.
4. Place a window partially across two monitors.
5. Confirm snapping uses the monitor containing the window center. If the center is not on a monitor, confirm it uses the monitor with the largest intersection.
6. Hold Command and press Control + Shift + Left Arrow or Control + Shift + Right Arrow.
7. With two monitors, confirm the window snaps to the other monitor.
8. With more than two monitors, confirm the target is the next monitor in deterministic minX/minY order.
9. Hold Command and perform a three-finger left or right swipe.
10. Confirm the gesture snaps left/right on the other or next monitor.

## Gesture diagnostics

1. Open Gesture Diagnostics.
2. Close Gesture Diagnostics.
3. Open Gesture Diagnostics again.
4. App must not crash.
5. Perform three-finger left, right, and up gestures.
6. Confirm these counters update:
   - total raw callbacks
   - total recognized gestures
   - left gestures
   - right gestures
   - up gestures
7. Confirm Last accepted gesture, Last accepted dx/dy, and Last accepted duration update.
8. Move with two or four fingers.
9. Confirm unsupported finger count increases but Last 10 raw events are not filled with continuous two-finger/four-finger noise.
10. Confirm movement diagnostics show:
   - last movement mode: immediate
   - target frame
   - final readback frame if available
   - movement error

Diagnostics mode can increase CPU. Normal idle mode should stay low because public NSEvent diagnostics are off by default, the diagnostics window is throttled, and no movement timers run while idle.

## CPU check

Run:

```bash
make debug-cpu-note
```

Then check Toucher in Activity Monitor or with the printed `top` command.
