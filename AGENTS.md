# AGENTS.md

This file describes how coding agents should work in this repository.

## Project Goal

Build and maintain Beckon, a macOS menu bar app for focus-follows-mouse behavior.

## Tech Stack

- Swift 6
- SwiftUI (MenuBarExtra)
- AppKit / ApplicationServices for global events + Accessibility APIs
- Xcode project (no external package manager yet)

## Working Rules

- Keep the app as a menu bar utility (`LSUIElement = YES`).
- Prefer explicit, readable Swift over clever shorthand.
- Add brief comments only where behavior is non-obvious.
- Avoid refactoring unrelated areas during focused tasks.
- Preserve existing user-facing behavior unless the task says otherwise.

## Architecture Conventions

- `SettingsModel` owns persisted user preferences.
- `MenuBarView` owns menu UI only.
- `FocusFollowsMouseManager` owns event monitoring/debounce/focus actions.
- `WindowFinder` owns window detection and AX window resolution.
- `AppDelegate` handles launch-time permission prompts.

Keep these boundaries clear when adding features.

## Build And Validate

Primary validation flow:

1. Open `Beckon.xcodeproj` in Xcode.
2. Build `Beckon`.
3. Run and verify:
   - menu appears
   - permission prompt path works
   - focus follows mouse when enabled
   - delay and raise toggles behave as expected

## Common Task Playbook

### Add a new setting

1. Add key/default in `SettingsModel`.
2. Expose control in `MenuBarView`.
3. Wire behavior into `FocusFollowsMouseManager` or related component.

### Touch focus behavior

1. Keep debouncing intact.
2. Avoid repeated focus thrashing on the same window.
3. Check behavior when Accessibility permission is absent.

### Debug window matching

- Start with `WindowFinder`:
  - verify CG window candidate
  - verify AX window frame matching
- If no exact AX match, maintain a safe fallback path.

## Known Constraints

- App behavior depends on Accessibility permission.
- Some apps/windows may not expose complete AX attributes.
- Fullscreen/Spaces transitions can produce stale or missing window metadata.

## Definition Of Done For Changes

- Compiles without new warnings/errors relevant to the change
- Feature works from menu bar UI through runtime behavior
- No regressions to enable/disable, delay, raise toggles
- Documentation is updated when behavior or settings change
