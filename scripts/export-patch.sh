#!/usr/bin/env bash
# Save the current state of file(s) in the merged worktree back into patches/,
# replacing the old patch with one that applies cleanly on the merged upstream ref.
# Usage: ./scripts/export-patch.sh config/routes.rb [config/layers.yml ...]
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
MERGED="${MERGED_DIR:-$HERE/../ohm-website-merged}"

[[ $# -ge 1 ]] || { echo "Usage: $0 <relative/path> [...]"; exit 1; }

for f in "$@"; do
  if [[ ! -f "$MERGED/$f" ]]; then
    echo "!! not found: $MERGED/$f"; exit 1
  fi
  if grep -q '^<<<<<<< ' "$MERGED/$f"; then
    echo "!! $f still has conflict markers — fix them first"; exit 1
  fi
  git -C "$MERGED" add -- "$f"          # clears unmerged state
  git -C "$MERGED" diff --cached -- "$f" > "$HERE/patches/$f.patch"
  echo "updated: patches/$f.patch"
done

echo ""
echo "When ALL conflicted patches are exported, record the new base:"
echo "  git -C \"$MERGED\" rev-parse HEAD > \"$HERE/UPSTREAM_BASE\""
