# Beckon

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Beckon is a macOS menu bar app that implements focus-follows-mouse.
When your pointer hovers a window, Beckon gives that window keyboard focus without requiring a click.

## Current Status

The initial app scaffold is complete and includes:

- Menu bar app shell (`LSUIElement = YES`)
- Accessibility permission prompt on launch
- Persisted settings (enabled, delay, velocity sensitivity, raise-on-focus)
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
- Velocity sensitivity slider (0.00-0.20)
- Raise window when focused
- Request Accessibility Permission button
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

### Menu Bar / Transit Focus Problem

When the user moves the pointer toward the menu bar or across the screen, the cursor
passes over intermediate windows. This causes unintended focus switches before the
user reaches their intended target (e.g. a menu, or a distant window).

**Implemented:**
- **Velocity-adaptive dwell**: the effective debounce delay scales up proportionally
  with pointer speed (pts/s). Fast transit requires a much longer dwell to trigger
  focus; slow deliberate hover uses the configured delay. Capped at 500 ms.
- **User-tunable velocity sensitivity**: slider exposed in the menu controls the
  speed-to-delay factor, so users can tune transit behavior for display size,
  pointer settings, and personal movement style.

**Possible future approaches:**
- **Upward-trajectory suppression**: track a rolling window of Y-deltas; if the
  pointer is moving predominantly upward with meaningful speed, suppress focus
  changes until movement stops or reverses. Directly models "heading to menu bar"
  intent without affecting horizontal window-to-window movement.
- **Top-edge proximity cone**: extend a dead zone downward from the menu bar edge
  proportional to pointer speed — the faster the approach, the deeper the cone.
- **Menu bar notification lock**: subscribe to `NSMenuDidBeginTrackingNotification`
  / `NSMenuDidEndTrackingNotification` and freeze focus changes while any menu is
  open. Exact — no false positives — but only activates after a menu opens, not
  during transit.
- **Screen-edge dead zone**: suppress focus when the cursor is within the top N px
  (menu bar height via `NSStatusBar.system.thickness`) or bottom N px (Dock area).
  Simple and zero-latency but does not prevent focus changes during cross-window
  travel en route to the edge.
- **Proportional dwell near edges**: as the cursor approaches the top edge, scale
  the required dwell time upward (e.g. normal 25 ms at center, 300 ms within 50 px
  of menu bar). No hard cutoffs but adds latency for legitimate near-edge focus.
- **Ignore system-owned windows**: explicitly skip windows owned by `SystemUIServer`,
  `Dock`, or `WindowServer` so the menu bar chrome itself never steals focus.
- **Increase base dwell threshold**: the simplest mitigation — raise the default
  from 25 ms to ~150 ms. A quick swipe to the menu bar spends <10 ms over any
  intermediate window, so it never completes the dwell. Zero new code; trades off
  latency on all legitimate focus changes.
