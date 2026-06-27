# WindowGestures manual test

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
5. Focus an app or panel that cannot expose a controllable window.
6. Press either hotkey and confirm the app remains open while the menu bar status reports that it could not move or find a window.
