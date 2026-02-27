---
title: "Force Base Terminal Nib to Hide Workspace Titlebar"
category: architecture
component: TerminalController, WorkspaceViewContainer
symptoms:
  - Native window title "~" visible in titlebar despite hiding attempts
  - Visible titlebar band persists after setting titlebarAppearsTransparent
  - KVO-based title hiding immediately overridden by window subclass
tags:
  - macos
  - nswindow
  - titlebar
  - nib
  - workspace-sidebar
date_solved: 2026-02-26
---

# Force Base Terminal Nib to Hide Workspace Titlebar

## Problem

In workspace mode, the native macOS window title ("~") and a visible titlebar band persisted despite multiple attempts to hide them. The workspace sidebar provides its own session title label inside the floating terminal card, so the native titlebar elements are redundant.

**Observable symptoms:**
- Window title "~" displayed in the titlebar area
- Opaque titlebar band visible between the sidebar and terminal content
- Setting `titleVisibility = .hidden` and `titlebarAppearsTransparent = true` had no effect
- KVO observer to hide the NSTextField was immediately overridden

## Investigation

### Approach 1: KVO + isHidden on NSTextField (Failed)

Added a KVO observer on `window.title` to find and hide the native `NSTextField` in the titlebar view hierarchy. macOS internally manages `isHidden` on titlebar text fields and resets the value, making this approach fragile and ineffective.

### Approach 2: alphaValue on NSTextField (Failed)

Switched from `isHidden = true` to `alphaValue = 0` with async dispatch for timing. Still targeted the wrong element — the visible title was rendered by a custom `TerminalToolbar`, not the native NSTextField.

### Approach 3: Remove toolbar (Partial)

Set `window.toolbar = nil` in `configureWorkspaceTitlebar()`. This removed the "~" text (custom `CenteredDynamicLabel` in `TerminalToolbar`) but the titlebar **band** remained because `TitlebarTabsVenturaTerminalWindow` paints `titlebarContainer.layer?.backgroundColor` via its `titlebarColor` property.

### Approach 4: Clear titlebar background (Failed)

Cleared `titlebarContainer.layer?.backgroundColor` after each `syncAppearance()` call. The window subclass repainted it immediately — `syncAppearance()` resets `titlebarColor` from the surface config on every change.

## Root Cause

The user's Ghostty config (`~/.config/ghostty/config`) included:

```
macos-titlebar-style = tabs
```

This caused `TerminalController.windowNibName` to return `"TerminalTabsTitlebarVentura"`, loading the `TitlebarTabsVenturaTerminalWindow` subclass. This subclass:

1. Creates a custom `TerminalToolbar` with `CenteredDynamicLabel` (line 589) that independently renders the window title
2. Overrides `title` didSet (line 303) to update `toolbar.titleText`
3. Overrides `titlebarColor` didSet (line 13) to paint `titlebarContainer.layer?.backgroundColor`
4. Runs `syncAppearance()` (line 142) on every surface config change, resetting titlebar colors

Standard NSWindow properties (`titleVisibility`, `titlebarAppearsTransparent`) are ineffective against these overrides because the subclass manages its own parallel title rendering and background painting systems.

## Solution

**Bypass the complex window subclass entirely** by forcing the base "Terminal" nib in workspace mode.

### TerminalController.swift — Force base nib

```swift
override var windowNibName: NSNib.Name? {
    // Workspace mode always uses the base Terminal nib. The sidebar
    // replaces native tabs and provides its own titlebar appearance,
    // so we bypass macosTitlebarStyle entirely to avoid fighting
    // complex titlebar subclasses (TitlebarTabsVenturaTerminalWindow, etc.).
    return "Terminal"
}
```

### TerminalController.swift — Simple titlebar configuration

```swift
private func configureWorkspaceTitlebar() {
    guard let window else { return }
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
}
```

Called once from `windowDidLoad()` after setting `WorkspaceViewContainer` as the content view.

### WorkspaceViewContainer.swift — Remove workarounds

Removed all previous title-hiding infrastructure:
- `cachedTitlebarTextField` weak reference
- `titleObservation` KVO observer
- `hideTitlebarTextField(in:)` method
- `observeWindowTitle(_:)` method
- Title-related cleanup in `deinit` and `viewDidMoveToWindow()`

The base `TerminalWindow` class respects standard NSWindow properties, so `titleVisibility = .hidden` and `titlebarAppearsTransparent = true` work correctly without workarounds.

## Prevention

1. **Match nib to mode**: When a feature replaces native window chrome (tabs, titlebar), force a nib that doesn't fight back. Complex window subclasses manage their own rendering pipelines.
2. **Check user config**: `macos-titlebar-style` in `~/.config/ghostty/config` determines which window subclass loads. Always test with the user's actual config.
3. **Prefer bypass over suppression**: Instead of suppressing side effects of a complex subclass (clearing backgrounds, hiding text fields, removing toolbars), avoid loading the subclass at all.

## Related

- [Sidebar 3-State Machine Pattern](sidebar-3-state-machine-overlay-pattern.md) — the overlay/pinned/closed state machine that this titlebar fix supports
- `TitlebarTabsVenturaTerminalWindow.swift` — the bypassed subclass with custom toolbar and titlebar painting
- `TerminalWindow.swift` — the base class that respects standard NSWindow properties
