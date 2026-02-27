---
status: complete
priority: p2
issue_id: "010"
tags: [code-review, performance, gpu, compositing]
dependencies: []
---

# NSVisualEffectViews Compositing When Not Visible

## Problem Statement

Two `NSVisualEffectView` instances continue compositing when they are not needed:

1. `backgroundEffectView` (full-window) composites in all modes, including `.closed` where it is fully occluded by the terminal. This creates a Gaussian blur filter in WindowServer processing every pixel of the window backing.

2. `sidebarOverlayBackground` uses `alphaValue = 0` in non-overlay modes, but `isHidden` is never set. `alphaValue = 0` does NOT remove a layer from the compositing tree — Core Animation still traverses it.

## Findings

- **Performance Oracle**: Flagged `backgroundEffectView` as P1, `sidebarOverlayBackground` as P1

## Proposed Solutions

### Option A: Toggle isHidden in transitionTo() (Recommended)

```swift
// In transitionTo(), add to each case:
case .closed:
    backgroundEffectView.isHidden = true
    sidebarOverlayBackground.isHidden = true
case .pinned:
    backgroundEffectView.isHidden = false
    sidebarOverlayBackground.isHidden = true
case .overlay:
    backgroundEffectView.isHidden = false
    sidebarOverlayBackground.isHidden = false
```

**Pros:** Eliminates compositing overhead entirely when views not needed
**Cons:** None — `isHidden` is the correct mechanism
**Effort:** Small
**Risk:** Low

## Technical Details

**Affected files:**
- `macos/Sources/Features/Ghostties/WorkspaceViewContainer.swift`

## Acceptance Criteria

- [ ] `backgroundEffectView.isHidden = true` in `.closed` mode
- [ ] `sidebarOverlayBackground.isHidden = true` in `.pinned` and `.closed` modes
- [ ] Visual appearance unchanged in all three modes
- [ ] Reduced GPU compositing in Activity Monitor during closed mode

## Work Log

| Date | Action | Result |
|------|--------|--------|
| 2026-02-26 | Identified by Performance Oracle | P1 performance finding |
