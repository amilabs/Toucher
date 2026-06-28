# Toucher manual test

## v0.5.2 smoke test

1. Run `make run-debug`.
2. Confirm Toucher appears as an icon only in the menu bar, not as text and not as a Dock app.
3. Open the Toucher menu and confirm:
   - `Toucher version: 0.5.2`
   - `Accessibility trusted: yes`
   - `App bundle id: com.amilabs.Toucher`
   - `App bundle path: ~/Applications/Toucher.app`
   - `Gesture backend: raw multitouch`
   - `Raw multitouch active: yes`
4. If Accessibility is not trusted, run:

```bash
tccutil reset Accessibility com.amilabs.Toucher
```

Then remove old WindowGestures entries and add `~/Applications/Toucher.app` in System Settings > Privacy & Security > Accessibility. Quit and reopen Toucher after granting permission.

## v0.5.2 settings crash smoke test

Fresh reset:

```bash
pkill -x Toucher || true
defaults delete com.amilabs.Toucher || true
make run-debug
```

Expected defaults:

- gestures enabled: yes
- backend: raw
- diagnostics: off
- animation: off

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
12. With animation off, verify:
    - Ctrl+Shift+Left works
    - Ctrl+Shift+Right works
    - three-finger left/right works
13. Open Gesture Diagnostics.
14. App must not crash.
15. Close Gesture Diagnostics.
16. App must not crash.

## Hotkeys

1. Open a normal resizable app window, such as TextEdit or Finder.
2. Press Control + Shift + Left Arrow.
3. Confirm the active window moves to the left half of its current monitor.
4. Press Control + Shift + Right Arrow.
5. Confirm the active window moves to the right half of its current monitor.
6. Press Control + Shift + Up Arrow once.
7. Confirm the active window maximizes to the visible frame of its current monitor.
8. Press Control + Shift + Up Arrow twice quickly.
9. Confirm the window becomes full visible height and centered at one third visible width.
10. Press Control + Shift + Down Arrow.
11. Confirm the window restores to its original frame.

## Raw gestures

1. Quit BetterTouchTool for clean testing.
2. Disable conflicting macOS Trackpad > More Gestures actions.
3. Disable System Settings > Accessibility > Pointer Control > Trackpad Options > Three Finger Drag.
4. Open TextEdit and make it active.
5. Swipe exactly three fingers left.
6. Confirm the window moves to the left half.
7. Swipe exactly three fingers right.
8. Confirm the window moves to the right half.
9. Try two fingers left and right.
10. Confirm the window does not move.
11. Try four fingers left and right.
12. Confirm the window does not move.

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

## Animation

1. Open Settings.
2. Confirm `Animation enabled (experimental)` is off after a fresh defaults reset.
3. With animation off, trigger hotkey and raw gesture actions.
4. Confirm movement is immediate and reliable.
5. Enable animation and set duration near `0.25`.
6. Confirm hotkeys and gestures still execute without crashing.
7. Disable animation again before final normal-use testing.

## Settings persistence

1. Open `Open Settings`.
2. Change:
   - `Enable gestures`
   - `Gesture backend`
   - `Enable diagnostics/probe`
   - `Invert gesture direction`
   - `Animation enabled`
   - `Animation duration`
   - raw distance, dominance, and cooldown values
3. Quit Toucher.
4. Run `make run-debug`.
5. Confirm settings persist after restart.

## Gesture diagnostics

1. Choose `Open Gesture Diagnostics`.
2. Confirm the window title is `Toucher Gesture Diagnostics`.
3. Confirm raw diagnostics appear before public NSEvent diagnostics.
4. Perform raw gestures and confirm these counters update:
   - total raw callbacks
   - total recognized gestures
   - left gestures
   - right gestures
   - ignored gestures
   - unsupported finger count
   - canceled gestures
5. Confirm timing fields show:
   - minHorizontalDistance
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
