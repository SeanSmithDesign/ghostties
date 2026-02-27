---
status: complete
priority: p3
issue_id: "016"
tags: [code-review, architecture, ux]
dependencies: []
---

# Add Transition Debounce to Prevent Overlay Oscillation

## Problem Statement

When the mouse exits the overlay tracking area, `mouseExited` fires `transitionTo(.closed)`, which starts a 0.2s animation and calls `updateTrackingAreas()`. The new closed-mode tracking area is a 10pt strip. If the user's mouse is still within those 10pt during the animation, `mouseEntered` can fire immediately, causing rapid closed→overlay→closed oscillation.

## Findings

- **Architecture Strategist**: Identified the race between animation completion and tracking area activation.

## Proposed Solutions

### Timestamp guard in transitionTo()

```swift
private var lastTransitionTime: CFTimeInterval = 0

private func transitionTo(_ newMode: SidebarMode) {
    guard newMode != sidebarMode else { return }
    let now = CACurrentMediaTime()
    guard now - lastTransitionTime > 0.25 else { return }
    lastTransitionTime = now
    // ... rest of method
}
```

- **Effort**: Trivial
- **Risk**: None — 0.25s debounce is imperceptible for intentional gestures
- **Pros**: Prevents visual flickering
- **Cons**: Adds a small delay to legitimate rapid toggles (unlikely use case)

## Acceptance Criteria

- [ ] Rapid mouse movement near sidebar edge does not cause oscillation
- [ ] Normal hover-to-reveal still works smoothly
- [ ] Build succeeds

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-02-27 | Created from code review | Architecture strategist flagged |
