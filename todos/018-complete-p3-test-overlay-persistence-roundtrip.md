---
status: complete
priority: p3
issue_id: "018"
tags: [code-review, testing, persistence]
dependencies: ["017"]
---

# Add Test for Overlay-to-Closed Persistence Round-Trip

## Problem Statement

There is no test verifying that the overlay→closed persistence conversion works correctly. The logic exists in `WorkspaceStore.persist()` but lacks test coverage.

## Findings

- **Pattern Recognition**: Identified gap in persistence test coverage — all other migration paths are tested but overlay persistence is not.

## Proposed Solutions

Add to `WorkspacePersistenceTests.swift`:

```swift
@Test func encodingOverlayModePersistsAsClosed() throws {
    let state = WorkspacePersistence.State(sidebarMode: .overlay)
    let data = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(WorkspacePersistence.State.self, from: data)
    #expect(decoded.sidebarMode == .closed)
}
```

- **Effort**: Trivial
- **Risk**: None

## Acceptance Criteria

- [ ] Test encodes a State with `.overlay` and verifies it decodes as `.closed`
- [ ] Tests pass in Xcode (Cmd+U)

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-02-27 | Created from code review | Pattern recognition flagged test gap |
