# Toucher manual test

## v0.5.7 release smoke test

Fresh start:

```bash
pkill -x Toucher || true
defaults delete com.amilabs.Toucher || true
make run-debug
```

Expected defaults:

- Animate window movement is enabled.
- Animation steps is `32`.
- Animation duration is `0.10s`.

Expected main menu:

- compact menu, icon only in the menu bar
- first item is `About Toucher`
- `Settings` when Accessibility is trusted
- `⚠ Settings — Accessibility required` when Accessibility is not trusted
- `Quit Toucher`

The main menu should not show long debug rows such as bundle path, raw callback counters, movement frame details, skipped steps, target frame, public NSEvent diagnostics, Gesture Diagnostics, or Accessibility Settings. The only status warning allowed in the menu is the Settings title changing to `⚠ Settings — Accessibility required`.

If Accessibility is not trusted, run:

```bash
tccutil reset Accessibility com.amilabs.Toucher
```

Then remove old WindowGestures entries and add `~/Applications/Toucher.app` in System Settings > Privacy & Security > Accessibility. Toucher should recover after permission is granted without an app restart.

After bundle id, signing, or path changes, macOS may keep a stale Accessibility entry. Do not reset automatically during normal use. For release smoke testing, reset manually with:

```bash
make debug-reset-accessibility
```

Then relaunch Toucher only if macOS still reports stale TCC state after re-adding `~/Applications/Toucher.app` in System Settings > Privacy & Security > Accessibility.

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

- Enable trackpad gestures
- Animate window movement
- Animation steps
- Animation duration
- Accessibility status
- Accessibility Settings…
- Gesture Diagnostics…

Technical backend, raw threshold, and public probe options belong in Gesture Diagnostics or internal defaults, not normal Settings.

## About Toucher

1. Open `About Toucher`.
2. Confirm it shows:
   - Toucher
   - Version `0.5.7`
   - build date
   - `GitHub Repository`
   - no Bundle ID
3. Click the repository link.
4. Confirm it opens GitHub in the default browser.
5. Close and reopen About Toucher.
6. App must not crash.

## Gesture and hotkey test

1. Open a normal resizable app window, such as TextEdit or Finder.
2. Press Control + Shift + Left Arrow.
3. Confirm the active window moves to the left half.
4. Press Control + Shift + Right Arrow.
5. Confirm the active window moves to the right half.
6. Press Control + Shift + Up Arrow once.
7. Confirm the active window maximizes to the visible frame.
8. Press Control + Shift + Up Arrow twice quickly.
9. Confirm the window becomes full visible height and centered at one third visible width.
10. Press Control + Shift + Down Arrow.
11. Confirm the window restores to its original frame.
12. Swipe exactly three fingers left.
13. Confirm the active window moves to the left half.
14. Swipe exactly three fingers right.
15. Confirm the active window moves to the right half.
16. Swipe exactly three fingers up.
17. Confirm the window maximizes to the full visible screen.

Note: three-finger up and Control + Shift + Up both maximize. Control + Shift + Up twice quickly is the separate centered one-third-width action.

If Settings shows Accessibility as not enabled while Toucher is visibly enabled in System Settings, reset TCC manually, re-add Toucher, and retry a real hotkey. Relaunch only if macOS still reports stale TCC state. Unit tests cannot fully validate real TCC permission state.

## Accessibility false-to-true recovery

1. Start Toucher with Accessibility enabled.
2. Open the menu.
3. Confirm it shows only `About Toucher`, `Settings`, and `Quit Toucher`.
4. Press Control + Shift + Left Arrow.
5. Confirm the window moves.
6. Disable Toucher in System Settings > Privacy & Security > Accessibility.
7. Open the menu.
8. Confirm it shows `About Toucher`, `⚠ Settings — Accessibility required`, and `Quit Toucher`.
9. Click `⚠ Settings — Accessibility required`.
10. Confirm Settings opens and System Access shows `Accessibility: Not enabled` with the inline warning visible.
11. Press Control + Shift + Left Arrow or perform a three-finger left swipe.
12. Confirm the window does not move and the app remains responsive.
13. Click `Gesture Diagnostics…` in Settings and confirm:
    - Accessibility trusted: no
    - Waiting for accessibility: yes
    - Last AX error: accessibilityPermissionMissing
14. Enable Toucher again in Accessibility settings.
15. Do not restart Toucher.
16. Return to Settings.
17. Confirm System Access updates to `Accessibility: Enabled` and the warning disappears.
18. Press Control + Shift + Right Arrow and perform a three-finger right swipe.
19. Confirm movement works without restart.
20. Open the menu and confirm it shows `About Toucher`, `Settings`, and `Quit Toucher`.
21. Open Gesture Diagnostics from Settings and confirm:
    - Accessibility trusted: yes
    - Last accessibility transition: untrustedToTrusted

Toucher temporarily polls Accessibility trust only while untrusted/waiting, then stops polling after trust returns.

## Coordinate smoke test

On macOS 15.1.1 or later:

1. Press Control + Shift + Left Arrow.
2. Press Control + Shift + Right Arrow.
3. Press Control + Shift + Up Arrow.
4. Press Control + Shift + Up Arrow twice quickly.
5. Press Control + Shift + Down Arrow.
6. Confirm every target stays fully inside the selected screen visible height.
7. Repeat on an external monitor if available.
8. If any target is wrong, open Settings > Gesture Diagnostics and copy the Screen Geometry Debug Info block.

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

1. Open Settings.
2. Click `Gesture Diagnostics…`.
3. Close Gesture Diagnostics.
4. Open Gesture Diagnostics again from Settings.
5. App must not crash.
6. Perform three-finger left, right, and up gestures.
7. Confirm these counters update:
   - total raw callbacks
   - total recognized gestures
   - left gestures
   - right gestures
   - up gestures
8. Confirm Last accepted gesture, Last accepted dx/dy, and Last accepted duration update.
9. Move with two or four fingers.
10. Confirm unsupported finger count increases but Last 10 raw events are not filled with continuous two-finger/four-finger noise.
11. Confirm movement diagnostics show:
   - last movement mode
   - movement kind
   - animation steps setting
   - requested duration
   - actual elapsed duration
   - steps planned/applied/skipped
   - fallback used
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
