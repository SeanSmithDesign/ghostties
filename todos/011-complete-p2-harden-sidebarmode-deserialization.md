---
status: complete
priority: p2
issue_id: "011"
tags: [code-review, security, persistence, data-loss]
dependencies: []
---

# Out-of-Range SidebarMode Raw Value Wipes All Workspace State

## Problem Statement

If `workspace.json` contains `"sidebarMode": 99` (invalid raw value), Swift's synthesized `Codable` throws a `DecodingError`. This is caught by `load()`'s `catch is DecodingError` handler which backs up the file and starts fresh — wiping all projects, sessions, and templates. Losing all user data because one enum value is invalid is disproportionate.

## Findings

- **Security Sentinel**: Flagged as LOW severity but with disproportionate data loss impact

## Proposed Solutions

### Option A: Decode as raw Int then safe-construct (Recommended)

```swift
if let rawMode = try container.decodeIfPresent(Int.self, forKey: .sidebarMode),
   let mode = SidebarMode(rawValue: rawMode) {
    self.sidebarMode = mode
} else if let visible = try container.decodeIfPresent(Bool.self, forKey: .sidebarVisible) {
    self.sidebarMode = visible ? .pinned : .closed
} else {
    self.sidebarMode = .pinned
}
```

**Pros:** Unknown values gracefully fall through to default; no state wipe
**Cons:** Slightly more verbose
**Effort:** Small
**Risk:** Low

## Technical Details

**Affected files:**
- `macos/Sources/Features/Ghostties/WorkspacePersistence.swift` (lines 70-76)

## Acceptance Criteria

- [ ] JSON with `"sidebarMode": 99` loads without wiping state (defaults to `.pinned`)
- [ ] Valid `sidebarMode` values still decode correctly
- [ ] Legacy `sidebarVisible` fallback still works

## Work Log

| Date | Action | Result |
|------|--------|--------|
| 2026-02-26 | Identified by Security Sentinel | Data safety finding |
