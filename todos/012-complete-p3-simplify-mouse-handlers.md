---
status: complete
priority: p3
issue_id: "012"
tags: [code-review, simplicity, code-quality]
dependencies: []
---

# Simplify Mouse Handlers and Remove Stringly-Typed Zone userInfo

## Problem Statement

`mouseEntered`/`mouseExited` use `userInfo["zone"]` string matching to identify which tracking area fired. Since only one tracking area is active at a time, the zone is already known from `sidebarMode`. The zone check is redundant and the string literals are fragile. Additionally, `.removeDuplicates()` is missing from the Combine pipeline, and overlay shadow config values are re-set every transition.

## Findings

- **Code Simplicity**: ~21 LOC reduction identified
- **Pattern Recognition**: Recommended `event.trackingArea === activeTrackingArea` or just checking `sidebarMode`
- **Performance Oracle**: Recommended `.removeDuplicates()` on Combine pipeline and caching titlebar text field

## Proposed Solutions

### Batch of minor simplifications:

1. **Mouse handlers** — drop userInfo, just check `sidebarMode`:
   ```swift
   override func mouseEntered(with event: NSEvent) {
       if sidebarMode == .closed { transitionTo(.overlay) }
   }
   override func mouseExited(with event: NSEvent) {
       if sidebarMode == .overlay { transitionTo(.closed) }
   }
   ```
   Drop `userInfo` from NSTrackingArea constructors. (~8 lines saved)

2. **Move overlay shadow radius/offset to setup()** (~2 lines saved)

3. **Simplify initial constraint activation** to 2 lines (~5 lines saved)

4. **Replace overlayBackgroundWidthConstraint** with trailing-to-sidebar constraint (~6 lines, 1 property saved)

5. **Add `.removeDuplicates()`** to Combine pipeline (1 line)

6. **Cache titlebar text field** reference (avoid recursive traversal on title changes)

**Total: ~21 LOC reduction, 1 fewer stored property**

## Technical Details

**Affected files:**
- `macos/Sources/Features/Ghostties/WorkspaceViewContainer.swift`

## Acceptance Criteria

- [ ] Mouse handlers use `sidebarMode` check only, no string matching
- [ ] Overlay shadow radius/offset set once in setup()
- [ ] No behavioral changes to any sidebar state

## Work Log

| Date | Action | Result |
|------|--------|--------|
| 2026-02-26 | Identified by Code Simplicity + Pattern Recognition + Performance Oracle | Cleanup items |
