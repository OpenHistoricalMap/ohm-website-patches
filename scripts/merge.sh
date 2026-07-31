#!/usr/bin/env bash
# Merge upstream openstreetmap-website + OHM patches/overlays into ../ohm-website-merged.
# Conflicts are left as <<<<<<< markers to fix in your editor.
# Usage:  ./scripts/merge.sh [ref]   # rebuilds ../ohm-website-merged from scratch
#                                    # default ref: the commit in UPSTREAM_BASE
# WARNING: edits in ../ohm-website-merged not saved with export-patch.sh are lost.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OSM="$HERE/../openstreetmap-website"
MERGED="$HERE/../ohm-website-merged"

# Stop the dev web container first: while it runs, its mounts keep
# node_modules/tmp/storage inside the merged folder undeletable.
docker compose -f "$HERE/docker-compose.yml" rm -sf web >/dev/null 2>&1

# Delete the previous merged folder (worktree remove also clears git's record
# of it; the rm -rf fallback covers a folder git no longer knows about).
git -C "$OSM" worktree remove --force "$MERGED" 2>/dev/null || rm -rf "$MERGED" 2>/dev/null
# Docker leaves root-owned files behind (node_modules, tmp, storage); if the
# folder survived, delete its contents from a container where we are root.
if [ -e "$MERGED" ]; then
  docker run --rm -v "$MERGED":/merged alpine sh -c 'rm -rf /merged/* /merged/.[!.]* /merged/..?*'
  rm -rf "$MERGED"
fi
git -C "$OSM" worktree prune
git -C "$OSM" worktree add --detach "$MERGED" "${1:-$(cat "$HERE/UPSTREAM_BASE")}" || exit 1
cd "$MERGED"

# 1. patches (diffs on upstream files)
FAILED=0
for p in $(find "$HERE/patches" -name '*.patch' | sort); do
  git apply --3way "$p" 2>/dev/null || { echo "conflict: ${p#"$HERE"/patches/}"; FAILED=$((FAILED+1)); }
done

# Relabel conflict markers: "ours/theirs" -> "OSM upstream (date) / OHM patch"
OSM_DATE=$(git log -1 --format=%cs HEAD)
grep -rl '^<<<<<<< ours' . --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null \
  | while read -r f; do
      sed -i '' -e "s/^<<<<<<< ours/<<<<<<< OSM upstream ($OSM_DATE)/" \
                -e "s/^>>>>>>> theirs/>>>>>>> OHM patch/" "$f"
    done

# 2. overlays (OHM-only files) and removals
cp -R "$HERE/overlays/." .
while read -r f; do [[ -n "$f" ]] && rm -rf "./$f"; done < "$HERE/REMOVALS"

echo ""
echo "$FAILED conflicting patch(es). Files with <<<<<<< markers:"
grep -rl '^<<<<<<<' . --exclude-dir=node_modules --exclude-dir=.git || echo "  none"
echo ""
echo "Fix markers, then: ./scripts/export-patch.sh <file>"
echo "Validate:          ./scripts/lint.sh && ./scripts/test.sh"
echo "Run the site:      docker compose up   # http://localhost:3000"
