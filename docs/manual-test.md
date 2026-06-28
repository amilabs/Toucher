# Toucher manual test

## v0.5.3 smoke test

Fresh run:

```bash
pkill -x Toucher || true
make run-debug
```

Expected menu state:

- `Toucher version: 0.5.3`
- `Accessibility trusted: yes`
- `App bundle id: com.amilabs.Toucher`
- `App bundle path: ~/Applications/Toucher.app`
- `Gesture backend: raw multitouch`
- `Raw multitouch active: yes`

Expected settings defaults:

- gestures enabled: yes
- backend: raw
- diagnostics: off
- animation: off

If Accessibility is not trusted, run:

```bash
tccutil reset Accessibility com.amilabs.Toucher
```

Then remove old WindowGestures entries and add `~/Applications/Toucher.app` in System Settings > Privacy & Security > Accessibility. Quit and reopen Toucher after granting permission.

## Settings stability

Fresh reset:

```bash
pkill -x Toucher || true
defaults delete com.amilabs.Toucher || true
make run-debug
```

Test:

1. Open Settings.
2. Toggle Enable diagnostics/probe on and off.
3. App must not crash.
4. Toggle Invert gesture direction on and off.
5. App must not crash.
6. Change raw minimum distance.
7. App must not crash.
8. Toggle Animation enabled on.
9. App must not crash.
10. Toggle Animation enabled off.
11. App must not crash.
12. Open Gesture Diagnostics.
13. App must not crash.
14. Close Gesture Diagnostics.
15. App must not crash.

## Animation off

1. Open a normal resizable app window, such as TextEdit or Finder.
2. Confirm animation is off in Settings.
3. Press Control + Shift + Left Arrow.
4. Confirm the active window moves to the left half.
5. Press Control + Shift + Right Arrow.
6. Confirm the active window moves to the right half.
7. Press Control + Shift + Up Arrow once.
8. Confirm the active window maximizes to the visible frame.
9. Press Control + Shift + Up Arrow twice quickly.
10. Confirm the window becomes full visible height and centered at one third visible width.
11. Swipe exactly three fingers left.
12. Confirm the active window moves to the left half.
13. Swipe exactly three fingers right.
14. Confirm the active window moves to the right half.
15. Swipe exactly three fingers up.
16. Confirm the window maximizes to the full visible screen.
17. Press Control + Shift + Down Arrow.
18. Confirm the window restores to its original frame.

## Animation on

1. Open Settings.
2. Enable `Animation enabled (experimental)`.
3. Set duration to `0.30`.
4. Repeat the hotkeys and raw gestures from the animation-off test.
5. Confirm movement is smooth and visible.
6. Confirm the app does not crash.
7. Confirm gestures and hotkeys still work.
8. Disable animation.
9. Confirm immediate movement works again.

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

1. Choose `Open Gesture Diagnostics`.
2. Confirm the window title is `Toucher Gesture Diagnostics`.
3. Confirm raw diagnostics appear before public NSEvent diagnostics.
4. Perform three-finger left, right, and up gestures.
5. Confirm these counters update:
   - total raw callbacks
   - total recognized gestures
   - left gestures
   - right gestures
   - up gestures
   - ignored gestures
   - unsupported finger count
   - canceled gestures
6. Confirm timing fields show:
   - minHorizontalDistance
   - minVerticalDistance
   - dominanceRatio
   - maxGestureDuration
   - cooldown
   - last gesture duration
   - start and end/trigger timestamps
   - accepted/rejected state and rejection reason

Diagnostics mode can increase CPU. Normal idle mode should stay low because public NSEvent diagnostics are off by default, the diagnostics window is throttled, and no timers run while idle.

## CPU check

Run:

```bash
make debug-cpu-note
```

Then check Toucher in Activity Monitor or with the printed `top` command. If CPU remains high in normal idle mode with diagnostics closed, profile with Instruments in a follow-up pass.
