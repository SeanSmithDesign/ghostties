---
title: "Sidebar Visual Polish — Ghost Characters, Pixel Chevrons, Design Parity"
category: ui-bugs
component: workspace-sidebar
date: 2026-02-27
tags: [design-parity, pixel-art, ghost-characters, accessibility, swiftui]
severity: medium
status: resolved
---

# Sidebar Visual Polish — Ghost Characters, Pixel Chevrons, Design Parity

## Problem

The workspace sidebar had solid functionality (3-state machine, sessions, projects, persistence) but the visual treatment didn't match the Paper design mockups (artboards `1O-0` dark, `XX-0` light). Key mismatches:

1. **Status dots** (8px circles) instead of ghost characters (16px pixel art) in session rows
2. **SF Symbol chevron** instead of pixel-art chevron matching ghost aesthetic
3. **No expanded project container** background
4. **No plus icon** in expanded project headers
5. **No empty state** when zero projects exist
6. **No hover states** on toolbar buttons, session rows, or new session button
7. **Missing a11y features**: no "Move Up/Down" in session context menu, animations not gated on reduced motion

Design quality score before: 73/100

## Root Cause

Visual implementation lagged behind Paper design iterations. The sidebar was built function-first with placeholder styling (SF Symbols, plain circles) that was never updated to match the final pixel-art aesthetic.

## Solution

### Phase 1: PixelChevronView (new file)

Created `PixelChevronView.swift` — a pixel-art chevron matching the ghost character aesthetic:
- 7×5 grid rendered via `Path` + `.fill(color)`, same pattern as `GhostCharacterView`
- 8×8 pixels inside a 16×16 frame
- Rotates -90° (points right) when collapsed, 0° (points down) when expanded
- Animation gated on `accessibilityDisplayShouldReduceMotion`
- Color parameter: green when project has running sessions, gray otherwise

### Phase 2: ProjectDisclosureRow updates

- Replaced SF Symbol chevron with `PixelChevronView`
- Added plus icon (24×24 hit target) in header when expanded, triggers new session flow
- Added hover feedback on project header (`@State isHeaderHovered`)
- Wrapped expanded content in themed container background (8px radius)
- Added "Move Up" / "Move Down" to session context menu
- Gated expand/collapse animation on reduced motion

### Phase 3: SessionRow rewrite

- Removed status dot Circle from left side
- Added `GhostCharacterView` on RIGHT side (12×12 in 16×16 frame)
- Ghost inherits from `project.ghostCharacter`; fallback: first letter of session name
- Row height: 28pt, HStack spacing: 4pt
- Active row: themed background + subtle shadow
- Hover feedback on all rows
- Status colors: green (running), gray (exited), red (killed)

### Phase 4: WorkspaceSidebarView updates

- Toolbar refactored to `ToolbarIconButton` private struct with hover states
- Empty state: centered ghost character + "Add a project to get started" + `EmptyStateAddButton` with hover

### Phase 5: WorkspaceLayout constants

Extracted shared color constants to avoid magic values:
- `expandedContainerDark` / `expandedContainerLight`
- `activeRowDark` / `activeRowLight`

## Design Quality Fixes Applied

After initial implementation (score 82/100), a design review caught 6 issues:
1. Expand/collapse animation not gated on reduced motion → added check
2. Plus icon hit target too small (16pt) → increased to 24×24 with `contentShape`
3. Hardcoded inactive text colors → replaced with `Color(.secondaryLabelColor)`
4. Hardcoded container backgrounds → extracted to `WorkspaceLayout` constants
5. 6pt spacing off grid → snapped to 4pt
6. Empty state button no hover → added `EmptyStateAddButton` with hover

Final score: 88/100

## Key Patterns

- **Pixel art rendering**: `GeometryReader` + `Path` with grid array, same pattern for ghosts and chevrons
- **Reduced motion gating**: `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeInOut(duration: 0.2)`
- **Adaptive colors**: Use `Color(.secondaryLabelColor)` (NSColor-backed) for automatic dark/light adaptation; use `WorkspaceLayout` constants for custom themed values
- **Hover states**: `@State private var isHovered = false` + `.onHover { isHovered = $0 }` + conditional background/foreground

## Files Changed

- **New:** `PixelChevronView.swift`
- **Modified:** `ProjectDisclosureRow.swift`, `SessionDetailView.swift`, `WorkspaceSidebarView.swift`, `WorkspaceLayout.swift`, `WorkspaceViewContainer.swift`

## Prevention

- Run `/design:review` after visual changes to catch parity gaps early
- Keep Paper designs and implementation in sync — update one, update the other
- Extract shared colors to `WorkspaceLayout` constants rather than hardcoding hex values

## Related Solutions

- [Safe Area Inset Blocks Terminal Card Top Constraint](safe-area-inset-blocks-terminal-card-top-constraint.md) — companion fix in same session
- [3-State Sidebar: Pinned, Closed, and Hover Overlay](../architecture/sidebar-3-state-machine-overlay-pattern.md) — sidebar state machine this builds on
- [Titlebar Accessory Inflation Fix](../architecture/titlebar-accessory-inflation-arc-style-fix.md) — Arc-style titlebar that frames the sidebar
- [Phase 1: Forking Ghostty and Adding a Workspace Sidebar](../integration-issues/ghostty-fork-workspace-sidebar-phase1.md) — original sidebar implementation
- [Phase 2: Icon Rail, Project Management, and Persistence](../integration-issues/ghostty-fork-workspace-sidebar-phase2.md) — project/session model this polishes
