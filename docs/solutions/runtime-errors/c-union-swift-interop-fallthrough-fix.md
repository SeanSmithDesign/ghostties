---
title: "C Union Fallthrough Bug in Swift Action Dispatch"
date: 2026-03-05
category: runtime-errors
severity: critical
problem_type: runtime-errors
component: Ghostty.App / C tagged union action dispatch
tags:
  - swift-c-interop
  - undefined-behavior
  - fallthrough
  - tagged-union
  - session-indicator-states
symptoms:
  - 4 unrelated action cases silently read wrong C union variant
  - Undefined behavior / garbage memory reads
  - No crash or compiler warning — only caught by code review
related_files:
  - macos/Sources/Ghostty/Ghostty.App.swift
  - macos/Sources/Ghostty/Surface View/SurfaceView_AppKit.swift
  - macos/Sources/Features/Ghostties/SessionCoordinator.swift
---

# C Union Fallthrough Bug in Swift Action Dispatch

## Problem

When adding `GHOSTTY_ACTION_COMMAND_FINISHED` to the action dispatch switch in `Ghostty.App.swift`, the new case was placed at the **end of a `fallthrough` chain** for unimplemented actions:

```swift
case GHOSTTY_ACTION_TOGGLE_TAB_OVERVIEW:
    fallthrough
case GHOSTTY_ACTION_TOGGLE_WINDOW_DECORATIONS:
    fallthrough
case GHOSTTY_ACTION_SIZE_LIMIT:
    fallthrough
case GHOSTTY_ACTION_QUIT_TIMER:
    fallthrough
case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
    fallthrough
case GHOSTTY_ACTION_COMMAND_FINISHED:  // BUG!
    commandFinished(app, target: target, v: action.action.command_finished)
```

All 5 preceding cases now fall through into `commandFinished()`, which reads `action.action.command_finished` — the **wrong union variant** for those actions. This is undefined behavior: reading garbage from a C tagged union with no compiler warning.

## Root Cause

Ghostty's action system uses a C tagged union (`ghostty_action_s`) where `action.tag` is the discriminator and `action.action` is the union body. Each tag corresponds to a specific union field. Reading the wrong field is UB — the memory layout of one variant doesn't match another.

Swift's `fallthrough` is explicit (unlike C), but the danger is identical when the cases share a handler that reads a union variant. The compiler cannot check that the union tag matches the field being accessed.

## Solution

Move `COMMAND_FINISHED` to its own standalone case **before** the fallthrough chain:

```swift
case GHOSTTY_ACTION_COMMAND_FINISHED:
    commandFinished(app, target: target, v: action.action.command_finished)

case GHOSTTY_ACTION_TOGGLE_TAB_OVERVIEW:
    fallthrough
case GHOSTTY_ACTION_TOGGLE_WINDOW_DECORATIONS:
    fallthrough
// ... rest of fallthrough chain → logs "known but unimplemented"
```

## Secondary Fixes (Same Session)

### Exit Code -1 Sentinel

The C header defines exit code `-1` as "no exit code reported" (shell integration present but command didn't report). The Swift code initially treated it as `.error(exitCode: -1)`.

**Fix:** Explicit sentinel handling before interpreting the value:

```swift
switch exitCode {
case .none:        return .exited   // No shell integration
case .some(-1):    return .exited   // Shell integration, no code reported
case .some(0):     return .completed
case .some(let c): return .error(exitCode: c)
}
```

### @Published on High-Traffic Object

`@Published var lastOutputDate: Date?` on `SurfaceView` fired `objectWillChange` on every `setTitle()` call. Since `SurfaceView` is the most-observed object in the app (terminal rendering views depend on it), this caused excessive SwiftUI re-evaluation.

**Fix:** Replace with `PassthroughSubject<Void, Never>` — only the session coordinator subscribes; terminal views are unaffected.

### Review Finding Triage

8 findings from code review were evaluated by 3 specialist agents (architecture, performance, simplicity). **5 were dropped:**

| Finding | Why dropped |
|---------|-------------|
| Cached indicator states | Trading one cheap operation for another plus maintenance |
| Per-surface split subscriptions | New subsystem for cosmetic-only corner case |
| Flash Task cancellation | The "bug" sets `false` to `false` — a no-op |
| Exit code in a11y label | YAGNI — no user benefits from "exit code 127" in VoiceOver |
| Cross-window guard | Architecture already prevents the scenario |

**3 were kept:** `MainActor.assumeIsolated` (Swift 6), terracotta color DRY, exit code ownership filter.

## Prevention

### Never fallthrough into a C union read

Any case that reads a union variant (`action.action.some_field`) must be a **standalone case**. Fallthrough chains should only lead to generic handlers (logging, no-ops) that don't access the union body.

**Rule:** If a `case` reads from a C union field, it must `return` or `break` — never `fallthrough` from or to it.

### Validate C sentinel values at the boundary

When consuming C API values in Swift, check for documented sentinels (-1, 0xFFFF, NULL) **before** assigning semantic meaning. Prefer `Optional` wrapping or a Swift enum to encode "not available" rather than passing the raw sentinel through.

### Avoid @Published on frequently-updated, widely-observed objects

If an `ObservableObject` is observed by many views (like a terminal surface), high-frequency property changes via `@Published` cause a cascade of `objectWillChange` → view re-evaluation. Use `PassthroughSubject` or delegate patterns for properties that change often but are consumed by few subscribers.

### Use simplicity review to filter code review findings

Not every finding is worth implementing. A simplicity pass asking "is the fix cheaper than the bug?" kills over-engineering before it ships. In this case, it eliminated 5 of 8 proposed changes (~80 LOC) with no loss of correctness.

## Related Documentation

- [Codable Enum Raw Value Wipes State](../logic-errors/codable-enum-raw-value-wipes-state.md) — similar defensive-at-boundary pattern for enum deserialization
- [Sidebar Code Review Remediation](../logic-errors/sidebar-code-review-remediation.md) — prior @Published bulk-sync fix with `setStatus(_:for:)` pattern
- [Two-Layer State Architecture](../architecture/two-layer-state-architecture-swiftui-appkit-session-management.md) — WorkspaceStore vs SessionCoordinator design
- [Session Indicator Plan](../../plans/2026-03-05-fix-session-indicator-review-findings-plan.md) — full plan with triage decisions
