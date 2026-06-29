# Toucher Manual Release Test

Use this checklist before publishing a release.

## Fresh Start

```bash
pkill -x Toucher || true
defaults delete com.amilabs.Toucher || true
make run-debug
```

The debug app installs to:

```text
~/Applications/Toucher.app
```

## Expected Defaults

- Animate window movement: enabled
- Animation steps: `32`
- Animation duration: `0.10s`
- Trackpad gestures: enabled

## Status Bar Menu

When Accessibility is enabled, the menu must show:

- About Toucher
- Settings
- Quit Toucher

When Accessibility is not enabled, the menu must show:

- About Toucher
- ⚠ Settings — Accessibility required
- Quit Toucher

The status bar itself should show only the Toucher icon.

## Settings Stability

1. Open Settings.
2. Confirm these sections are visible:
   - Gestures
   - Movement
   - System Access
   - Diagnostics
3. Toggle `Enable trackpad gestures`.
4. Toggle `Animate window movement`.
5. Change `Animation steps`.
6. Change `Animation duration`.
7. Confirm layout remains stable and text is not clipped.
8. Close and reopen Settings.
9. Confirm no duplicate Settings windows are created.

## Accessibility Recovery

1. Start Toucher with Accessibility enabled.
2. Open the status bar menu.
3. Confirm it shows `About Toucher`, `Settings`, and `Quit Toucher`.
4. Press Control + Shift + Left Arrow.
5. Confirm the active window moves.
6. Disable Toucher in System Settings > Privacy & Security > Accessibility.
7. Open the status bar menu.
8. Confirm it shows `About Toucher`, `⚠ Settings — Accessibility required`, and `Quit Toucher`.
9. Open Settings.
10. Confirm System Access shows `Accessibility: Not enabled`.
11. Confirm the inline warning is visible.
12. Try a hotkey or gesture.
13. Confirm the window does not move and Toucher remains responsive.
14. Enable Toucher again in Accessibility.
15. Do not restart Toucher.
16. Confirm Settings changes to `Accessibility: Enabled`.
17. Confirm the inline warning disappears.
18. Confirm hotkeys and gestures work again.
19. Confirm the status bar menu returns to `About Toucher`, `Settings`, and `Quit Toucher`.

## Hotkeys

Use a normal resizable app window, such as Finder or TextEdit.

1. Control + Shift + Left Arrow -> left half.
2. Control + Shift + Right Arrow -> right half.
3. Control + Shift + Up Arrow -> maximize.
4. Control + Shift + Up Arrow twice quickly -> full-height centered one-third width.
5. Control + Shift + Down Arrow -> restore previous frame.

## Trackpad Gestures

1. Swipe exactly three fingers left -> left half.
2. Swipe exactly three fingers right -> right half.
3. Swipe exactly three fingers up -> maximize.
4. Move with two fingers -> no window action.
5. Move with four fingers -> no window action.

For clean gesture testing:

- quit BetterTouchTool
- disable conflicting macOS Trackpad > More Gestures actions
- disable System Settings > Accessibility > Pointer Control > Trackpad Options > Three Finger Drag

## Multi-Monitor Behavior

1. Place a window on a secondary monitor.
2. Snap left and right.
3. Confirm the window stays on the current monitor.
4. Place a window partially across monitors.
5. Confirm Toucher chooses the monitor containing the window center, or largest intersection when the center is outside all screens.
6. Hold Command with a left/right hotkey.
7. Confirm Toucher targets the other or next screen.
8. Hold Command with a three-finger left/right gesture.
9. Confirm Toucher targets the other or next screen.

## Diagnostics

1. Open Settings.
2. Click `Gesture Diagnostics…`.
3. Confirm the window opens.
4. Close and reopen Gesture Diagnostics.
5. Confirm the app does not crash.
6. Perform three-finger left, right, and up gestures.
7. Confirm gesture counters update.
8. Confirm Accessibility state is shown correctly.
9. Confirm movement details are available for troubleshooting, including movement mode, target frame, readback frame if available, and movement error.

Diagnostics may increase CPU while open. Close Gesture Diagnostics for normal idle checks.

## CPU and Idle Behavior

Run:

```bash
make debug-cpu-note
```

Then check Toucher in Activity Monitor or with the printed `top` command.

Expected behavior:

- no continuous work in normal idle mode
- no movement timers while idle
- diagnostics updates only while Gesture Diagnostics is open

## Signing and Bundle Verification

Run:

```bash
make check
make debug-verify-bundle
```

Confirm:

- bundle id is `com.amilabs.Toucher`
- executable is `Toucher`
- version is current
- app path is `~/Applications/Toucher.app`
- signing identity is expected for the build
