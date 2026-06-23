#!/usr/bin/env bash
# =============================================================================
# refresh-demo.sh — Build, re-bundle, and launch Ghostties Demo.app
#
# PURPOSE
#   Produces /Applications/Ghostties Demo.app with bundle ID
#   com.seansmithdesign.ghostties.demo, which causes WorkspacePersistence to
#   resolve its state directory to "~/Library/Application Support/Ghostties Demo/"
#   — completely isolated from the release ("Ghostties") and dev ("Ghostties Dev")
#   workspaces. Use this for marketing screen captures.
#
# USAGE
#   ./scripts/demo/refresh-demo.sh             # build current checkout (default)
#   ./scripts/demo/refresh-demo.sh --pull-main # fetch + checkout main first
#
# FLAGS
#   --pull-main   Switch to main, fetch origin, and pull --ff-only BEFORE building.
#                 Only use this when you explicitly want the latest shipped code.
#                 Without this flag the script operates on whatever is checked out,
#                 which is safe for multi-session development workflows.
#
# SAFETY
#   - Never modifies ~/Library/Application Support/Ghostties/ (release workspace).
#   - Never runs killall. Quit any existing instance before running.
#   - arm64 only (GhosttyKit.xcframework is arm64-only).
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEME="Ghostties"
PROJECT="$REPO_ROOT/macos/Ghostties.xcodeproj"
BUILD_DIR="$REPO_ROOT/.build-demo"
DEST_APP="/Applications/Ghostties Demo.app"
BUNDLE_ID="com.seansmithdesign.ghostties.demo"

echo "==> Ghostties Demo refresh"
echo "    Repo: $REPO_ROOT"
echo "    Branch: $(git -C "$REPO_ROOT" branch --show-current)"
echo ""

# ── Optional: pull main ──────────────────────────────────────────────────────
if [[ "${1:-}" == "--pull-main" ]]; then
  echo "==> [--pull-main] Fetching origin and switching to main..."
  git -C "$REPO_ROOT" fetch origin
  git -C "$REPO_ROOT" checkout main
  git -C "$REPO_ROOT" pull --ff-only
  echo "    Done. Now on: $(git -C "$REPO_ROOT" branch --show-current)"
  echo ""
fi

# ── Phase 1: Build ──────────────────────────────────────────────────────────
echo "==> Phase 1: Building from source (Debug, arm64)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  ONLY_ACTIVE_ARCH=YES \
  ARCHS=arm64 \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | grep -E "^(Build|CompileSwift|error:|warning: build input|PhaseScriptExecution|== BUILD)" \
  | head -200 || true

# Verify the build actually succeeded by checking the binary exists
BUILT_APP=$(find "$BUILD_DIR/Build/Products/Debug" -maxdepth 1 -name "Ghostties Dev.app" -type d | head -1)
if [[ -z "$BUILT_APP" ]]; then
  echo ""
  echo "ERROR: Build output not found at $BUILD_DIR/Build/Products/Debug/Ghostties Dev.app"
  echo "       Run xcodebuild without grep to see full error output."
  exit 1
fi
echo "    Built: $BUILT_APP"
echo ""

# ── Phase 2: Re-bundle ───────────────────────────────────────────────────────
echo "==> Phase 2: Re-bundling to '$DEST_APP'..."

if [[ -d "$DEST_APP" ]]; then
  echo "    Removing previous $DEST_APP..."
  rm -rf "$DEST_APP"
fi

cp -R "$BUILT_APP" "$DEST_APP"
echo "    Copied."

PLIST="$DEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID"         "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Ghostties Demo"           "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Ghostties Demo"    "$PLIST"
echo "    Plist updated:"
echo "      CFBundleIdentifier  = $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
echo "      CFBundleName        = $(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$PLIST")"
echo "      CFBundleDisplayName = $(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$PLIST")"
echo "      CFBundleExecutable  = $(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST") (unchanged)"
echo ""

# ── Phase 3: Re-sign ad-hoc ──────────────────────────────────────────────────
echo "==> Phase 3: Ad-hoc re-signing..."
codesign --force --deep --sign - "$DEST_APP"
echo "    Signed. Verifying..."
codesign --verify --deep "$DEST_APP"
echo "    Verification passed."
echo ""

# ── Phase 4: Launch ──────────────────────────────────────────────────────────
echo "==> Phase 4: Launching Ghostties Demo..."
open "$DEST_APP"
echo "    Launched."
echo ""
echo "==> Done. Ghostties Demo is running with isolated state:"
echo "    ~/Library/Application Support/Ghostties Demo/workspace.json"
echo ""
echo "    To quit cleanly (never use killall):"
echo "    osascript -e 'tell application \"Ghostties Demo\" to quit'"
