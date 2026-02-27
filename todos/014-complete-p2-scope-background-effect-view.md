---
status: complete
priority: p2
issue_id: "014"
tags: [code-review, performance, compositing]
dependencies: []
---

# Scope backgroundEffectView to Sidebar Width

## Problem Statement

`backgroundEffectView` is constrained to all four edges of the superview (full window). In pinned mode, `NSVisualEffectView` with `.behindWindow` blending composites the entire window through WindowServer, even though only the sidebar strip is visible — the terminal container is opaque and drawn on top. This is a wasted full-window vibrancy pass.

## Findings

- **Architecture Strategist**: Identified the full-window constraint as unnecessary compositing overhead.
- **Performance Oracle**: Confirmed `isHidden = true` in closed mode correctly removes from compositing tree, but pinned mode still composites the full width.

## Proposed Solutions

### Constrain trailing edge to sidebar (Recommended)

In `WorkspaceViewContainer.setup()`, change:

```swift
// Before:
backgroundEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
// After:
backgroundEffectView.trailingAnchor.constraint(equalTo: sidebarHostingView.trailingAnchor),
```

- **Effort**: Trivial (one line)
- **Risk**: Low — verify visually that sidebar material still looks correct at the edge
- **Pros**: Eliminates unnecessary vibrancy compositing behind the terminal
- **Cons**: None expected

## Acceptance Criteria

- [ ] `backgroundEffectView` only covers the sidebar region
- [ ] Sidebar material appearance unchanged visually
- [ ] No compositing artifacts at the sidebar/terminal boundary
- [ ] Build succeeds

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-02-27 | Created from code review | Architecture + performance flagged |
