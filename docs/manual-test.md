# WindowGestures manual test

## v0.1 smoke test checklist

- Confirm the app builds with `make build`.
- Launch `.build/debug/WindowGestures.app`.
- Confirm WindowGestures appears only in the menu bar, not as a normal Dock app.
- Confirm the menu has a disabled status row, `Open Accessibility Settings`, and `Quit WindowGestures`.
- Confirm Control + Shift + Left Arrow moves the focused window to the left half of the visible screen.
- Confirm Control + Shift + Right Arrow moves the focused window to the right half of the visible screen.
- Confirm the menu bar and Dock areas are respected.
- Confirm the app does not crash if Accessibility permission is missing.
- Confirm the app does not crash when no resizable focused window is available.
- Confirm the app does not implement gestures, configurable shortcuts, maximize, restore, center, launch at login, notarization, or update behavior.

## Enable Accessibility

1. Build and launch WindowGestures.
2. Open the WindowGestures menu bar item.
3. If the status says `Accessibility permission needed`, choose `Open Accessibility Settings`.
4. In System Settings, enable Accessibility access for WindowGestures.
5. Quit and relaunch WindowGestures if macOS asks for it.
6. Confirm the menu bar status changes to `Ready`.

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
