#!/usr/bin/env bash
# Rebuild merged/ from scratch: upstream checkout + patches + overlays - REMOVALS.
# Conflicts are left as <<<<<<< markers to fix in your editor.
# Usage: ./scripts/build.sh [ref]     # default ref: the commit in UPSTREAM_BASE
# WARNING: edits in merged/ not saved with export.sh are lost.
#
# No `set -e` here on purpose: the script must reach the end to report conflicts.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Stop the dev web container first: while it runs, its mounts keep
# node_modules/tmp/storage inside merged/ undeletable.
docker compose -f "$ROOT/docker-compose.yml" rm -sf web >/dev/null 2>&1

# Delete the old merged/ (worktree remove also clears git's record of it;
# the rm -rf covers a folder git no longer knows about).
git -C "$ROOT/upstream" worktree remove --force "$ROOT/merged" 2>/dev/null || rm -rf "$ROOT/merged"
# Docker leaves root-owned files behind (node_modules, tmp, storage); if the
# folder survived, delete its contents from a container where we are root.
if [ -e "$ROOT/merged" ]; then
  docker run --rm -v "$ROOT/merged":/merged alpine sh -c 'rm -rf /merged/* /merged/.[!.]* /merged/..?*'
  rm -rf "$ROOT/merged"
fi

git -C "$ROOT/upstream" worktree prune
git -C "$ROOT/upstream" worktree add --detach "$ROOT/merged" "${1:-$(cat "$ROOT/UPSTREAM_BASE")}" || exit 1
cd "$ROOT/merged"

# 1. patches (diffs on upstream files)
FAILED=0
for p in $(find "$ROOT/patches" -name '*.patch' | sort); do
  git apply --3way "$p" 2>/dev/null || { echo "conflict: ${p#"$ROOT"/patches/}"; FAILED=$((FAILED+1)); }
done

# Rename the conflict markers: "ours/theirs" -> "OSM upstream (date) / OHM patch"
OSM_DATE=$(git log -1 --format=%cs HEAD)
grep -rl '^<<<<<<< ours' . --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null \
  | while read -r f; do
      sed -i '' -e "s/^<<<<<<< ours/<<<<<<< OSM upstream ($OSM_DATE)/" \
                -e "s/^>>>>>>> theirs/>>>>>>> OHM patch/" "$f"
    done

# 2. overlays (OHM-only files) and removals
cp -R "$ROOT/overlays/." .
while read -r f; do
  [ -n "$f" ] || continue
  rm -rf "./$f"
done < "$ROOT/REMOVALS"

echo ""
echo "$FAILED conflicting patch(es). Files with <<<<<<< markers:"
grep -rl '^<<<<<<<' . --exclude-dir=node_modules --exclude-dir=.git || echo "  none"
echo ""
echo "Fix the markers, then: ./scripts/export.sh <file>"
echo "Validate:               ./scripts/lint.sh && ./scripts/test.sh"
echo "Run the site:           docker compose up   # http://localhost:3000"
