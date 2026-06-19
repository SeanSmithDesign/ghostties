# Sparkle Auto-Update — Architecture, Bugs Fixed, and Reuse Playbook

> **Status:** Working end-to-end as of beta.18 (2026-06-19). Full OTA path proven in
> production: detect → download → install → relaunch.
> **Audience:** Future-me wiring Sparkle into a new macOS app, or anyone touching the
> Ghostties update flow. Read sections 8 and 7 first if you just want the portable lessons.

---

## 1. Overview

Ghostties ships **self-hosted Sparkle auto-updates** with a **custom branded in-app
"pill" UI** instead of Sparkle's standard dialogs. Updates are delivered from
self-hosted appcast feeds on Vercel:

- Beta channel: `https://ghostties.org/appcast-beta.xml`
- Stable channel: `https://ghostties.org/appcast-stable.xml`

Ghostties is a fork of upstream Ghostty, and the update layer is inherited from
upstream's custom-driver design (the `SPUUserDriver` mirror-into-a-state-machine
pattern). The fork's workspace titlebar redesign broke that inherited UI, which is
what bugs #1 and #2 below are about. The appcast feeds, signing keys, and the
release pipeline that regenerates the XML are all Ghostties-specific.

---

## 2. Architecture

The update system has one job: take Sparkle's stream of user-driver callbacks and
turn them into a single observable state value that a SwiftUI pill renders. Every
moving part exists to serve that.

### The parts

| Part | File | Role |
|---|---|---|
| `UpdateController` | `macos/Sources/Features/Update/UpdateController.swift` | Owns the `SPUUpdater`, starts it, exposes `checkForUpdates()` and `installUpdate()`. |
| `UpdateDriver` | `macos/Sources/Features/Update/UpdateDriver.swift` | The custom `SPUUserDriver`. Mirrors **every** Sparkle callback into the view model's state, AND wraps a real `SPUStandardUserDriver` as a fallback. |
| `UpdateDelegate` | `macos/Sources/Features/Update/UpdateDelegate.swift` | `SPUUpdaterDelegate` extension on `UpdateDriver`. Picks the feed URL by channel and handles silent install-on-quit. |
| `UpdateViewModel` / `UpdateState` | `macos/Sources/Features/Update/UpdateViewModel.swift` | `ObservableObject` with one `@Published var state: UpdateState`. The state machine + all display strings/colors/icons. |
| `UpdatePill` | `macos/Sources/Features/Update/UpdatePill.swift` | The branded pill SwiftUI view; `@ObservedObject var model`. Hidden when `state == .idle`. |
| `UpdatePopoverView` / `UpdateBadge` | same dir | Popover detail + badge glyph. |
| `UpdateSimulator` | `macos/Sources/Features/Update/UpdateSimulator.swift` | DEBUG-only driver that pushes scripted states into the view model with NO Sparkle/network. 9 scenarios. |

### `SPUUpdater` ownership

`UpdateController.init()` builds the updater with the **custom user driver as both
the user driver and the delegate** (`UpdateController.swift:31-36`):

```swift
self.updater = SPUUpdater(
    hostBundle: hostBundle,
    applicationBundle: hostBundle,
    userDriver: userDriver,   // UpdateDriver
    delegate: userDriver      // UpdateDelegate extension on UpdateDriver
)
```

One `UpdateController` lives on `AppDelegate`. There is exactly **one** shared
`UpdateViewModel` (`UpdateController.viewModel` proxies `userDriver.viewModel`). All
pill instances `@ObservedObject` that same model — bindings were never a bug source
here.

### The state machine

`UpdateState` (`UpdateViewModel.swift:187`) is an `Equatable` enum:
`.idle`, `.permissionRequest`, `.checking`, `.updateAvailable`, `.notFound`,
`.error`, `.downloading`, `.extracting`, `.installing`. Each non-idle case carries a
payload struct holding the Sparkle reply/cancel closures. `cancel()`
(`UpdateViewModel.swift:218`) and `confirm()` (`:245`) dispatch the right closure for
the current case — this is how the UI answers Sparkle.

### Callback → state → pill flow

```
  Sparkle (SPUUpdater)
        │  user-driver callback (showUpdateFound, showDownloadInitiated, …)
        ▼
  UpdateDriver  (SPUUserDriver)
        │  viewModel.state = .updateAvailable(…)        // mirror into state
        │  if !hasUnobtrusiveTarget { standard.<same>() } // fallback to std UI
        ▼
  UpdateViewModel  @Published var state
        │  objectWillChange
        ▼
  UpdatePill  (@ObservedObject)   ── renders unless state == .idle
        │  user taps → state.confirm()/cancel() → fires Sparkle's reply closure
        └─────────────────────────────────────────► back to Sparkle
```

### The fallback wrapper (`hasUnobtrusiveTarget`)

`UpdateDriver` holds a real `SPUStandardUserDriver` (`UpdateDriver.swift:7,11`).
Every callback mirrors into the view model and **also** forwards to the standard
driver *only when* `hasUnobtrusiveTarget == false`
(`UpdateDriver.swift:209-214`):

```swift
var hasUnobtrusiveTarget: Bool {
    NSApp.windows.contains { window in
        (window is TerminalWindow || window is QuickTerminalWindow) && window.isVisible
    }
}
```

Translation: "if there's a visible terminal window, I'll show the pill and suppress
the standard dialog; otherwise fall back to the real Sparkle UI." This single
property is the seam where bug #1 detonated.

---

## 3. Bug #1 — the permission-request wedge

**Symptom:** "Check for Updates" did nothing. Zero `log stream` output, no Sparkle
helper process spawned. Confirmed on the genuine notarized published beta.16 DMG
(not just a local build), so it was a real code bug, not a signing problem.

**Root cause:** On launch Sparkle issues a permission request ("Enable automatic
update checks?"). `UpdateDriver.show(_ request:reply:)` routed that prompt into a
`.permissionRequest` pill state but **suppressed** the standard prompt whenever a
terminal window was visible (`hasUnobtrusiveTarget == true`). The pill never
surfaced and was never answered, so Sparkle stayed in
`_showingPermissionRequest == YES` / `_sessionInProgress == YES` **permanently**.
Every subsequent `checkForUpdates()` was swallowed by Sparkle's internal "already
showing" guard (`SPUUpdater.m:697`) — it returned before logging and spawned no
helper. That one wedge reconciles all three symptoms: no logs, no helper, nothing
on screen.

**Fix (chosen behavior: silent background checks, NO consent prompt):**

1. `Ghostties-Info.plist:111-112` — `SUEnableAutomaticChecks=true`. With automatic
   checks enabled, Sparkle skips the permission-request path entirely on fresh
   installs, so the wedge never forms.
2. `.github/workflows/ghostties-release.yml:198-202` — the release packaging step
   does `PlistBuddy -c "Set :SUEnableAutomaticChecks true"`. **Critical:** an earlier
   version *deleted* this key during packaging, which re-broke the wedge on every
   release. If you ever see the wedge come back, check this line first.
3. `UpdateViewModel.swift:218-226` — `cancel()` now handles the `.permissionRequest`
   case by firing `request.reply(SUUpdatePermissionResponse(automaticUpdateChecks:
   true, …))`. This is the escape hatch that **un-wedges already-stuck installs** on
   the first manual check (the plist flag prevents the wedge on fresh installs; this
   rescues older installs that already entered it).
4. `UpdateController.checkForUpdates()` (`UpdateController.swift:95-97`) — added an
   `os_log` diagnostic so the next person can see state + `canCheckForUpdates` in the
   log stream.

> **Diagnostic predicate that actually works:**
> `log stream --predicate 'subsystem == "org.sparkle-project.Sparkle"' --level debug`
> Earlier broad predicates produced unreliable/empty output and sent the
> investigation down the wrong path.

---

## 4. Bug #2 — the pill never rendered

Even with the wedge fixed, the branded pill still didn't appear. Two compounding
causes:

**Cause A — the titlebar accessory is stripped.** The base `TerminalWindow` adds the
update pill as a **titlebar accessory** in `awakeFromNib`, but only when
`supportsUpdateAccessory` is true (`TerminalWindow.swift:62-65, 167-174`). The
fork's workspace redesign then runs `TerminalController.configureWorkspaceTitlebar()`,
which **removes ALL titlebar accessories** to flatten the titlebar band
(`TerminalController.swift:1283-1285`):

```swift
while !window.titlebarAccessoryViewControllers.isEmpty {
    window.removeTitlebarAccessoryViewController(at: 0)
}
```

So the pill was *added, then deleted* at launch.

**Cause B — the overlay fallback was off.** `BaseTerminalController` has a
bottom-right SwiftUI **overlay** fallback path that subscribes to the view model and
shows the pill when state is non-idle — but it only wires up when
`needsOverlayFallback == true`, and that is gated on
`!terminalWin.supportsUpdateAccessory` (`BaseTerminalController.swift:1169-1182`).
On a standard `TerminalWindow`, `supportsUpdateAccessory` stays `true`
(`TerminalWindow.swift:62-65`), so `needsOverlayFallback == false` and the overlay
never subscribed. Net: pill stripped by Cause A, fallback disabled by Cause B → no
update UI anywhere.

**Fix:** `activateUpdateOverlayFallback()` in `BaseTerminalController`
(`BaseTerminalController.swift:1193-1201`), called from
`configureWorkspaceTitlebar()` **right after the strip**
(`TerminalController.swift:1292`). It unconditionally (re)subscribes the overlay to
`updateViewModel.$state`, so any non-idle state now surfaces the branded pill in the
bottom-right corner via the pure-SwiftUI overlay — deliberately **not** entangled
with the traffic-light NSToolbar hack that the titlebar accessory path depended on.

> **Note:** bindings were never the problem. There is a single shared
> `UpdateViewModel` and the pill correctly uses `@ObservedObject`. The bug was purely
> *where* the pill was mounted (stripped titlebar) and *whether* a fallback mount
> existed (it was gated off).

---

## 5. Design decision — keep the branded pill

Sean chose to keep the **branded pill (bottom-right overlay)** rather than fall back
to Sparkle's standard dialog. To make that call with evidence, both paths were built
into a DEBUG A/B menu and compared side by side, then the standard-dialog scaffolding
was removed once the pill won. The custom user driver stays; the standard driver
remains only as the no-visible-window fallback inside `UpdateDriver`.

---

## 6. Release & packaging mechanics (the parts that bite)

The release is **tag-triggered**: pushing a `v*` tag runs
`.github/workflows/ghostties-release.yml`.

### Xcode pin for the Zig build step (the one that silently regresses)

The `macos-26` runner's default Xcode moved (26.2 → 26.4+ → 26.5). The 26.4+ SDK
changed `libSystem.tbd` arch naming, which broke Zig 0.15.2's link of
`GhosttyKit.xcframework` with undefined symbols (`_abort`,
`__availability_version_check`, `_arc4random_buf`, …). Fix is the same pin upstream
uses (ziglang/zig#31658):

```yaml
# ghostties-release.yml:125
sudo xcode-select -s /Applications/Xcode_26.3.app
```

before any zig build step. **Any CI job that runs a Zig or CLI-toolchain build needs
this pin** — Xcode/local builds dodge it because they consume the prebuilt
xcframework.

### Build number = Sparkle's version key

```yaml
# ghostties-release.yml:82
echo "build=$(git rev-list --count HEAD)" >> $GITHUB_OUTPUT
```

That build number becomes `CFBundleVersion` (`:195`) **and** the appcast's
`<sparkle:version>` (`:431`). Sparkle compares releases by `sparkle:version`. **A new
release must be a new commit**, or Sparkle treats it as equal and offers no update.
This is why beta.18 was shipped as a one-commit changelog bump — to push the commit
count from 16568 to 16570 so beta.17 would see it as newer.

### CI fully regenerates the appcast — do NOT hand-edit it

The `appcast` job (`ghostties-release.yml:385-462`) signs the DMG with the EdDSA key
and rewrites `appcast-beta.xml` (and `appcast-stable.xml` on stable tags) from
scratch every tag: version, URL, `sparkle:edSignature`, `length`, and a **fixed
template description** that just links to the GitHub release (`:434-438`). It then
commits the regenerated XML into `web/` with `[skip ci]` (`:517-521`).

> **Stale step warning:** the release checklist's "edit the appcast description before
> tagging" instruction is **dead** — CI overwrites it. To get real release notes into
> the Sparkle dialog, edit the `item_xml` template in the workflow (read CHANGELOG.md),
> not the committed XML. Pre-writing the appcast in the prep commit also diverges the
> branch on push. **Let CI own the appcast.**

### Channel mapping

`UpdateDelegate.feedURLString(for:)` (`UpdateDelegate.swift:14-17`) maps the config
channel to a feed:

- `.tip` → `appcast-beta.xml`
- `.stable` → `appcast-stable.xml`

The channel comes from `autoUpdateChannel`
(`Ghostty.Config.swift:658-673`), overridable via:

```bash
defaults write com.seansmithdesign.ghostties ghostties.autoUpdateChannel tip
```

(The feed URL is set **in code**, not in Info.plist — there is no `SUFeedURL` key.)

### Tag protection

`v*` tags are protection-locked and cannot move once pushed. If a tagged build is
broken, **bump to the next number** — never try to re-push the same tag.

### Notarize + staple

The pipeline notarizes (`:300-326`) and **staples** both the DMG and the `.app`
(`ghostties-release.yml:328-330`) so Gatekeeper validates offline:

```yaml
xcrun stapler staple "Ghostties.dmg"
xcrun stapler staple "macos/build/Release/Ghostties.app"
```

> Historical note: beta.17's DMG was notarized but **not** stapled (Gatekeeper
> validated online — fine for beta). The `stapler staple` step was the deferred
> hardening item and is now in the pipeline. For any new app, staple from day one.

---

## 7. Testing & validation playbook

This section is the reusable gold — it captures every footgun that cost time.

- **The real Sparkle path does NOT run in DEBUG.** `startUpdater()` is gated
  `#if !DEBUG` (`AppDelegate.swift:271-273`) to dodge Sparkle key-validation errors,
  so "Check for Updates" is **inert in Debug builds**. To exercise the UI without
  network, use the **DEBUG "Debug ▸ Simulate Update" menu** (`AppDelegate.swift:745+`),
  which drives all 9 `UpdateSimulator` scenarios through the real pill.

- **A broken updater client cannot self-update.** beta.16 (with the wedge) could not
  pull beta.17 → that required a manual install. The first real OTA test needs a
  **FIXED client + a NEWER build**: install the fixed beta.N, then ship beta.N+1 and
  let the fixed client pull it. (Proven beta.17 → beta.18.)

- **Local-build version pitfall.** A placeholder version like `0.1.0` semver-compares
  as **newer** than `0.1.0-beta.X`. A dev/local build with the placeholder version
  will never see published betas as updates. (Also: the About panel is the tell — a
  real release shows e.g. `0.1.0-beta.18` / build `16570`; a local build shows
  `0.1.0` / `1`.)

- **Automatic checks are on but throttled.** `SUEnableAutomaticChecks=true` with no
  `SUScheduledCheckInterval` set means Sparkle's default ~24h interval. **Manual
  "Check for Updates" forces an immediate check** — that's the trigger to use when
  testing. Add `SUScheduledCheckInterval` if you want snappier automatic checks.

- **Proven end-to-end (2026-06-19):** on installed beta.17, manual Check for Updates
  → "Update Available: 0.1.0-beta.18" pill → Install and Relaunch → app updated.
  Full OTA path confirmed in production: **detect → download → install → relaunch.**

---

## 8. Portable lessons for a future macOS app using Sparkle

Read this before deciding to build anything custom.

1. **Default to `SPUStandardUserDriver`.** Unless you genuinely need custom UI, use
   Sparkle's standard driver. The custom user driver here is ~1,600 lines of code you
   maintain forever, and it's the source of both bugs above. Custom UI is a real cost,
   not a free coat of paint.

2. **If you DO build custom titlebar UI, always have a non-titlebar fallback path.**
   Titlebar-accessory lifecycle, `NSWindow` subclasses, and toolbar conflicts will
   bite you (bug #2 was a titlebar accessory getting stripped with no fallback wired).
   Mount a window-agnostic overlay fallback and activate it after any code that
   touches titlebar accessories.

3. **Pin Xcode for any Zig/CLI-toolchain build step in CI.** Runner default Xcode
   moves silently and breaks toolchain linking. Pin an explicit
   `Xcode_<version>.app` with `xcode-select -s`.

4. **Build number is Sparkle's version key and must monotonically increase.** Tie it
   to `git rev-list --count HEAD` so every release is a new commit. Equal version =
   no update offered.

5. **Notarize AND staple.** Notarize the DMG and `.app`, then `stapler staple` both so
   Gatekeeper validates offline. Don't ship "notarized but not stapled" past beta.

6. **Keep the EdDSA signing key in CI secrets and let CI own the appcast.** Generate
   the signature, regenerate the XML, and commit it from the workflow. Hand-editing
   the appcast diverges the branch and gets overwritten anyway.

---

## 9. Key files reference

| File | Responsibility |
|---|---|
| `macos/Sources/Features/Update/UpdateController.swift` | Owns `SPUUpdater`; `startUpdater()`, `checkForUpdates()`, `installUpdate()`. |
| `macos/Sources/Features/Update/UpdateDriver.swift` | Custom `SPUUserDriver`; mirrors callbacks into state + wraps standard driver fallback (`hasUnobtrusiveTarget`). |
| `macos/Sources/Features/Update/UpdateDelegate.swift` | `SPUUpdaterDelegate`; feed URL by channel, silent install-on-quit. |
| `macos/Sources/Features/Update/UpdateViewModel.swift` | `UpdateViewModel` + `UpdateState` machine; display strings/colors; `cancel()`/`confirm()`. |
| `macos/Sources/Features/Update/UpdatePill.swift` | Branded pill SwiftUI view (`@ObservedObject` shared model). |
| `macos/Sources/Features/Update/UpdatePopoverView.swift` / `UpdateBadge.swift` | Pill popover detail + badge glyph. |
| `macos/Sources/Features/Update/UpdateSimulator.swift` | DEBUG-only scripted state driver (9 scenarios, no network). |
| `macos/Sources/Features/Terminal/Window Styles/TerminalWindow.swift` | Adds titlebar update accessory; `supportsUpdateAccessory` (`:62`). |
| `macos/Sources/Features/Terminal/BaseTerminalController.swift` | Overlay fallback + `activateUpdateOverlayFallback()` (`:1193`). |
| `macos/Sources/Features/Terminal/TerminalController.swift` | `configureWorkspaceTitlebar()` strips accessories then calls the fallback (`:1272-1292`). |
| `macos/Sources/App/macOS/AppDelegate.swift` | Owns `UpdateController`; `startUpdater()` gated `#if !DEBUG` (`:271`); DEBUG Simulate-Update menu (`:745+`). |
| `macos/Ghostties-Info.plist` | `SUEnableAutomaticChecks=true` (`:111`), `SUPublicEDKey`. |
| `.github/workflows/ghostties-release.yml` | Xcode pin (`:125`), build number (`:82`), notarize+staple (`:328`), appcast regen + EdDSA signing (`:385`). |

---

## 10. Related

- **Linear SSD-360** (Low) — sidebar open/closed state not preserved across relaunch;
  found during the beta.18 OTA test (rides on `window-save-state=never` window
  restoration; fix = persist visibility via `@AppStorage` like `ghostties.sidebarTab`
  already does).
- **See also:** Second Brain note "Sparkle Auto-Update (companion)" — durable
  cross-project reference (link to be wired by the orchestrator).
