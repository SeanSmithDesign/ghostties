---
date: 2026-02-26
tags: [swift, codable, persistence, data-loss, defensive-coding]
applies_to: [WorkspacePersistence.swift]
---

# Invalid Codable Enum Raw Value Wipes All Persisted State

## Problem

If `workspace.json` contains `"sidebarMode": 99` (an invalid raw value for the `SidebarMode` enum), Swift's synthesized `Codable` throws a `DecodingError`. The `load()` function catches `DecodingError` by backing up the file and returning an empty `State()` — wiping all projects, sessions, and templates. One bad enum value destroys everything.

## Root Cause

Swift's synthesized `init(from:)` for `RawRepresentable` enums calls `fatalError`-style decoding when the raw value doesn't match any case. This bubbles up as a `DecodingError.dataCorrupted`, which is indistinguishable from truly corrupted JSON. The catch-all handler treats it the same as a completely garbled file.

## Solution

Decode as the raw type (`Int`) first, then safe-construct the enum:

```swift
// Instead of:
// self.sidebarMode = try container.decode(SidebarMode.self, forKey: .sidebarMode)

// Do this:
if let rawMode = try container.decodeIfPresent(Int.self, forKey: .sidebarMode),
   let mode = SidebarMode(rawValue: rawMode) {
    self.sidebarMode = mode
} else if let visible = try container.decodeIfPresent(Bool.self, forKey: .sidebarVisible) {
    // Legacy migration
    self.sidebarMode = visible ? .pinned : .closed
} else {
    self.sidebarMode = .pinned  // safe default
}
```

This gracefully falls through to a default for unknown values instead of throwing.

### Test coverage added

```swift
@Test func decodingInvalidSidebarModeRawValueDefaultsToPinned() throws {
    let json = """
    { "projects": [], "sessions": [], "templates": [], "sidebarMode": 99 }
    """
    let decoded = try JSONDecoder().decode(State.self, from: Data(json.utf8))
    #expect(decoded.sidebarMode == .pinned)
    #expect(decoded.projects.isEmpty)  // NOT wiped
}
```

## Prevention

- **Never use synthesized Codable for enums in persistence files.** Always decode as the raw type and safe-construct with `init(rawValue:)`.
- **Write a custom `init(from:)`** for any `Codable` struct that holds user data. Use `decodeIfPresent` with defaults for every field.
- **Test with invalid raw values** as part of the persistence test suite.
- **Disproportionate-response rule:** If one field being invalid causes *all* data to be lost, the error handling is wrong. Degrade gracefully per-field.
