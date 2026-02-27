---
title: "Safe Area Inset Blocks Terminal Card Top Constraint"
category: ui-bugs
component:
  - WorkspaceViewContainer
  - NSView
symptoms:
  - Top constraint constant changes have no visible effect
  - Terminal card does not reach window top edge despite correct constraint values
  - ~28pt gap between card top and expected position
tags:
  - auto-layout
  - safe-area
  - macos
  - nswindow
  - fullSizeContentView
  - titlebar
  - workspace-sidebar
date_solved: 2026-02-27
---

# Safe Area Inset Blocks Terminal Card Top Constraint

## Problem

The floating terminal card in the workspace sidebar would not reach the top of the window. Changing the top constraint constant (e.g., from 8pt to 2pt) had no visible effect — the card stayed in the same position regardless of the value.

**Observable symptoms:**
- Terminal card started ~28pt below the expected position
- Adjusting `terminalTopInset` from 8 to 2 produced zero visual change
- The gap matched the titlebar height exactly

## Root Cause

With `.fullSizeContentView`, macOS applies safe area insets derived from the titlebar height (~28pt) to `NSView.topAnchor`. Even though `titlebarAppearsTransparent = true` makes the titlebar invisible, the **safe area still reserves space** for it.

The constraint `terminalShadowHost.topAnchor.constraint(equalTo: topAnchor, constant: 8)` was effectively `topAnchor + 28 (safe area) + 8 (constant) = 36pt` from the window edge. Changing the constant to 2 made it `28 + 2 = 30pt` — a 6pt change that was barely perceptible against the dominant 28pt offset.

**Key insight:** Visual invisibility of the titlebar does not equal constraint system invisibility. The Auto Layout anchor system continues to respect safe area boundaries even when the titlebar is transparent.

## Solution

**File:** `WorkspaceViewContainer.swift`

```swift
/// Zero out safe area insets so Auto Layout constraints measure from
/// the actual window edge, not the titlebar-offset safe area.
/// Without this, `topAnchor` is shifted down by ~28pt (titlebar height)
/// and our `terminalTopInset` constant has no visible effect.
override var safeAreaInsets: NSEdgeInsets { NSEdgeInsetsZero }
```

This single override tells the view to ignore the titlebar safe area, letting the constraint constant directly control the distance from the window edge.

### Additional refinements in the same commit

- **Shadow opacity**: 0.15 → 0.2 (tested at 0.3, settled on 0.2 per design comparison with Paper)
- **Corner rounding**: Added `.continuous` cornerCurve and explicit `maskedCorners` for all four corners
- **Design verification**: Paper computed styles confirmed 8pt equal padding on all four sides

## Investigation Trail

| # | Approach | Result | Why |
|---|----------|--------|-----|
| 1 | Changed `terminalTopInset` from 8 to 2 | No visible change | Safe area (~28pt) dominated the 6pt difference |
| 2 | Explored agent investigated `topAnchor` behavior | Found safe area insets on the view | `NSView.topAnchor` includes safe area offset |
| 3 | Added `override var safeAreaInsets` returning zero | **Success** | Constraints now measure from actual window edge |
| 4 | Verified with Paper design tool | Confirmed 8pt on all sides | Reverted `terminalTopInset` back to shared 8pt constant |

## Prevention

1. **When using `.fullSizeContentView`**: Always check whether safe area insets are shifting your views. Override `safeAreaInsets` on container views that need to reach the window edge.
2. **Debug layout gaps**: If a constraint constant change has no visible effect, check the view's `safeAreaInsets` property — they may be adding a hidden offset.
3. **The Arc/Dia pattern is cumulative**: This fix joins the existing set of required properties (see related doc). The complete recipe now includes `safeAreaInsets` override on the container view.

## Testing Checklist

- [ ] Terminal card top edge aligns to the 8pt inset from the window edge (not 36pt)
- [ ] Changing `terminalInset` constant produces a proportional visual change
- [ ] All three sidebar states (pinned/closed/overlay) render correctly
- [ ] Fullscreen enter/exit doesn't restore the offset
- [ ] Window minimize and restore preserves correct positioning

## Related

- [Titlebar Accessory Inflation Fix](../architecture/titlebar-accessory-inflation-arc-style-fix.md) — removes accessories that inflate titlebar height
- [Nib Window Subclass Titlebar Hiding](../architecture/nib-window-subclass-titlebar-hiding.md) — forces base Terminal nib for transparent titlebar
- [Sidebar 3-State Machine](../architecture/sidebar-3-state-machine-overlay-pattern.md) — the state machine this card layout supports
- `.ignoresSafeArea(.container, edges: .top)` on the SwiftUI sidebar (in `WorkspaceSidebarView.swift`) handles the SwiftUI side; this fix handles the AppKit container side
