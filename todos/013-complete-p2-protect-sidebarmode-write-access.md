---
status: complete
priority: p2
issue_id: "013"
tags: [code-review, architecture, state-management]
dependencies: []
---

# Protect sidebarMode Write Access on WorkspaceStore

## Problem Statement

`WorkspaceStore.sidebarMode` is a public `var` with a `didSet` that triggers persistence. Any code could write `WorkspaceStore.shared.sidebarMode = .closed` and persist the change without updating the UI in `WorkspaceViewContainer`. The intended data flow is unidirectional: only `transitionTo()` in the view container should write to the store.

This is safe today (only `transitionTo()` writes) but fragile — a future contributor could easily bypass the view container and create a UI/persistence desync.

## Findings

- **Architecture Strategist**: Identified dual-write risk between `WorkspaceViewContainer.sidebarMode` (local) and `WorkspaceStore.shared.sidebarMode` (global). No reactive sync from store → container.
- **Pattern Recognition**: Noted `sidebarMode` is intentionally not `@Published` but this asymmetry is undocumented.

## Proposed Solutions

### Option A: `private(set)` + explicit method (Recommended)

In `WorkspaceStore.swift`:

```swift
private(set) var sidebarMode: SidebarMode = .pinned {
    didSet { if oldValue != sidebarMode { persist() } }
}

/// Called by WorkspaceViewContainer after state transitions.
func updateSidebarMode(_ mode: SidebarMode) {
    sidebarMode = mode
}
```

Update `WorkspaceViewContainer.transitionTo()` to call `WorkspaceStore.shared.updateSidebarMode(newMode)`.

- **Effort**: Small
- **Risk**: None
- **Pros**: Locks in unidirectional flow, compiler enforces it
- **Cons**: One extra method

### Option B: Add doc comment only

Add a comment on `sidebarMode` explaining the ownership contract. No compiler enforcement.

- **Effort**: Trivial
- **Risk**: None
- **Pros**: Zero code change
- **Cons**: Comment-only protection, easily violated

## Acceptance Criteria

- [ ] External code cannot directly set `WorkspaceStore.shared.sidebarMode`
- [ ] `transitionTo()` still persists mode changes
- [ ] Build succeeds

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-02-27 | Created from code review | Architecture strategist + pattern recognition flagged |
