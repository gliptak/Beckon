# Contributing to Beckon

Thanks for contributing to Beckon.

## Project Structure

- `Beckon/BeckonApp.swift`: app entry point and menu bar wiring
- `Beckon/AppDelegate.swift`: startup lifecycle and permission prompt
- `Beckon/SettingsModel.swift`: persisted settings model
- `Beckon/MenuBarView.swift`: menu bar UI
- `Beckon/WindowFinder.swift`: window-under-cursor detection
- `Beckon/FocusFollowsMouseManager.swift`: global mouse monitor + focus logic
- `Beckon/BorderHighlightWindow.swift`: transparent floating panel that draws the border overlay
- `Beckon/Info.plist`: app metadata and `LSUIElement`

## Notes On Accessibility

Beckon relies on macOS Accessibility APIs (`AXUIElement`).
Without Accessibility access, it cannot move focus between windows.

Border highlight color is currently auto-selected from appearance contrast;
only border width is user-configurable.

## Build And Run

Xcode flow:

1. Open `Beckon.xcodeproj` in Xcode.
2. Select the `Beckon` scheme.
3. Build and run.
4. On first launch, grant Accessibility permission when prompted.

If macOS did not show the permission dialog, open:

- System Settings -> Privacy & Security -> Accessibility

Then enable Beckon manually.

## Command Line (Makefile)

From repository root:

```bash
make help
make list
make test
make build
make run
```

Available targets:

- `make list`: list project targets/schemes
- `make build`: unsigned Release build to `.build/Build/Products/Release/Beckon.app`
- `make release`: alias for `make build`
- `make debug`: unsigned Debug build
- `make test`: run unit tests on macOS
- `make ci`: run local CI checks (test + release build)
- `make run`: build Release and launch the app
- `make clean`: remove local build output (`.build`)

## Next Work Items

- Verify focus behavior across many apps and window types
- Improve edge-case handling (fullscreen apps, Spaces, transient windows)
- Add auto border contrast "strength" slider (subtle to strong)
- Add optional diagnostics logging toggle in the menu
- Add simple automated tests for non-UI logic
- Add debounce and duplicate-focus suppression unit tests for `FocusFollowsMouseManager` via injected scheduler/window/focus seams
- Add `WindowFinder` filtering tests by extracting pure candidate-selection logic from CG/AX calls
- Add settings-to-manager sync tests by extracting a small coordinator from `BeckonApp.syncManagerFromSettings()`
- Add XCUI smoke tests for menu controls and persistence with a test-host window mode for `MenuBarView`

## Menu Bar / Transit Focus Problem

When the user moves the pointer toward the menu bar or across the screen, the cursor
passes over intermediate windows. This causes unintended focus switches before the
user reaches their intended target (e.g. a menu, or a distant window).

Implemented:
- Configurable base hover delay: users set a base dwell threshold from 0-500 ms
  (default 25 ms, step 5 ms) in the menu.
- Velocity-adaptive effective delay: for each mouse-move event, Beckon computes
  pointer speed and inflates the dwell delay using
  `effectiveDelayMs = min(500, hoverDelayMs + speedPtsPerSec * velocitySensitivity)`.
  Fast transit requires a much longer hover to trigger focus, while slow deliberate
  movement stays close to the configured base delay.
- User-tunable velocity sensitivity: slider exposed in the menu controls the
  speed-to-delay factor (0.00-0.20, default 0.08, step 0.01), so users can tune
  transit behavior for display size, pointer settings, and personal movement style.

Possible future approaches:
- Upward-trajectory suppression: track a rolling window of Y-deltas; if the
  pointer is moving predominantly upward with meaningful speed, suppress focus
  changes until movement stops or reverses. Directly models "heading to menu bar"
  intent without affecting horizontal window-to-window movement.
- Top-edge proximity cone: extend a dead zone downward from the menu bar edge
  proportional to pointer speed; the faster the approach, the deeper the cone.
- Menu bar notification lock: subscribe to `NSMenuDidBeginTrackingNotification`
  / `NSMenuDidEndTrackingNotification` and freeze focus changes while any menu is
  open. Exact but only activates after a menu opens, not during transit.
- Screen-edge dead zone: suppress focus when the cursor is within the top N px
  (menu bar height via `NSStatusBar.system.thickness`) or bottom N px (Dock area).
  Simple and zero-latency but does not prevent focus changes during cross-window
  travel en route to the edge.
- Proportional dwell near edges: as the cursor approaches the top edge, scale
  the required dwell time upward (e.g. normal 25 ms at center, 300 ms within 50 px
  of menu bar). No hard cutoffs but adds latency for legitimate near-edge focus.
- Ignore system-owned windows: explicitly skip windows owned by `SystemUIServer`,
  `Dock`, or `WindowServer` so the menu bar chrome itself never steals focus.
- Increase base dwell threshold: the simplest mitigation; raise the default
  from 25 ms to ~150 ms. A quick swipe to the menu bar spends <10 ms over any
  intermediate window, so it never completes the dwell. Zero new code; trades off
  latency on all legitimate focus changes.