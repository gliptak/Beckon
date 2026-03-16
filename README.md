# Beckon

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Beckon is a macOS menu bar app that implements focus-follows-mouse.
When your pointer hovers a window, Beckon gives that window keyboard focus without requiring a click.

## Current Status

The initial app scaffold is complete and includes:

- Menu bar app shell (`LSUIElement = YES`)
- Accessibility permission prompt on launch
- Persisted settings (enabled, delay, raise-on-focus)
- Hover tracking with debounce
- Window lookup under cursor via `CGWindowListCopyWindowInfo` + Accessibility API
- Focus + optional raise behavior

## Requirements

- macOS 13+
- Xcode 15+ (tested with newer versions)
- Accessibility permission granted to Beckon

## Build And Run

1. Open `Beckon.xcodeproj` in Xcode.
2. Select the `Beckon` scheme.
3. Build and run.
4. On first launch, grant Accessibility permission when prompted.

If macOS did not show the permission dialog, open:

- System Settings -> Privacy & Security -> Accessibility

Then enable Beckon manually.

## Usage

Use the menu bar icon to open settings:

- Enable Focus Follows Mouse
- Hover delay slider (0-500 ms)
- Raise window when focused
- Open Accessibility Settings shortcut
- Quit Beckon

## Project Structure

- `Beckon/BeckonApp.swift`: app entry point and menu bar wiring
- `Beckon/AppDelegate.swift`: startup lifecycle and permission prompt
- `Beckon/SettingsModel.swift`: persisted settings model
- `Beckon/MenuBarView.swift`: menu bar UI
- `Beckon/WindowFinder.swift`: window-under-cursor detection
- `Beckon/FocusFollowsMouseManager.swift`: global mouse monitor + focus logic
- `Beckon/Info.plist`: app metadata and `LSUIElement`

## Notes On Accessibility

Beckon relies on macOS Accessibility APIs (`AXUIElement`).
Without Accessibility access, it cannot move focus between windows.

## Next Work Items

- Verify focus behavior across many apps and window types
- Improve edge-case handling (fullscreen apps, Spaces, transient windows)
- Add optional diagnostics logging toggle in the menu
- Add simple automated tests for non-UI logic
