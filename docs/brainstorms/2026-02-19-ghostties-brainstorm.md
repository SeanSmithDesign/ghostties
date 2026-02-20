# Ghostties Brainstorm — 2026-02-19

> **Name: Ghostties** — Ghostty + multi-project workspace management

## What We're Building

A **fork of Ghostty** (the GPU-accelerated native macOS terminal emulator) that adds a multi-project, multi-session workspace manager via a native sidebar. The goal is to manage multiple repos and terminal sessions (AI agents, dev servers, shells, etc.) from a single integrated window.

**This is NOT an external orchestrator** — it's a single-app experience with the sidebar and terminal in one window.

## Why This Approach

- **Minimal fork strategy** (Approach A): Only modify 2 upstream Ghostty files (`TerminalController.swift`, `AppDelegate.swift`), add a new feature directory
- **Proven pattern**: Ghostree (another Ghostty fork) validated this exact integration approach — SwiftUI `NavigationSplitView` inside Ghostty's existing AppKit window system
- **Small merge surface**: Ghostty releases every 6 months. With only 2 files changed, upstream merges should be trivial
- **MIT licensed**: No licensing concerns with forking

## Key Decisions

### Layout: Two-column sidebar + terminal
```
┌──┬─────────┬──────────────────┐
│  │ Project │                  │
│P1│ ─────── │                  │
│  │ Agent A │                  │
│P2│ Agent B │    Terminal       │
│  │ Server  │  (supports splits)│
│P3│ ─────── │                  │
│  │+ New    │                  │
└──┴─────────┴──────────────────┘
```

- **Far left**: Icon rail with project icons. **Expands on hover** to show project name + icon (Discord/Slack pattern)
- **Second column**: Detail panel showing sessions/agents for the selected project
- **Terminal area**: Ghostty's native terminal with full split support

### Session scope: Any terminal session
Not just AI agents — dev servers, file watchers, build processes, shells. Anything that runs in a terminal.

### Project discovery: Pinned favorites + recents
- Pin active projects to the top of the icon rail
- Recently opened repos appear below (ordered by last-used, capped at ~10)

### New session creation: Preset templates
- Configurable per project (e.g., "Claude Code agent", "Dev server", "Shell")
- "+" button in the detail panel opens template picker

### Status indicators: Running / Idle / Done
- Base semantics: three states (running, idle/waiting, done)
- Custom animation design TBD — something more expressive than a simple dot
- Ghostree's `StatusRing` as reference, but we want something distinctive

### Session switching: Single view, project scopes the sidebar
- The terminal area is one continuous space — not tied to a specific project
- Switching projects in the icon rail changes which sessions the detail panel shows
- Click a session → focuses it in the terminal area
- Splits can contain sessions from **different projects** (mix and match)
- The icon rail is a navigator/filter, not a tab switcher

## Architecture (from research)

### Files to modify (upstream Ghostty):
1. `macos/Sources/Features/Terminal/TerminalController.swift` — swap `TerminalViewContainer` for new `WorkspaceViewContainer` in `windowDidLoad()`
2. `macos/Sources/App/macOS/AppDelegate.swift` — inject workspace store

### Files to create (new feature directory):
```
macos/Sources/Features/Ghostties/
  WorkspaceView.swift              ← NavigationSplitView wrapper (icon rail + detail + terminal)
  WorkspaceViewContainer.swift     ← NSHostingView wrapper replacing TerminalViewContainer
  WorkspaceStore.swift             ← ObservableObject: projects, sessions, templates
  WorkspaceToolbar.swift           ← NSToolbar with sidebar toggle
  IconRailView.swift               ← Custom SwiftUI view with hover-expand behavior
  SessionDetailView.swift          ← Session list for selected project
  SessionTemplates.swift           ← Per-project launch templates
  StatusIndicator/
    StatusIndicatorView.swift      ← Animated status ring/indicator
```

### Note on NavigationSplitView vs custom layout
Ghostree used `NavigationSplitView` (two columns: sidebar + detail). Our design has **three** columns (icon rail + detail + terminal). `NavigationSplitView` supports a three-column mode, but the icon rail's hover-expand behavior is custom — it will be a nested SwiftUI view inside the sidebar column, not a separate `NavigationSplitView` column.

### Key Ghostty architecture to leverage:
- `Ghostty.App` (C bridge) — singleton that manages terminal instances
- `SplitTree<SurfaceView>` — existing split system, untouched
- `TerminalView` / `SurfaceView` — terminal rendering, untouched
- Window style XIBs — untouched

## Open Questions

- [ ] Project name (something ghost + agent themed)
- [ ] How to persist project/session state (UserDefaults vs JSON file vs Core Data)
- [ ] Session type auto-detection (defer — nice-to-have, not needed for v1)
- [ ] Keyboard shortcuts for sidebar navigation (⌘1-9 for projects? ⌘↑/↓ for sessions?)
- [ ] Should the icon rail show session counts or status summary per project?
- [ ] What happens when Ghostty gets native window naming in 1.3 — leverage it?

## Build Phases (estimated)

1. **Foundation**: Clone Ghostty, build from source, add sidebar scaffolding (~1-2 sessions)
2. **Project management**: Icon rail, project store, pinning/recents (~2 sessions)
3. **Session management**: Detail panel, templates, launch/track sessions (~2-3 sessions)
4. **Status & polish**: Status indicators, animations, keyboard shortcuts (~2 sessions)
5. **1.2 → 1.3 migration test**: Merge Ghostty 1.3 into fork when released (~1 session)

## Prior Art

- **Ghostree**: Ghostty fork with worktree sidebar. Validated the integration pattern. Single-repo focused.
- **Roro**: Electron-based Claude Code wrapper with similar sidebar concept. Glitchy, not native.
- **Warp / Wave**: "AI-native" terminals, but not native macOS and not multi-agent focused.
- **Worktrunk**: CLI for parallel agent workflows via git worktrees.

## Next Steps

Run `/workflows:plan` to create detailed implementation plan from this brainstorm.
