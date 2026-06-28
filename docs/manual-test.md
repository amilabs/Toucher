# WindowGestures manual test

## v0.2 smoke test checklist

- Confirm the app builds with `make build`.
- Launch the stable debug copy with `make run-debug`.
- Confirm WindowGestures appears only in the menu bar, not as a normal Dock app.
- Confirm the menu has disabled status/debug rows, `Open Accessibility Settings`, and `Quit WindowGestures`.
- Confirm the debug rows show the correct menu state:
  - `Accessibility trusted: yes`
  - `App bundle id: com.amilabs.WindowGestures`
  - `App bundle path: ~/Applications/WindowGestures.app`
- Confirm Control + Shift + Left Arrow moves the focused window to the left half of the visible screen.
- Confirm Control + Shift + Right Arrow moves the focused window to the right half of the visible screen.
- Confirm Control + Shift + Up Arrow maximizes the focused window to the visible screen.
- Confirm pressing Control + Shift + Up Arrow twice quickly resizes the focused window to a centered vertical third.
- Confirm Control + Shift + Down Arrow restores the focused window to its previous frame after a snap.
- Confirm the menu bar and Dock areas are respected.
- Confirm the app does not crash if Accessibility permission is missing.
- Confirm the app does not crash when no resizable focused window is available.
- Confirm `make debug-verify-bundle` reports the running process as `~/Applications/WindowGestures.app/Contents/MacOS/WindowGestures` when the app is running.
- Confirm the app does not implement configurable shortcuts, launch at login, notarization, or update behavior.

## Enable Accessibility

1. Build, install, and launch the stable debug copy with `make run-debug`.
2. Open the WindowGestures menu bar item.
3. If the status says `Accessibility permission needed`, choose `Open Accessibility Settings`.
4. In System Settings, enable Accessibility access for `~/Applications/WindowGestures.app`.
5. Quit and relaunch WindowGestures after granting permission.
6. Confirm the menu bar status changes to `Ready`.
7. Confirm the menu shows `Accessibility trusted: yes`.
8. Confirm the running process path is `~/Applications/WindowGestures.app/Contents/MacOS/WindowGestures`.

Accessibility trust should survive rebuilds only when the debug app is signed with the stable local certificate `WindowGestures Local Dev`. See `docs/signing.md` if trust flips back to `no` after rebuilding.

## Test hotkeys

1. Open a normal resizable app window, such as Finder.
2. Press Control + Shift + Left Arrow.
3. Confirm the active window moves to the left half of the visible screen, staying below the menu bar and clear of the Dock.
4. Press Control + Shift + Right Arrow.
5. Confirm the active window moves to the right half of the visible screen, staying below the menu bar and clear of the Dock.
6. Press Control + Shift + Up Arrow once.
7. Confirm the active window maximizes to the full visible screen, staying below the menu bar and clear of the Dock.
8. Press Control + Shift + Up Arrow twice quickly.
9. Confirm the active window becomes full visible-screen height, one third visible-screen width, and horizontally centered.
10. Press Control + Shift + Down Arrow.
11. Confirm the active window restores to the frame it had before the snap.
12. Press Control + Shift + Up Arrow once, wait more than 400 ms, then press Control + Shift + Up Arrow again.
13. Confirm each delayed Up press behaves as a single press and maximizes instead of triggering the centered one-third layout.

## Graceful failure checks

1. Disable Accessibility access for WindowGestures.
2. Press either hotkey.
3. Confirm the app does not crash and the menu bar status says `Accessibility permission needed`.
4. Re-enable Accessibility access.
5. Focus the desktop, System Settings, a save dialog, or another app/panel that may not expose a normal resizable focused window.
6. Press either hotkey and confirm the app remains open while the menu bar status reports `No active window found`, `Focused window cannot be resized`, `Could not read active window`, or `Could not move active window`.
7. Launch a second copy while the first copy is running, or otherwise create a shortcut conflict if possible.
8. Confirm a hotkey registration failure does not crash the app and the status reports `Hotkeys unavailable`.

## Troubleshoot stale Accessibility entries

macOS Accessibility permission is tied to a specific app identity and path. During local development, grant permission to the stable debug copy:

`~/Applications/WindowGestures.app`

`/Applications/WindowGestures.app` is for a later release or system-wide install and may require admin rights. Local debug installs should use `~/Applications/WindowGestures.app`.

If hotkeys still report `Accessibility permission needed` after permission is enabled:

1. Confirm `security find-identity -v -p codesigning` includes `WindowGestures Local Dev`.
2. Quit WindowGestures.
3. Run `tccutil reset Accessibility com.amilabs.WindowGestures`.
4. Open System Settings > Privacy & Security > Accessibility.
5. Remove old WindowGestures entries for `local.windowgestures.WindowGestures`.
6. Remove old WindowGestures entries that point to previous build locations, especially `.build/debug/WindowGestures.app`, `/Users/Shared/SharedWork/Apps/WindowGestures.app`, or `/Applications/WindowGestures.app`.
7. Re-add `~/Applications/WindowGestures.app`.
8. Launch again with `make run-debug`.
9. Confirm the menu shows `Accessibility trusted: yes` and the app bundle path is `~/Applications/WindowGestures.app`.
10. Confirm the running process path is `~/Applications/WindowGestures.app/Contents/MacOS/WindowGestures`.
11. Run `make debug-verify-bundle` and `make debug-signing-info` if System Settings still does not list the app.

## v0.3a gesture test

Before testing gestures:

1. Quit BetterTouchTool or disable its 3 Finger Swipe Left/Right triggers.
2. Disable conflicting macOS Trackpad > More Gestures actions.
3. Disable System Settings > Accessibility > Pointer Control > Trackpad Options > Three Finger Drag.

Test:

1. Run `make run-debug`.
2. Open the WindowGestures menu.
3. Confirm the menu shows:
   - `Accessibility trusted: yes`
   - `App bundle id: com.amilabs.WindowGestures`
   - `Gesture monitor: active`
4. Open TextEdit.
5. Make TextEdit active.
6. Swipe three fingers left.
7. Confirm the TextEdit window moves to the left half of the visible screen.
8. Swipe three fingers right.
9. Confirm the TextEdit window moves to the right half of the visible screen.
10. If nothing happens, open the WindowGestures menu and record:
    - `Last gesture event`
    - raw `dx` / `dy`
    - `Last gesture ignored reason`

Troubleshooting:

- If `Last gesture event` stays `none`, macOS, BetterTouchTool, or system gesture settings are consuming the gesture, or the public NSEvent swipe API is insufficient on this device/settings combination.
- If raw `dx` / `dy` appears but the action is ignored, adjust the threshold or horizontal dominance in `HorizontalSwipeRecognizer`.
- If the action is reversed, invert the public swipe direction mapping in `HorizontalSwipeRecognizer` initialization.
- If hotkeys work but gestures do not, window control is working and gesture input is the problem.

## v0.3b gesture diagnostics probe

Use this when the menu shows:

- `Gesture backend: public NSEvent swipe`
- `Gesture monitor: active`
- `Last gesture event: none`
- `Last gesture ignored reason: noEventReceived`

### Test A: normal menu bar mode

1. Quit BetterTouchTool.
2. Disable conflicting macOS Trackpad > More Gestures actions.
3. Disable System Settings > Accessibility > Pointer Control > Trackpad Options > Three Finger Drag.
4. Run `make run-debug`.
5. Open the WindowGestures menu and confirm:
   - `Gesture probe: inactive`
   - `Gesture monitor: active`
6. Perform three-finger swipe left and right.
7. Open the WindowGestures menu and record:
   - `Last public event type`
   - `Last public event timestamp`
   - `Last public event dx/dy`
   - `Last scroll deltaX/deltaY`
   - `Last scroll scrollingDeltaX/scrollingDeltaY`
   - `Accumulated scroll dx/dy`
   - `Last scroll precise`
   - `Last scroll direction inverted`
   - `Last public event phase`
   - `Last public event momentumPhase`
   - `Event counters`

### Test B: local probe window

1. Choose `Open Gesture Probe Window` from the WindowGestures menu.
2. Make the probe window frontmost.
3. Perform three-finger swipe left and right over the probe window.
4. Record the same public event fields and counters shown in the probe window or menu.

### Interpretation

- If all counters stay zero, public `NSEvent` cannot see this gesture in this configuration.
- If the local probe window sees events but the global monitor does not, public global monitoring is insufficient for background gestures.
- If `scrollWheel` events arrive but `swipe` does not, three-finger swipe may be exposed differently or only as scroll-like movement. Use `scrollingDeltaX/scrollingDeltaY`, precision, direction inversion, and accumulated dx/dy to evaluate that path before mapping any scrollWheel action.
- If public events never arrive, the next step is `RawMultitouchBackend`.

## v0.4 raw multitouch test

Before testing:

1. Quit BetterTouchTool.
2. Disable conflicting macOS Trackpad > More Gestures actions.
3. Disable System Settings > Accessibility > Pointer Control > Trackpad Options > Three Finger Drag.

Test:

1. Run `make run-debug`.
2. Open the WindowGestures menu.
3. Confirm the menu shows:
   - `Accessibility trusted: yes`
   - `Gesture backend: raw multitouch`
   - `Raw multitouch active: yes`
4. Open TextEdit.
5. Make TextEdit active.
6. Swipe exactly three fingers left.
7. Confirm the TextEdit window moves to the left half of the visible screen.
8. Swipe exactly three fingers right.
9. Confirm the TextEdit window moves to the right half of the visible screen.
10. Try two fingers left and right.
11. Confirm the window does not move.
12. Try four fingers left and right.
13. Confirm the window does not move.

If raw multitouch does not start:

1. Record:
   - `Raw multitouch available`
   - `Raw multitouch active`
   - `Raw devices found`
   - `Last raw error`
2. Force the public backend with `WINDOWGESTURES_GESTURE_BACKEND=public make run-debug`.
3. Disable gestures with `WINDOWGESTURES_GESTURE_BACKEND=off make run-debug`.
