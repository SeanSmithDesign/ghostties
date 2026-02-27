---
status: complete
priority: p1
issue_id: "008"
tags: [code-review, security, memory, lifecycle]
dependencies: []
---

# Missing deinit in WorkspaceViewContainer — Observer Leak

## Problem Statement

`WorkspaceViewContainer` registers a `NotificationCenter` observer in `viewDidMoveToWindow()` (selector-based) but has no `deinit` and never calls `removeObserver`. If `viewDidMoveToWindow()` is called multiple times (view moved between windows), observers accumulate. The KVO observation on `window.title` is also not explicitly invalidated when the view leaves its window.

On modern macOS (10.11+), selector-based observers use zeroing weak references so this won't crash, but it is still a resource leak and correctness issue.

## Findings

- **Security Sentinel**: Flagged as MEDIUM — "most actionable fix"
- **Architecture Strategist**: Flagged as MEDIUM — noted SessionCoordinator already has correct deinit pattern

## Proposed Solutions

### Option A: Add deinit + guard viewDidMoveToWindow (Recommended)

```swift
deinit {
    NotificationCenter.default.removeObserver(self)
    titleObservation?.invalidate()
}

override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    // Clean up previous window's observers.
    NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
    titleObservation?.invalidate()
    titleObservation = nil
    guard let window = window else { return }
    // ... re-register with new window ...
}
```

**Pros:** Follows existing pattern from `SessionCoordinator.deinit`, handles window-move edge case
**Cons:** None
**Effort:** Small
**Risk:** Low

## Technical Details

**Affected files:**
- `macos/Sources/Features/Ghostties/WorkspaceViewContainer.swift`
  - Line 142-148: NotificationCenter observer registration
  - Line 170: `titleObservation` KVO property
  - Line 182-186: `observeWindowTitle` KVO setup

**Reference pattern:**
- `SessionCoordinator.swift` line 412: `deinit { NotificationCenter.default.removeObserver(self) }`

## Acceptance Criteria

- [ ] `deinit` added with `removeObserver` and `titleObservation?.invalidate()`
- [ ] `viewDidMoveToWindow` cleans up previous window's observer before re-registering
- [ ] No duplicate observers accumulate if view moves between windows

## Work Log

| Date | Action | Result |
|------|--------|--------|
| 2026-02-26 | Identified by Security Sentinel + Architecture Strategist | Consensus finding |
