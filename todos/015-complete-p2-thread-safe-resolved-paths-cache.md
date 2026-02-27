---
status: complete
priority: p2
issue_id: "015"
tags: [code-review, security, concurrency]
dependencies: []
---

# Thread-Safe resolvedPaths Cache in SessionCoordinator

## Problem Statement

`SessionCoordinator` has a `nonisolated(unsafe) private static var resolvedPaths: [String: String]` dictionary that is read/written from `resolveCommand()`, which runs in `Task.detached`. Two windows creating sessions simultaneously could race on this dictionary, causing undefined behavior (potential crash).

**Note**: This predates the current branch but is exercised by the new session creation flows.

## Findings

- **Security Sentinel**: Rated MEDIUM — technically a data race on concurrent Dictionary mutation. Practical risk is low (users rarely create two sessions at the exact same instant) but it's undefined behavior.

## Proposed Solutions

### Option A: NSLock wrapper (Recommended)

```swift
private static let resolvedPathsLock = NSLock()
private static var _resolvedPaths: [String: String] = [:]

nonisolated private static func cachedPath(for command: String) -> String? {
    resolvedPathsLock.lock()
    defer { resolvedPathsLock.unlock() }
    return _resolvedPaths[command]
}

nonisolated private static func cachePath(_ resolved: String, for command: String) {
    resolvedPathsLock.lock()
    defer { resolvedPathsLock.unlock() }
    _resolvedPaths[command] = resolved
}
```

- **Effort**: Small
- **Risk**: None
- **Pros**: Eliminates undefined behavior, minimal overhead
- **Cons**: Slightly more code

### Option B: Actor isolation

Move the cache into a dedicated actor. Cleaner but requires `await` at call sites.

- **Effort**: Medium
- **Risk**: Low
- **Pros**: Swift-native concurrency safety
- **Cons**: Requires async refactor of `resolveCommand`

## Acceptance Criteria

- [ ] No `nonisolated(unsafe)` on the paths dictionary
- [ ] Concurrent access is synchronized
- [ ] Build succeeds

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-02-27 | Created from code review | Security sentinel flagged pre-existing issue |
