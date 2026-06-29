# Toucher

Toucher is a lightweight macOS menu bar utility for moving and resizing windows with hotkeys and trackpad gestures.

It is distributed outside the App Store and requires Accessibility permission to control windows.

## Requirements

- macOS 13 or later
- Accessibility permission for `Toucher.app`
- A trackpad for gesture controls

## Supported Controls

Hotkeys:

- Control + Shift + Left Arrow: move the active window to the left half of the current visible screen.
- Control + Shift + Right Arrow: move the active window to the right half of the current visible screen.
- Control + Shift + Up Arrow: maximize the active window on the current visible screen.
- Control + Shift + Up Arrow twice quickly: resize to full height and centered one-third width.
- Control + Shift + Down Arrow: restore the previous frame.

Trackpad gestures:

- Three-finger swipe left: move the active window to the left half.
- Three-finger swipe right: move the active window to the right half.
- Three-finger swipe up: maximize the active window.

Multi-monitor behavior:

- By default, Toucher keeps the active window on its current screen.
- Hold Command with a left/right hotkey or gesture to target the other or next screen.

## Installation

Download and unzip the release archive, then move `Toucher.app` to your Applications folder or another stable location.

On first launch, macOS may ask for confirmation because Toucher is distributed outside the App Store.

## Accessibility Permission

Toucher needs Accessibility access to move and resize windows.

To enable it:

1. Open System Settings.
2. Go to Privacy & Security > Accessibility.
3. Add or enable `Toucher.app`.
4. Return to Toucher. The Settings window should update automatically.

If Accessibility is missing, Toucher does not move windows and shows a warning in the status bar menu.


## Troubleshooting

If hotkeys or gestures are recognized but windows do not move:

1. Confirm Toucher is enabled in System Settings > Privacy & Security > Accessibility.
2. Open Toucher Settings and check the System Access status.
3. Quit conflicting gesture tools while testing, such as BetterTouchTool.
4. If permission was changed recently, wait a few seconds for Toucher to update.
5. If macOS still shows inconsistent permission state, remove and re-add `Toucher.app` in Accessibility.

## Distribution Note

Toucher uses a private macOS multitouch API to recognize exact three-finger gestures. This API is isolated to the macOS adapter layer and is the reason Toucher is not App Store compatible.

Hotkeys and window movement use standard macOS APIs.
