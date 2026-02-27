---
status: complete
priority: p3
issue_id: "017"
tags: [code-review, security, persistence]
dependencies: []
---

# Double-Layer Overlay Guard in State.encode(to:)

## Problem Statement

The overlay→closed mapping for persistence exists in `WorkspaceStore.persist()` but not in `State.encode(to:)`. If someone constructs a `State` directly with `.overlay` and encodes it (bypassing WorkspaceStore), the transient `.overlay` mode would reach disk. On next launch, the app would start in overlay mode with no way to dismiss.

## Findings

- **Security Sentinel**: Recommended defense-in-depth — enforce the invariant at the encoding layer too.

## Proposed Solutions

In `WorkspacePersistence.State.encode(to:)`:

```swift
let persistedMode = sidebarMode == .overlay ? SidebarMode.closed : sidebarMode
try container.encode(persistedMode, forKey: .sidebarMode)
```

- **Effort**: Trivial (one line)
- **Risk**: None

## Acceptance Criteria

- [ ] `State` with `.overlay` encodes as `.closed`
- [ ] Add unit test verifying the encoding guard
- [ ] Build succeeds

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-02-27 | Created from code review | Security sentinel flagged |
