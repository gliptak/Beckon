# Beckon

[![Build](https://github.com/gliptak/Beckon/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/gliptak/Beckon/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Windows should come when called. Beckon is a macOS menu bar app that quietly grants keyboard focus to whichever window your pointer lingers over — no click required, no ceremony needed.

## Current Status

The initial app scaffold is complete and includes:

- Menu bar app shell (`LSUIElement = YES`)
- Accessibility permission prompt on launch
- Persisted settings (enabled, delay, velocity sensitivity, raise-on-focus, border highlight, border width)
- Hover tracking with debounce
- Window lookup under cursor via `CGWindowListCopyWindowInfo` + Accessibility API
- Focus + optional raise behavior
- **Focused window border highlight** — auto contrast color with configurable border width

## Requirements

- macOS 13+
- Xcode 15+ (tested with newer versions)
- Accessibility permission granted to Beckon

Build and run instructions (Xcode + Makefile) are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Usage

Use the menu bar icon to open settings:

- Enable Focus Follows Mouse
- **Launch at Login** toggle (uses `SMAppService`; appears in System Settings → General → Login Items)
- Hover delay slider (0-500 ms)
- Velocity sensitivity slider (0.00-0.20)
- Raise window when focused
- **Highlight focused window border** toggle
  - Border color mode: `Auto` (inverse of current light/dark appearance)
  - Border width slider (1-8 px, default 2 px)
- Request Accessibility Permission button
- Quit Beckon

## Contributing

Technical and implementation guidance (architecture notes, accessibility constraints,
roadmap, and transit-focus details) lives in [CONTRIBUTING.md](CONTRIBUTING.md).
