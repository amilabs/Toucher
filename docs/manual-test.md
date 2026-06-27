# WindowGestures manual test

## v0.1 smoke test checklist

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
- Confirm the menu bar and Dock areas are respected.
- Confirm the app does not crash if Accessibility permission is missing.
- Confirm the app does not crash when no resizable focused window is available.
- Confirm `make debug-verify-bundle` reports the running process as `~/Applications/WindowGestures.app/Contents/MacOS/WindowGestures` when the app is running.
- Confirm the app does not implement gestures, configurable shortcuts, maximize, restore, center, launch at login, notarization, or update behavior.

## Enable Accessibility

1. Build, install, and launch the stable debug copy with `make run-debug`.
2. Open the WindowGestures menu bar item.
3. If the status says `Accessibility permission needed`, choose `Open Accessibility Settings`.
4. In System Settings, enable Accessibility access for `~/Applications/WindowGestures.app`.
5. Quit and relaunch WindowGestures after granting permission.
6. Confirm the menu bar status changes to `Ready`.
7. Confirm the menu shows `Accessibility trusted: yes`.
8. Confirm the running process path is `~/Applications/WindowGestures.app/Contents/MacOS/WindowGestures`.

## Test hotkeys

1. Open a normal resizable app window, such as Finder.
2. Press Control + Shift + Left Arrow.
3. Confirm the active window moves to the left half of the visible screen, staying below the menu bar and clear of the Dock.
4. Press Control + Shift + Right Arrow.
5. Confirm the active window moves to the right half of the visible screen, staying below the menu bar and clear of the Dock.

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

1. Quit WindowGestures.
2. Run `tccutil reset Accessibility com.amilabs.WindowGestures`.
3. Open System Settings > Privacy & Security > Accessibility.
4. Remove old WindowGestures entries for `local.windowgestures.WindowGestures`.
5. Remove old WindowGestures entries that point to previous build locations, especially `.build/debug/WindowGestures.app`, `/Users/Shared/SharedWork/Apps/WindowGestures.app`, or `/Applications/WindowGestures.app`.
6. Re-add `~/Applications/WindowGestures.app`.
7. Launch again with `make run-debug`.
8. Confirm the menu shows `Accessibility trusted: yes` and the app bundle path is `~/Applications/WindowGestures.app`.
9. Confirm the running process path is `~/Applications/WindowGestures.app/Contents/MacOS/WindowGestures`.
10. Run `make debug-verify-bundle` if System Settings still does not list the app.
