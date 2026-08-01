#!/usr/bin/env bash
# Save the current state of file(s) in the merged worktree back into patches/,
# replacing the old patch with one that applies cleanly on the merged upstream ref.
# Usage:
#   ./scripts/export-patch.sh config/routes.rb [config/layers.yml ...]
#   ./scripts/export-patch.sh --all     # export every modified file in the merged tree
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
MERGED="${MERGED_DIR:-$HERE/../ohm-website-merged}"

if [[ "${1:-}" == "--all" ]]; then
  # Every tracked upstream TEXT file with unexported edits. Skipped on purpose:
  # untracked files (overlays), binaries (overlays), REMOVALS deletions, and
  # generated lockfiles.
  FILES=()
  while IFS=$'\t' read -r added deleted f; do
    case "$f" in
      Gemfile.lock|yarn.lock)
        # Lockfiles ship as overlays (generated files, not patches) —
        # refresh the overlay copy when the merged one changed.
        if ! cmp -s "$MERGED/$f" "$HERE/overlays/$f"; then
          cp "$MERGED/$f" "$HERE/overlays/$f"
          echo "overlay updated (lockfile): overlays/$f"
        fi
        continue ;;
      db/structure.sql) continue ;;
    esac
    [[ "$added" == "-" ]] && { echo "skip (binary, belongs in overlays/): $f"; continue; }
    [[ -f "$MERGED/$f" ]] || { echo "skip (deleted, covered by REMOVALS): $f"; continue; }
    FILES+=("$f")
  done < <(git -C "$MERGED" diff HEAD --numstat)

  # Prune obsolete patches: their file no longer differs from upstream.
  while IFS= read -r -d '' p; do
    f="${p#"$HERE"/patches/}"; f="${f%.patch}"
    if [[ -f "$MERGED/$f" ]] && git -C "$MERGED" diff HEAD --quiet -- "$f" 2>/dev/null; then
      rm "$p"
      echo "pruned (file matches upstream again): patches/$f.patch"
    fi
  done < <(find "$HERE/patches" -name '*.patch' -print0)

  [[ ${#FILES[@]} -ge 1 ]] || { echo "Nothing to export — merged tree matches the patches."; exit 0; }
  set -- "${FILES[@]}"
fi

[[ $# -ge 1 ]] || { echo "Usage: $0 <relative/path> [...] | --all"; exit 1; }

for f in "$@"; do
  if [[ ! -f "$MERGED/$f" ]]; then
    echo "!! not found: $MERGED/$f"; exit 1
  fi
  if grep -q '^<<<<<<< ' "$MERGED/$f"; then
    echo "!! $f still has conflict markers — fix them first"; exit 1
  fi
  git -C "$MERGED" add -- "$f"          # clears unmerged state
  mkdir -p "$(dirname "$HERE/patches/$f.patch")"
  git -C "$MERGED" diff --cached -- "$f" > "$HERE/patches/$f.patch"
  echo "updated: patches/$f.patch"
done

echo ""
echo "When ALL conflicted patches are exported, record the new base:"
echo "  git -C \"$MERGED\" rev-parse HEAD > \"$HERE/UPSTREAM_BASE\""
