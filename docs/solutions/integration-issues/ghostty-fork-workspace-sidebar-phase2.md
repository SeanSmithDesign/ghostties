---
title: "Ghostties Phase 2: Icon Rail, Project Management, and Persistence"
date: 2026-02-20
category: integration-issues
tags:
  - macOS
  - SwiftUI
  - AppKit
  - workspace-sidebar
  - icon-rail
  - project-management
  - persistence
  - code-review
  - state-management
  - concurrency
  - hover-interaction
  - multi-window
component:
  - IconRailView
  - WorkspaceStore
  - WorkspaceSidebarView
  - WorkspacePersistence
  - WorkspaceViewContainer
  - ProjectRailItem
  - WorkspaceLayout
  - Project
severity: resolved
status: complete
project: Ghostties
phase: 2-icon-rail-project-management
platform: macOS (Zig 0.15.2 + Swift/AppKit + SwiftUI)
fork_source: ghostty-org/ghostty
fork_target: SeanSmithDesign/ghostties
problem_type: integration/architecture
---

# Ghostties Phase 2: Icon Rail, Project Management, and Persistence

## Problem Statement

Phase 2 of Ghostties adds a multi-project workspace sidebar to the Ghostty terminal emulator fork. The challenge: build a native macOS sidebar (SwiftUI icon rail with hover-expand, project CRUD, JSON persistence) that integrates cleanly into Ghostty's existing AppKit window system — while keeping the upstream diff minimal and the architecture ready for Phase 3 (session management).

## Investigation Steps

### What Was Built

1. **Project model** (`Project.swift`) — Codable value type with id, name, rootPath, isPinned
2. **WorkspaceStore** — `@MainActor ObservableObject` singleton managing the project list
3. **WorkspacePersistence** — JSON read/write to `~/Library/Application Support/Ghostties/workspace.json`
4. **IconRailView** — Far-left rail, 52pt collapsed / 220pt expanded on hover with spring animation
5. **ProjectRailItem** — Individual row: folder icon + project name, 44pt hit target
6. **WorkspaceSidebarView** — ZStack overlay: detail panel always present, icon rail overlays when expanded
7. **WorkspaceViewContainer** — Updated to inject `WorkspaceStore.shared` via `.environmentObject()`
8. **WorkspaceLayout** — Shared layout constants enum

### What Went Wrong (10 Findings from 5-Agent Review)

A parallel code review (architecture, patterns, security, performance, simplicity agents) identified 10 issues — 5 P2 (Important) and 5 P3 (Nice-to-Have). All were fixed before merge.

## Root Cause Analysis

### Finding 1: Timer Lifecycle Leak (P2)

**Problem:** `Timer.scheduledTimer` for hover debounce retains its target and requires explicit invalidation. If the view disappears mid-hover, the timer fires on a stale view.

**Root cause:** SwiftUI view lifetimes are unpredictable; `Timer` from Foundation doesn't participate in structured concurrency.

**Fix:** Replaced with `Task.sleep(for:)` + cancellation check, plus `onDisappear { hoverTask?.cancel() }`:

```swift
@State private var hoverTask: Task<Void, Never>?

.onHover { hovering in
    hoverTask?.cancel()
    hoverTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(hovering ? 100 : 150))
        guard !Task.isCancelled else { return }
        isExpanded = hovering
    }
}
.onDisappear { hoverTask?.cancel() }
```

### Finding 2: Global selectedProjectID Breaks Multi-Window (P2)

**Problem:** `selectedProjectID` was stored on `WorkspaceStore` (the singleton), meaning all windows shared one selection cursor.

**Root cause:** Not reasoning about multi-window from the start. The design spec explicitly says "shared store, independent focus."

**Fix:** Moved `selectedProjectID` to `@State` on `WorkspaceSidebarView`, passed to `IconRailView` via `@Binding`. The store now only manages the global project list.

### Finding 3: NSOpenPanel in Model Layer (P2)

**Problem:** `WorkspaceStore.addProjectViaFolderPicker()` presented `NSOpenPanel` directly from the ObservableObject — mixing AppKit UI with state management.

**Root cause:** Convenience during rapid iteration. The store was the easiest place to put it.

**Fix:** Moved `NSOpenPanel` to the view layer (`IconRailView.presentFolderPicker()` and `WorkspaceSidebarView.presentFolderPicker()`). Store exposes only `addProject(at: URL)`.

### Finding 4: Dead Recents System (P2)

**Problem:** `Project.lastOpenedAt`, `WorkspaceStore.trimRecents()`, `maxRecents`, and `select(id:)` existed but nothing in Phase 2 used them. All projects were pinned on add.

**Root cause:** Building for a future phase without a concrete spec. Classic YAGNI violation.

**Fix:** Removed all recents machinery. Can be recreated from git history when Phase 3 defines the recents UX.

### Finding 5: Missing @MainActor on WorkspaceStore (P2)

**Problem:** No actor isolation on an `ObservableObject` publishing to SwiftUI. Any background call to mutating methods would be a data race on `@Published` properties.

**Root cause:** Easy to forget; the compiler doesn't always warn without strict concurrency enabled.

**Fix:** Added `@MainActor` to the class declaration.

### Findings 6-10 (P3)

| # | Finding | Fix |
|---|---------|-----|
| 6 | Magic numbers (52, 220) scattered across files | Extracted to `WorkspaceLayout` enum |
| 7 | Dead `Project.initial` property (unused) | Removed |
| 8 | Default (0o755) permissions on persistence directory | Set explicit `0o700` |
| 9 | Hardcoded "Shell"/"Claude Code" placeholder implying Phase 3 | Replaced with `Text(project.rootPath)` |
| 10 | Non-private `init` on singleton | Made `private` |

## Working Solution

### Final Architecture (After Fixes)

**8 files** in `macos/Sources/Features/Ghostties/`:

| File | Role |
|------|------|
| `Models/Project.swift` | Codable value type |
| `WorkspaceStore.swift` | `@MainActor ObservableObject` singleton — project CRUD + persistence |
| `WorkspacePersistence.swift` | JSON read/write with atomic writes, 0o700 permissions |
| `IconRailView.swift` | Hover-expand rail (52pt → 220pt), folder picker, context menu |
| `ProjectRailItem.swift` | Individual project row with accessibility |
| `WorkspaceSidebarView.swift` | ZStack overlay, per-window `selectedProjectID`, detail panel |
| `WorkspaceViewContainer.swift` | NSView wrapper composing sidebar + terminal via Auto Layout |
| `WorkspaceLayout.swift` | Shared layout constants |

**State ownership:**
- `WorkspaceStore.shared` (app-scoped) — owns `[Project]`, injected via `.environmentObject()`
- `@State selectedProjectID` (window-scoped) — lives in `WorkspaceSidebarView`, passed via `@Binding`

**Layout pattern:** ZStack with `.leading` alignment. Detail panel offset past the 52pt collapsed rail. Icon rail overlays with opaque background when expanded. Terminal never re-layouts during hover animation because the sidebar container width is always 220pt.

**Upstream diff:** Still only 1 line changed in `TerminalController.swift` (swap `TerminalViewContainer` for `WorkspaceViewContainer`).

### Key macOS Compatibility Notes

- `@Observable` requires macOS 14+; Ghostty targets macOS 13 → use `ObservableObject` + `@EnvironmentObject`
- `.windowBackground` ShapeStyle requires macOS 14+ → use `Color(nsColor: .windowBackgroundColor)`
- `NSHostingView.sizingOptions = []` prevents the hosting view from fighting Auto Layout

### Key Commits

- `c6c626491` — feat(workspace): add icon rail, project management, and persistence (Phase 2)
- `4c746e302` — fix(workspace): address review findings from Phase 2 audit

## Prevention Strategies

### SwiftUI + AppKit Integration

- **Never use `Timer.scheduledTimer` in SwiftUI views.** Use structured `Task` with cancellation.
- **Cancel tasks in `onDisappear`.** Don't assume `onDisappear` pairs 1:1 with `onAppear` in multi-window.
- **NSOpenPanel and all modal UI must live in the view layer.** Stores expose pure data methods only.
- **Set `NSHostingView.sizingOptions = []` when Auto Layout owns the geometry.** Prevents intrinsic size conflicts.

### State Management in Multi-Window macOS Apps

- **Classify every `@Published` property as window-scoped or app-scoped at creation time.** Selection state, scroll positions, and search queries are always per-window.
- **Every `ObservableObject` that publishes to SwiftUI must be `@MainActor`.** No exceptions.
- **Singleton `init` must be `private`.** `static let shared`, not `static var`.

### YAGNI in Phased Development

- **Every property must have a reader in the current phase.** If nothing reads `lastOpenedAt`, don't store it.
- **Stub interfaces, not implementations.** A protocol for Phase 3 is fine; a full implementation is not.
- **Delete aggressively during review.** If removing a symbol still compiles, and nothing in the current phase calls it, delete it.
- **Placeholders must describe current behavior, not aspirational features.**

### Pre-Commit Checklist

```
[ ] Every Task/Timer has a cancellation path (onDisappear or deinit)
[ ] No UI code in store/model layers
[ ] No selection/UI state in shared singletons
[ ] All ObservableObjects annotated @MainActor
[ ] No magic numbers — extracted to named constants
[ ] Every new property/method has a call site in the current phase
[ ] File permissions are explicit (0o700 for app-private dirs)
[ ] Singleton inits are private
```

## Cross-References

### Internal Docs

- [Brainstorm](/docs/brainstorms/2026-02-19-ghostties-brainstorm.md) — Project concept and key decisions
- [Plan](/docs/plans/2026-02-19-feat-ghostties-workspace-sidebar-plan.md) — Phased implementation plan

### External References

- [Ghostty upstream](https://github.com/ghostty-org/ghostty) — Core terminal emulator
- [libghostty docs](https://libghostty.tip.ghostty.org/index.html) — API documentation
- [HACKING.md](/HACKING.md) — Build instructions, logging, linting
