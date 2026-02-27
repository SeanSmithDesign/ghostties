---
status: complete
priority: p1
issue_id: "009"
tags: [code-review, testing, compilation]
dependencies: []
---

# WorkspacePersistenceTests References Removed sidebarVisible API

## Problem Statement

`WorkspacePersistenceTests.swift` still references `state.sidebarVisible` and the old `State(sidebarVisible:)` initializer. The `WorkspacePersistence.State` struct no longer has a `sidebarVisible` property — it now uses `sidebarMode: SidebarMode`. These tests will fail to compile.

## Findings

- **Architecture Strategist**: Flagged as HIGH priority — "most critical issue on this branch"

## Proposed Solutions

### Option A: Update all references (Recommended)

Update all occurrences of `sidebarVisible` to `sidebarMode` and add a test for the legacy `sidebarVisible` JSON migration path.

Lines to update:
- `state.sidebarVisible == true` → `state.sidebarMode == .pinned`
- `sidebarVisible: false` → `sidebarMode: .closed`
- `state.sidebarVisible == false` → `state.sidebarMode == .closed`
- `decoded.sidebarVisible == false` → `decoded.sidebarMode == .closed`
- `decoded.sidebarVisible == true` → `decoded.sidebarMode == .pinned`

New test to add: decode JSON containing `"sidebarVisible": false` (no `sidebarMode` key) and verify it produces `.closed`.

**Effort:** Small
**Risk:** Low

## Technical Details

**Affected files:**
- `macos/Tests/Workspace/WorkspacePersistenceTests.swift`

## Acceptance Criteria

- [ ] All test references updated from `sidebarVisible` to `sidebarMode`
- [ ] Tests compile and pass
- [ ] New test for legacy `sidebarVisible` → `sidebarMode` migration

## Work Log

| Date | Action | Result |
|------|--------|--------|
| 2026-02-26 | Identified by Architecture Strategist | Compilation blocker |
