# Ghost Personality & Polish Brainstorm

**Date:** 2026-02-26
**Status:** Capture — ready for deep brainstorm session

---

## Context

We now have 24 ghost characters (12 original + 12 new) as 12x12 pixel grids. The pixel art style is working well. This brainstorm captures several connected feature ideas that make the ghost characters a core part of the Ghostties identity.

## Feature Ideas

### 1. Empty State — Ghost in the Terminal

When no session is active, the terminal area is blank. Instead, show the project's assigned ghost character rendered large and centered.

- Render at ~120px using existing `GhostCharacterView` / `drawPath(in:)`
- Muted color, subtle "Start a session" prompt below
- Switching projects changes the ghost (each project has its own)
- Feels alive instead of void

### 2. Session Active Animation

When an agent/session is running, the ghost character animates to show state. Key states:

| State | Animation | Feel |
|---|---|---|
| **Running / thinking** | Float (3-4px vertical bob) + shimmer scan across pixels | Active, working |
| **Waiting for input** | Idle float, occasional eye blink (2-frame toggle every 3-5s) | Present, calm |
| **Exited / done** | Static, muted opacity | Resting |
| **Error** | Brief shake, then static | Something went wrong |

**Animation candidates to prototype:**
- **Float** — slow ease-in-out vertical bob. Apple sleep-light energy.
- **Shimmer scan** — highlight sweeps L-to-R across pixel grid. Leans into 16-bit aesthetic.
- **Eye blink** — eye pixels toggle off for 2 frames, randomized interval. Tiny, alive.
- **Pixel cascade** — bottom row pixels shift alternately. Pac-Man "walking in place."
- **Breathe** — opacity pulse 0.6 → 1.0 on slow loop.

**Open question:** Does the animation live in the empty state ghost only, or also on the small sidebar dots/icons?

### 3. Alternate App Icons

Let users pick from all 24 ghost characters as their macOS app icon.

- Pixel art reads well at every size (16px → 1024px dock)
- Render with `drawPath(in:)` onto a filled background
- Background color: terracotta default, or let users pick?
- Ship as alternate icons in the asset catalog
- Picker UI: grid of 24 ghosts in app preferences
- Each icon = ghost silhouette on colored background, matching the in-app style

### 4. Easter Eggs

**Konami code** — type ↑↑↓↓←→←→BA in the sidebar:
- All status dots briefly turn into animated mini ghosts
- Or: ghost parade animates across the titlebar
- Or: all 24 ghosts cascade down the sidebar like Pac-Man

**Idle surprise** — if a session is idle 10+ minutes:
- Status dot subtly pulses
- Or ghost "wanders" across the titlebar

**About window** — click app icon 5 times for a ghost animation

**Hidden CLI** — `ghostty` command prints your project's ghost in terminal using Unicode block characters (▀ ▄ █ ░). Like neofetch but just a ghost + session info.

### 5. Ghost in the Terminal (ASCII Art)

Render ghost characters as terminal-native ASCII/Unicode art using half-block characters:

```
  ██████
 ████████
██  ██  ██
██  ██  ██
████████████
████████████
██ ██  ██ ██
█   █  █   █
```

Could be used for:
- MOTD/greeting when a new session spawns
- The empty state (rendered in a pseudo-terminal style)
- The hidden CLI easter egg
- Splash screen on first launch

---

## Priority Thinking

1. **Empty state** — quick win, immediate UX improvement
2. **Session active animation** — brings the ghosts to life, needs prototyping
3. **App icons** — high personalization value, moderate effort
4. **Easter eggs** — pure delight, do last

## Next Steps

- [ ] Deep brainstorm session to pick animation direction
- [ ] Prototype float + shimmer in SwiftUI
- [ ] Design empty state layout in Paper
- [ ] Generate app icon assets for all 24 ghosts
- [ ] Decide on easter egg triggers
