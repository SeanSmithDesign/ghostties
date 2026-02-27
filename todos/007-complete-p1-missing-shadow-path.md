---
status: complete
priority: p1
issue_id: "007"
tags: [code-review, performance, gpu, rendering]
dependencies: []
---

# Missing shadowPath Causes Continuous Offscreen Rendering

## Problem Statement

Both `terminalShadowHost` and `sidebarOverlayBackground` have `shadowOpacity > 0` without a `shadowPath` set. Without an explicit shadow path, Core Animation must rasterize the layer's content every frame to compute the shadow shape. For a terminal emulator where content updates on every keystroke/output line, this means a full-window offscreen render pass per frame on Retina displays.

On a 5K display at 2x, this is ~59 MB re-rendered every frame. This can cause frame drops during rapid terminal output.

## Findings

- **Performance Oracle**: Flagged as P0 critical — "single highest-impact fix in this review"
- **Pattern Recognition**: Not flagged (focused on code patterns, not GPU behavior)

## Proposed Solutions

### Option A: Set shadowPath in layout() override (Recommended)

```swift
override func layout() {
    super.layout()
    terminalShadowHost.layer?.shadowPath = CGPath(
        roundedRect: terminalShadowHost.bounds,
        cornerWidth: WorkspaceLayout.terminalCornerRadius,
        cornerHeight: WorkspaceLayout.terminalCornerRadius,
        transform: nil
    )
    sidebarOverlayBackground.layer?.shadowPath = CGPath(
        rect: sidebarOverlayBackground.bounds,
        transform: nil
    )
}
```

**Pros:** Eliminates offscreen rendering entirely, updates on every resize
**Cons:** None — this is the standard approach
**Effort:** Small
**Risk:** Low

## Technical Details

**Affected files:**
- `macos/Sources/Features/Ghostties/WorkspaceViewContainer.swift`

**Shadow layers without paths:**
- Line 470-474: `terminalShadowHost` shadow (radius 8, offset 0,-2)
- Line 282-284: `sidebarOverlayBackground` shadow (radius 6, offset 2,0)

## Acceptance Criteria

- [ ] `shadowPath` set on `terminalShadowHost` layer
- [ ] `shadowPath` set on `sidebarOverlayBackground` layer
- [ ] Both paths update on layout changes (window resize)
- [ ] No visible change to shadow appearance
- [ ] Smooth 60fps terminal scrolling in pinned mode on Retina displays

## Work Log

| Date | Action | Result |
|------|--------|--------|
| 2026-02-26 | Identified by Performance Oracle agent | P0 finding |

## Resources

- Apple docs: [Improving Shadow Rendering](https://developer.apple.com/documentation/quartzcore/calayer/1410771-shadowpath)
