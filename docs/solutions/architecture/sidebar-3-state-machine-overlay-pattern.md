---
date: 2026-02-26
tags: [appkit, state-machine, nsview, overlay, auto-layout, nstrackingarea, animation]
applies_to: [WorkspaceViewContainer.swift, WorkspaceLayout.swift, WorkspaceStore.swift]
---

# 3-State Sidebar: Pinned, Closed, and Hover Overlay

## Problem

The sidebar used a boolean `isSidebarVisible` toggle. This couldn't express a third state: sidebar floating *on top* of the terminal without pushing it right. The boolean also made it impossible to hide traffic lights only when closed, or auto-dismiss on window resign.

## Root Cause

A boolean conflates two independent axes: "is the sidebar showing?" and "does it affect terminal layout?" Overlay mode needs sidebar visible but terminal full-width — impossible with one bool.

## Solution

### 1. Tri-state enum replaces boolean

```swift
enum SidebarMode: Int, Codable {
    case pinned   // sidebar open, terminal pushed right
    case closed   // sidebar hidden, terminal full-width
    case overlay  // sidebar floats on top of terminal
}
```

### 2. Dual mutually-exclusive leading constraints

The terminal's leading edge needs to follow the sidebar in pinned mode but snap to the superview in closed/overlay. Two constraints, never both active:

```swift
private var shadowHostLeadingToSidebar: NSLayoutConstraint!
private var shadowHostLeadingToSuperview: NSLayoutConstraint!

// In transitionTo():
shadowHostLeadingToSidebar.isActive = false   // deactivate FIRST
shadowHostLeadingToSuperview.isActive = false
// then activate the right one
shadowHostLeadingToSidebar.isActive = (newMode == .pinned)
shadowHostLeadingToSuperview.isActive = (newMode != .pinned)
```

**Key gotcha:** Always deactivate both before activating one. Activating conflicting constraints simultaneously causes Auto Layout exceptions.

### 3. Z-ordering for overlay via layer.zPosition

In overlay mode, the sidebar must render above the terminal. Use `layer.zPosition` rather than `addSubview` reordering (which breaks constraint relationships):

```swift
case .overlay:
    sidebarHostingView.layer?.zPosition = 100
    sidebarOverlayBackground.layer?.zPosition = 99
case .pinned, .closed:
    sidebarHostingView.layer?.zPosition = 0
    sidebarOverlayBackground.layer?.zPosition = 0
```

Requires `wantsLayer = true` set once in `setup()`.

### 4. NSTrackingArea swap pattern

NSTrackingArea rects are immutable. Swap the entire area on state change:

- `.closed` → install trigger zone (10pt left edge strip). `mouseEntered` → `.overlay`
- `.overlay` → install sidebar zone (220pt from left). `mouseExited` → `.closed`
- `.pinned` → no tracking area needed

```swift
override func updateTrackingAreas() {
    if let area = activeTrackingArea { removeTrackingArea(area) }
    // Install new area based on current sidebarMode
}
```

### 5. Centralized transitionTo()

All state changes go through one method that handles constraints, z-ordering, animation, traffic lights, tracking areas, isHidden toggles, and persistence in a fixed order. This eliminates scattered state manipulation.

### 6. Overlay is transient — persisted as .closed

```swift
let persistedMode: SidebarMode = sidebarMode == .overlay ? .closed : sidebarMode
```

## Prevention

- When a boolean starts accumulating special cases, it's time for an enum.
- Always deactivate conflicting constraints before activating new ones.
- Use `layer.zPosition` for z-ordering, not view hierarchy reordering.
- NSTrackingArea rects are immutable — swap the object, don't try to resize.
