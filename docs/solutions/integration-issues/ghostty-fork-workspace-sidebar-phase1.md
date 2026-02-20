---
title: "Ghostties Phase 1: Forking Ghostty and Adding a Workspace Sidebar"
date: 2026-02-20
category: integration-issues
tags:
  - forking
  - macOS
  - native-app-extension
  - Zig
  - SwiftUI
  - AppKit
  - workspace-sidebar
  - code-review
component:
  - build-system
  - branding
  - UI-composition
severity: resolved
status: complete
project: Ghostties
phase: 1-foundation
platform: macOS (Zig 0.15.2 + Swift/AppKit)
fork_source: ghostty-org/ghostty
fork_target: SeanSmithDesign/ghostties
---

# Ghostties Phase 1: Forking Ghostty and Adding a Workspace Sidebar

## Problem Statement

We needed to fork Ghostty (a GPU-accelerated native macOS terminal emulator built with Zig + Swift/AppKit) and add a multi-project workspace sidebar. The challenge: modify as little upstream code as possible to keep future merges manageable, while integrating a SwiftUI sidebar into Ghostty's existing AppKit window system.

## Solution

### 1. Minimal Fork Strategy

**Only 1 upstream Swift file modified** (`TerminalController.swift`, 1 line changed). All new code lives in a separate feature directory:

```
macos/Sources/Features/Ghostties/
  WorkspaceViewContainer.swift   ← NSView wrapper (sidebar + terminal)
  WorkspaceSidebarView.swift     ← SwiftUI placeholder sidebar
```

Xcode's `fileSystemSynchronizedGroups` auto-discovers new Swift files — no manual `pbxproj` edits for file registration needed. Identifier changes (`com.mitchellh.ghostty` → `com.seansmithdesign.ghostties`) are mechanical renames across ~15 files.

**View hierarchy before/after:**

```
Before:                              After:
NSWindow.contentView                 NSWindow.contentView
  └── TerminalViewContainer            └── WorkspaceViewContainer
       └── NSHostingView                    ├── NSHostingView<Sidebar>
                                            └── TerminalViewContainer
                                                 └── NSHostingView<Terminal>
```

### 2. WorkspaceViewContainer Composition Pattern

The wrapper composes the existing `TerminalViewContainer` alongside a sidebar `NSHostingView` using Auto Layout:

```swift
class WorkspaceViewContainer<ViewModel: TerminalViewModel>: NSView {
    private let sidebarHostingView: NSView
    private let terminalContainer: TerminalViewContainer<ViewModel>

    init(ghostty: Ghostty.App, viewModel: ViewModel, delegate: (any TerminalViewDelegate)? = nil) {
        self.terminalContainer = TerminalViewContainer(
            ghostty: ghostty, viewModel: viewModel, delegate: delegate
        )
        let hostingView = NSHostingView(rootView: WorkspaceSidebarView())
        hostingView.sizingOptions = []  // Auto Layout owns geometry
        self.sidebarHostingView = hostingView
        super.init(frame: .zero)
        setup()
    }

    override var intrinsicContentSize: NSSize {
        let termSize = terminalContainer.intrinsicContentSize
        guard termSize.width != NSView.noIntrinsicMetric else { return termSize }
        return NSSize(width: termSize.width + 220, height: termSize.height)
    }
}
```

**Key decisions:**
- Generic `<ViewModel: TerminalViewModel>` is structurally required (not over-engineered) because `TerminalViewContainer` demands it.
- `intrinsicContentSize` must include sidebar width — the terminal's intrinsic size alone would make the window 220pt too narrow.
- `sizingOptions = []` disables `NSHostingView`'s intrinsic size reporting since Auto Layout fully controls the sidebar geometry.

### 3. Building Ghostty from Source

```bash
# 1. Check exact Zig version from build.zig.zon (currently 0.15.2)
grep minimum_zig_version build.zig.zon

# 2. Download Zig (note: arch BEFORE os in URL)
curl -L https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz | tar xJ

# 3. Xcode 26 requires separate Metal Toolchain
xcodebuild -downloadComponent MetalToolchain

# 4. Build and launch
zig build -Doptimize=Debug
open zig-out/Ghostties.app
```

### 4. App Bundle Naming (Three Separate Xcode Concepts)

| Concept | Setting | Controls | Our Value |
|---------|---------|----------|-----------|
| **Target name** | Xcode project | `-target` flag for xcodebuild | `Ghostty` (unchanged) |
| **PRODUCT_NAME** | Build Settings | .app filename, Finder/Dock display | `Ghostties` |
| **EXECUTABLE_NAME** | Build Settings | Binary inside `Contents/MacOS/` | `ghostty` (unchanged) |

The Zig build system (`src/build/GhosttyXcodebuild.zig` line 52) must reference the correct `.app` filename to find xcodebuild's output.

### 5. Review Findings Fixed

| Finding | Severity | Fix |
|---------|----------|-----|
| `intrinsicContentSize` omitted sidebar width | P2 | Added `+ 220` to width calculation |
| Redundant `.frame()` on SwiftUI sidebar | P2 | Removed (Auto Layout is single authority) |
| Upstream Sparkle `SUPublicEDKey` retained | P2 | Removed from Info.plist |
| `sizingOptions = [.minSize]` unnecessary | P3 | Changed to `[]` |

## Prevention & Best Practices

### Build System
- [ ] **Always check `build.zig.zon`** for the exact Zig version before downloading
- [ ] **Verify Zig download URL format** — newer versions use `zig-{arch}-{os}` (arch before OS)
- [ ] **After Xcode upgrades**, run `xcodebuild -downloadComponent MetalToolchain`

### Fork Hygiene
- [ ] **Grep for old `.app` name** in build scripts when changing `PRODUCT_NAME`
- [ ] **Audit Info.plist** for inherited auto-update keys (Sparkle `SUPublicEDKey`)
- [ ] **Search for old bundle ID** in doc comments and Zig source files

### Layout Integration
- [ ] **Composite `intrinsicContentSize`** must include all children's widths
- [ ] **Single layout authority** per dimension — don't mix Auto Layout constraints with SwiftUI `.frame()`
- [ ] **Set `sizingOptions = []`** on `NSHostingView` when Auto Layout fully controls geometry

## Related Documentation

### Internal
- [Brainstorm: Ghostties concept](../brainstorms/2026-02-19-ghostties-brainstorm.md)
- [Plan: Workspace sidebar implementation](../plans/2026-02-19-feat-ghostties-workspace-sidebar-plan.md)

### External
- [Ghostty upstream](https://github.com/ghostty-org/ghostty)
- [Ghostties fork](https://github.com/SeanSmithDesign/ghostties)
- [libghostty API docs](https://libghostty.tip.ghostty.org/index.html)
- [HACKING.md](../../HACKING.md) — Ghostty build instructions and logging

## Key Commits

- `9516c43` — Add planning docs to fork
- `8757c72` — Rebrand identifiers from Ghostty to Ghostties
- `5c9c260` — Add placeholder sidebar alongside terminal
- `30d588f` — Rename app bundle to Ghostties and tint icon purple
- `1b49ad8` — Address review findings from Phase 1 audit
