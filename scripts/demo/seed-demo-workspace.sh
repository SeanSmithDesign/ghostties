#!/usr/bin/env bash
# =============================================================================
# seed-demo-workspace.sh — Write isolated demo workspace.json for screen captures
#
# PURPOSE
#   Seeds ~/Library/Application Support/Ghostties Demo/workspace.json with 7
#   fictional projects that look realistic on camera. This directory is used
#   exclusively by Ghostties Demo.app (bundle ID com.seansmithdesign.ghostties.demo).
#   It NEVER touches ~/Library/Application Support/Ghostties/ (release workspace).
#
# USAGE
#   ./scripts/demo/seed-demo-workspace.sh
#
#   Idempotent / re-runnable. Any existing workspace.json is backed up to
#   workspace.json.bak-<timestamp> before overwriting.
# =============================================================================
set -euo pipefail

DEMO_DIR="$HOME/Library/Application Support/Ghostties Demo"
TARGET="$DEMO_DIR/workspace.json"

echo "==> Seeding Ghostties Demo workspace"
echo "    Target: $TARGET"
echo ""

# ── Safety check: never touch the release workspace ─────────────────────────
RELEASE_DIR="$HOME/Library/Application Support/Ghostties"
if [[ "$DEMO_DIR" == "$RELEASE_DIR" ]]; then
  echo "ERROR: Demo dir resolved to release dir. Aborting."
  exit 1
fi

# ── Create directory if needed ───────────────────────────────────────────────
if [[ ! -d "$DEMO_DIR" ]]; then
  echo "    Creating directory: $DEMO_DIR"
  mkdir -p "$DEMO_DIR"
  chmod 700 "$DEMO_DIR"
fi

# ── Back up existing workspace.json ─────────────────────────────────────────
if [[ -f "$TARGET" ]]; then
  BACKUP="$DEMO_DIR/workspace.json.bak-$(date +%Y%m%dT%H%M%S)"
  echo "    Backing up existing workspace.json -> $(basename "$BACKUP")"
  cp "$TARGET" "$BACKUP"
fi

# ── Generate JSON via python3 ────────────────────────────────────────────────
echo "    Generating workspace.json with 7 projects..."

python3 - "$TARGET" <<'PYEOF'
import sys
import json
import subprocess
import datetime

target_path = sys.argv[1]

demo_base = "/Users/seansmith/Code/ghostties/examples/demo-workspace"

projects_spec = [
    ("atlas-api",    "atlas-api",    "banshee"),
    ("fieldwork",    "fieldwork",    "clyde"),
    ("pendulum",     "pendulum",     "ember"),
    ("silo",         "silo",         "haunt"),
    ("switchboard",  "switchboard",  "pinky"),
    ("trove",        "trove",        "specter"),
    ("wren",         "wren",         "wisp"),
]

def new_uuid():
    result = subprocess.run(["uuidgen"], capture_output=True, text=True, check=True)
    return result.stdout.strip().upper()

# Build project list, track switchboard UUID for lastSelectedProjectId
now_base = datetime.datetime.utcnow()
projects = []
switchboard_id = None

for i, (name, subdir, ghost) in enumerate(projects_spec):
    uid = new_uuid()
    # Stagger timestamps slightly so they look like real usage history
    ts = (now_base - datetime.timedelta(hours=i * 3)).strftime("%Y-%m-%dT%H:%M:%SZ")
    proj = {
        "ghostCharacter": ghost,
        "id": uid,
        "isPinned": False,
        "lastActiveAt": ts,
        "name": name,
        "rootPath": f"{demo_base}/{subdir}",
    }
    projects.append(proj)
    if subdir == "switchboard":
        switchboard_id = uid

state = {
    "hasDismissedPinMigrationNotice": True,
    "hasShownPinMigrationNotice": True,
    "lastSelectedProjectId": switchboard_id,
    "projects": projects,
    "sessions": [],
    "sidebarMode": 0,
    "templates": [],
}

with open(target_path, "w") as f:
    json.dump(state, f, indent=2, sort_keys=True)

print(f"    Written {len(projects)} projects.")
print(f"    switchboard UUID: {switchboard_id}")
print(f"    lastSelectedProjectId: {state['lastSelectedProjectId']}")
PYEOF

chmod 600 "$TARGET"

echo ""
echo "==> Verifying output..."
python3 - "$TARGET" <<'PYEOF'
import sys, json
with open(sys.argv[1]) as f:
    data = json.load(f)
print(f"    Project count : {len(data['projects'])}")
print(f"    sidebarMode   : {data['sidebarMode']}")
print(f"    lastSelected  : {data['lastSelectedProjectId']}")
switchboard = next((p for p in data['projects'] if p['name'] == 'switchboard'), None)
if switchboard:
    match = switchboard['id'] == data['lastSelectedProjectId']
    print(f"    switchboard id: {switchboard['id']}")
    print(f"    lastSelected == switchboard: {match}")
else:
    print("    ERROR: switchboard project not found!")
    sys.exit(1)
PYEOF

echo ""
echo "==> Done. Seed complete:"
echo "    $TARGET"
