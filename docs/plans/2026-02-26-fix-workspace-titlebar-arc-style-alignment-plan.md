---
title: "fix: Workspace Titlebar Arc-Style Alignment"
type: fix
date: 2026-02-26
---

# fix: Workspace Titlebar Arc-Style Alignment

## Overview

Eliminate the visible titlebar band in workspace mode and align traffic lights with the sidebar toolbar buttons on the same horizontal line — matching the Arc/Dia Browser pattern where the titlebar is invisible and content extends flush to the window chrome.

## Problem Statement

The current implementation shows a visible titlebar band at the top of the window. Traffic lights sit in this band at the macOS default position, while the sidebar toolbar buttons (+, sidebar toggle) appear in a separate row below. The design (Paper artboard `Q3-0`) shows all of these on ONE horizontal line with no band.

**Current state:** Title text and background are gone (from the nib fix in `509fc927f`), but the titlebar area still occupies extra vertical space.

**Target state:** Zero visible titlebar — sidebar background extends flush to the window chrome, traffic lights and sidebar buttons share the same row.

## Root Causes

### 1. NSTitlebarAccessoryViewControllers inflate titlebar height

The base `TerminalWindow.awakeFromNib()` adds two accessories that inflate the titlebar from ~28pt to ~50-60pt:

```swift
// TerminalWindow.swift:131-149
resetZoomAccessory.layoutAttribute = .right
addTitlebarAccessoryViewController(resetZoomAccessory)   // +height

updateAccessory.layoutAttribute = .right
addTitlebarAccessoryViewController(updateAccessory)       // +height
```

In workspace mode, the sidebar replaces these — they should be removed.

### 2. Missing `titlebarSeparatorStyle = .none`

The default separator style draws a hairline between the titlebar and content. Not set anywhere in the workspace flow. Only set in `TitlebarTabsVenturaTerminalWindow` (which we bypass).

### 3. Potential safe area inset pushing SwiftUI content down

With `.fullSizeContentView`, the window's safe area includes the titlebar height. If the sidebar's `NSHostingView` passes this safe area to SwiftUI, the `VStack` in `WorkspaceSidebarView` may be pushed down by the titlebar inset, creating a gap even though the frame extends to the top.

Evidence: `TerminalView.swift:108` explicitly uses `.ignoresSafeArea(.container, edges: .top)` for hidden titlebar mode. The workspace sidebar does NOT have this modifier.

## Proposed Solution

Follow the Arc/Dia pattern: keep `.titled` + `.fullSizeContentView` for the window frame and traffic lights, but remove everything that inflates or decorates the titlebar.

### Phase 1: Remove Titlebar Inflation

**File:** `TerminalController.swift` — `configureWorkspaceTitlebar()`

```swift
private func configureWorkspaceTitlebar() {
    guard let window else { return }

    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none

    // Remove titlebar accessories — the workspace sidebar replaces them.
    // Without this, resetZoomAccessory and updateAccessory inflate the
    // titlebar height, creating a visible band.
    while !window.titlebarAccessoryViewControllers.isEmpty {
        window.removeTitlebarAccessoryViewController(at: 0)
    }
}
```

- [x] Add `window.titlebarSeparatorStyle = .none`
- [x] Remove all `NSTitlebarAccessoryViewControllers` in the loop

### Phase 2: Safe Area Inset Fix

**File:** `WorkspaceSidebarView.swift` — root body view

```swift
var body: some View {
    VStack(spacing: 0) {
        titlebarToolbar
        ScrollView { ... }
        Spacer(minLength: 0)
    }
    .background(.clear)
    .ignoresSafeArea(.container, edges: .top)
}
```

- [x] Add `.ignoresSafeArea(.container, edges: .top)` to the sidebar root view
- [ ] Verify the `titlebarToolbar` starts at y=0 of the hosting view frame (no padding from safe area)

### Phase 3: Verify Traffic Light Alignment

With the inflated titlebar removed (standard ~28pt), the `titlebarSpacerHeight = 38` should provide correct alignment:

- Traffic lights at macOS default: ~(7, 6) from window top
- Traffic light vertical center: ~14pt from top
- Sidebar toolbar buttons centered in 38pt: ~19pt from top

If these are close enough (within 2-3pt), no repositioning needed. If visibly misaligned:

- [ ] Adjust `WorkspaceLayout.titlebarSpacerHeight` to match the actual titlebar height
- [ ] OR reposition traffic lights with `setFrameOrigin` (requires `NSWindow.didResizeNotification` observation for the macOS revert-on-resize bug)

### Phase 4: Guard Against Reapplication

macOS can reset titlebar properties during `syncAppearance`, fullscreen transitions, and title updates. The base `TerminalWindow.syncAppearance()` (line 433) does NOT touch titlebar properties, so this should be safe. But verify:

- [ ] Confirm `titlebarAppearsTransparent` survives `syncAppearance` calls
- [ ] Confirm accessories don't get re-added by any codepath
- [ ] Test fullscreen enter/exit doesn't restore the band

## Technical Considerations

### What NOT to do (from institutional learnings)

| Approach | Why it fails |
|----------|-------------|
| KVO observer on `window.title` to hide NSTextField | macOS resets `isHidden` internally |
| `alphaValue = 0` on titlebar elements | Targets wrong elements, fragile |
| Hide `NSTitlebarContainerView` entirely | Also hides traffic lights |
| Clear `titlebarContainer.layer?.backgroundColor` | `syncAppearance()` repaints it |

### The Arc/Dia recipe (what DOES work)

```
.titled + .fullSizeContentView + titlebarAppearsTransparent + titleVisibility(.hidden)
+ titlebarSeparatorStyle(.none) + NO accessories + NO toolbar
= invisible titlebar with traffic lights at natural position
```

### Files to modify

| File | Changes |
|------|---------|
| `TerminalController.swift` | Add `titlebarSeparatorStyle = .none`, remove accessories in `configureWorkspaceTitlebar()` |
| `WorkspaceSidebarView.swift` | Add `.ignoresSafeArea(.container, edges: .top)` if needed |
| `WorkspaceLayout.swift` | Adjust `titlebarSpacerHeight` if alignment is off (may not be needed) |

### Files NOT modified

| File | Why safe |
|------|---------|
| `TerminalWindow.swift` | Accessories are added in `awakeFromNib()` — we remove them afterward in the controller |
| `WorkspaceViewContainer.swift` | Already has correct constraint setup; `.fullSizeContentView` already inserted |

## Acceptance Criteria

- [ ] No visible titlebar band in workspace mode (pinned, closed, and overlay states)
- [ ] Traffic lights and sidebar toolbar buttons (+ and sidebar toggle) appear on the same horizontal line
- [ ] Sidebar background extends flush to the window's top chrome edge
- [ ] Session title label ("Front-end Swift UI") still centered in terminal card titlebar region
- [ ] `Cmd+Shift+E` toggle still works correctly across all 3 states
- [ ] Hover-to-reveal overlay still works
- [ ] Fullscreen enter/exit doesn't break the titlebar
- [ ] Dark mode renders correctly
- [ ] App quit and relaunch restores state correctly

## Verification

```bash
rm -rf macos/build && zig build run -Doptimize=ReleaseFast
```

1. Launch → confirm no band, traffic lights aligned with sidebar buttons
2. Compare against Paper design (artboard `Q3-0`)
3. `Cmd+Shift+E` → sidebar closes → traffic lights hide → terminal flush
4. Hover left edge → overlay appears → traffic lights + sidebar aligned
5. Enter/exit fullscreen → titlebar still correct
6. Quit and relaunch → state preserved

## References

- **Design target:** Paper artboard `Q3-0` ("Ghostties — Title bar - terminal name inside termi...")
- **Prior fix:** `509fc927f` — forced base Terminal nib, removed title text
- **Solution doc:** `docs/solutions/architecture/nib-window-subclass-titlebar-hiding.md`
- **State machine:** `docs/solutions/architecture/sidebar-3-state-machine-overlay-pattern.md`
- **Arc/Dia research:** fullSizeContentView + titlebarAppearsTransparent + no accessories = invisible titlebar with natural traffic light position
- **NSWindowStyles showcase:** [lukakerr/NSWindowStyles](https://github.com/lukakerr/NSWindowStyles)
- **Traffic light repositioning:** [CocoaPods/CPModifiedDecorationsWindow](https://github.com/CocoaPods/CocoaPods-app/blob/master/app/CocoaPods/CPModifiedDecorationsWindow.swift)
- **macOS resize revert bug:** Traffic lights revert to default position on `NSWindow.didResizeNotification` — must reapply
