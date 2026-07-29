#!/usr/bin/env bash
# Merge upstream openstreetmap-website + OHM patches/overlays into ../ohm-website-merged.
# Conflicts are left as <<<<<<< markers to fix in your editor.
# Usage:  ./scripts/merge.sh   # rebuilds ../ohm-website-merged from scratch
# WARNING: edits in ../ohm-website-merged not saved with export-patch.sh are lost.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OSM="$HERE/../openstreetmap-website"
MERGED="$HERE/../ohm-website-merged"

# Delete the previous merged folder (worktree remove also clears git's record
# of it; the rm -rf fallback covers a folder git no longer knows about).
git -C "$OSM" worktree remove --force "$MERGED" 2>/dev/null || rm -rf "$MERGED"
git -C "$OSM" worktree add --detach "$MERGED" "${1:-HEAD}" || exit 1
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
chmod +x start.sh
while read -r f; do [[ -n "$f" ]] && rm -rf "./$f"; done < "$HERE/REMOVALS"

echo ""
echo "$FAILED conflicting patch(es). Files with <<<<<<< markers:"
grep -rl '^<<<<<<<' . --exclude-dir=node_modules --exclude-dir=.git || echo "  none"
echo ""
echo "Fix markers, then: ./scripts/export-patch.sh <file>"
echo "Run the site:       docker compose -f docker-compose.upstream.yml up --build"
