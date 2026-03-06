---
title: Fix Session Indicator Review Findings
type: fix
date: 2026-03-05
status: complete
---

# Fix Session Indicator Review Findings

## Overview

Post-review cleanup for the session indicator states feature. Originally 8 findings (2 P2, 6 P3). After technical review by 3 agents (architecture, performance, simplicity), **3 fixes were implemented and 5 were dropped** as unnecessary complexity.

## Findings

### P2-1: Activity timer fires `objectWillChange` every 1s even when no state transitions

**Problem:** The 1-second timer calls `objectWillChange.send()` whenever *any* session is alive, even if no session actually transitions between active/waiting. This causes SwiftUI to re-diff the entire sidebar every second.

**Fix:** Cache the previous `SessionIndicatorState` per session. Only fire `objectWillChange` when at least one session's computed state differs from its cached value.

**File:** `SessionCoordinator.swift` — `startActivityTimer()` (~line 486)

```swift
private var cachedIndicatorStates: [UUID: SessionIndicatorState] = [:]

private func startActivityTimer() {
    activityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self else { return }
        var changed = false
        for id in self.statuses.keys where self.statuses[id]?.isAlive == true {
            let current = self.indicatorState(for: id)
            if self.cachedIndicatorStates[id] != current {
                self.cachedIndicatorStates[id] = current
                changed = true
            }
        }
        if changed {
            self.objectWillChange.send()
        }
    }
}
```

Also clean up `cachedIndicatorStates` in `clearRuntime(id:)`.

---

### P2-2: Output tracking only subscribes to root surface (splits not tracked)

**Problem:** `subscribeToOutput` is called once when a session is created, subscribing only to the root surface's `lastOutputSubject`. If a user creates splits (Cmd+D), output from non-root panes doesn't update the session's `lastOutputTimestamps`.

**Fix:** When the activity timer fires, also check the live tree for the active session (via `terminalController.surfaceTree`) and subscribe to any new surfaces that appeared since the last check. Store subscriptions per-surface rather than per-session.

**File:** `SessionCoordinator.swift` — new method + refactored subscriptions

```swift
/// Per-surface subscriptions (replaces per-session outputSubscriptions).
private var surfaceSubscriptions: [ObjectIdentifier: AnyCancellable] = [:]

/// Subscribe to all surfaces in a tree that aren't already subscribed.
private func subscribeToAllSurfaces(in tree: SplitTree<Ghostty.SurfaceView>, sessionId: UUID) {
    for surface in tree {
        let key = ObjectIdentifier(surface)
        guard surfaceSubscriptions[key] == nil else { continue }
        surfaceSubscriptions[key] = surface.lastOutputSubject
            .sink { [weak self] in
                self?.lastOutputTimestamps[sessionId] = .now
            }
    }
}
```

Call `subscribeToAllSurfaces` from `createSession` (replacing `subscribeToOutput`) and periodically from the activity timer for the active session.

Clean up stale entries in `clearRuntime` and `handleSurfaceClose`.

---

### P3-1: `DispatchQueue.main.asyncAfter` for completed flash has no cancellation

**Problem:** In `SessionRow.updateAnimations(for:)`, the 1.5s delayed block captures `self` via `@State` but has no cancellation. If the session's state changes rapidly (completed → relaunched → active), the stale block fires and incorrectly resets `completedFlashActive`.

**Fix:** Use a `Task` with cancellation instead of `DispatchQueue.main.asyncAfter`.

**File:** `SessionDetailView.swift` — `updateAnimations(for:)` (~line 150)

```swift
@State private var flashTask: Task<Void, Never>?

private func updateAnimations(for state: SessionIndicatorState) {
    isBouncing = (state == .active)

    flashTask?.cancel()
    if state == .completed && !reduceMotion {
        completedFlashActive = true
        flashTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                completedFlashActive = false
            }
        }
    } else {
        completedFlashActive = false
    }
}
```

---

### P3-2: Timer closure lacks `@MainActor` annotation (Swift 6)

**Problem:** The `Timer.scheduledTimer` closure in `startActivityTimer` accesses `self` (a `@MainActor` class) without explicit isolation. In Swift 5 strict concurrency this triggers a warning; in Swift 6 it's an error.

**Fix:** Wrap the closure body in `MainActor.assumeIsolated` (the timer fires on the main run loop, so this is correct).

**File:** `SessionCoordinator.swift` — `startActivityTimer()` (~line 486)

```swift
activityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    MainActor.assumeIsolated {
        guard let self else { return }
        // ... existing body ...
    }
}
```

---

### P3-3: Terracotta color literal duplicated in 2 files

**Problem:** `Color(red: 0.788, green: 0.451, blue: 0.314)` appears in both `SessionDetailView.swift` and `ProjectDisclosureRow.swift`. Changing the terracotta shade requires updating both.

**Fix:** Add a shared constant in `WorkspaceLayout` (already used for other shared colors).

**File:** `WorkspaceSidebarView.swift` (where `WorkspaceLayout` is defined)

```swift
extension WorkspaceLayout {
    /// Terracotta/warm rust accent for "waiting" indicator state. #c97350
    static let waitingTerracotta = Color(red: 0.788, green: 0.451, blue: 0.314)
}
```

Then replace both call sites with `WorkspaceLayout.waitingTerracotta`.

---

### P3-4: `error(exitCode: Int16)` associated value stored but never displayed

**Problem:** `SessionStatus.error(exitCode:)` carries the exit code, but `SessionIndicatorState.error` is a plain case — the code is discarded at the view layer. No tooltip or VoiceOver label shows it.

**Fix:** Add the exit code to the accessibility label in `SessionRow.statusLabel`. The indicator state doesn't need the code (color is the same for all errors), but the coordinator can pass it through for a11y.

Approach: Add an optional `exitCode` parameter to `indicatorState(for:)` that returns it as an inout, or simply have `SessionRow` look it up via a new `exitCode(for:)` accessor on the coordinator.

**File:** `SessionCoordinator.swift` — new accessor

```swift
/// The exit code for a session in error state, if available.
func exitCode(for sessionId: UUID) -> Int16? {
    guard case .error(let code) = statuses[sessionId] else { return nil }
    return code
}
```

**File:** `SessionDetailView.swift` — updated `statusLabel`

```swift
case .error: return "error, exit code \(exitCode ?? 0)"
```

Wire `exitCode` through from the coordinator as a new optional prop on `SessionRow`.

---

### P3-5: Cross-window active/waiting distinction not accurate

**Problem:** `lastOutputTimestamps` is per-coordinator (per-window). If the same session is somehow referenced from another window's coordinator, timestamps won't be shared. In practice this is unlikely (sessions are window-scoped), but the `indicatorState(for:)` fallback to `WorkspaceStore.shared.globalStatuses` could return `.running` for a session owned by another coordinator that has no local timestamps.

**Fix:** When `indicatorState(for:)` resolves a status from `globalStatuses` (not local), skip the activity check and return `.waiting` for running sessions (since we can't know their output recency).

**File:** `SessionCoordinator.swift` — `indicatorState(for:)` (~line 501)

```swift
func indicatorState(for sessionId: UUID) -> SessionIndicatorState {
    let isLocal = statuses[sessionId] != nil
    let status = statuses[sessionId]
        ?? WorkspaceStore.shared.globalStatuses[sessionId]
        ?? .exited

    switch status {
    case .running:
        // Only distinguish active/waiting for locally-owned sessions.
        guard isLocal else { return .waiting }
        if let lastOutput = lastOutputTimestamps[sessionId],
           ContinuousClock.now - lastOutput < Self.activityThreshold {
            return .active
        }
        return .waiting
    // ... rest unchanged
    }
}
```

---

### P3-6: `pendingExitCodes` entries from other windows accumulate

**Problem:** `observeCommandFinished()` observes ALL `ghosttyCommandFinished` notifications (no object filter). Exit codes from surfaces in other windows are cached in `pendingExitCodes` and never cleaned up because `handleSurfaceClose` only processes surfaces in *this* coordinator's session trees.

**Fix:** In `commandDidFinish`, only cache the exit code if the surface belongs to a session in this coordinator.

**File:** `SessionCoordinator.swift` — `commandDidFinish(_:)` (~line 474)

```swift
@objc private func commandDidFinish(_ notification: Notification) {
    guard let surface = notification.object as? Ghostty.SurfaceView,
          let exitCode = notification.userInfo?["exit_code"] as? Int16,
          sessionId(for: surface) != nil else { return }
    pendingExitCodes[surface.id] = exitCode
}
```

---

## Acceptance Criteria

- [ ] Activity timer only fires `objectWillChange` when a session's indicator state actually changes
- [ ] Splits in non-root panes contribute to session activity detection
- [ ] Completed flash animation is cancelled when state changes before the 1.5s delay
- [ ] No Swift 6 strict-concurrency warnings on the timer closure
- [ ] Terracotta color defined in one place (`WorkspaceLayout`)
- [ ] Exit code visible in VoiceOver label for error-state sessions
- [ ] Cross-window sessions show `.waiting` (not spurious `.active`)
- [ ] `pendingExitCodes` only caches exit codes for surfaces owned by this coordinator
- [ ] Build succeeds: `zig build run -Doptimize=ReleaseFast`
- [ ] Existing tests pass: Cmd+U in Xcode

## Key Files

| File | Changes |
|------|---------|
| `SessionCoordinator.swift` | P2-1 cached states, P2-2 split subscriptions, P3-2 MainActor, P3-5 cross-window guard, P3-6 exit code filter |
| `SessionDetailView.swift` | P3-1 flash cancellation, P3-3 color constant, P3-4 exit code in a11y |
| `ProjectDisclosureRow.swift` | P3-3 color constant |
| `WorkspaceSidebarView.swift` | P3-3 shared `waitingTerracotta` constant |

## References

- Implementation PR: session indicator states feature
- Review agents: security-sentinel, performance-oracle, architecture-strategist, pattern-recognition-specialist, code-simplicity-reviewer
