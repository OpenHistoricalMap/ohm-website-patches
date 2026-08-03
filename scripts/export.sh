#!/usr/bin/env bash
# Save the current state of file(s) in merged/ back into patches/, replacing the
# old patch with one that applies cleanly on the current upstream ref.
# Usage:
#   ./scripts/export.sh config/routes.rb [config/layers.yml ...]
#   ./scripts/export.sh --all     # every modified file in merged/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERGED="$ROOT/merged"

if [[ "${1:-}" == "--all" ]]; then
  # Every tracked upstream TEXT file with unexported edits. Skipped on purpose:
  # untracked files (overlays), binaries (overlays), REMOVALS deletions, and
  # generated lockfiles.
  FILES=()
  while IFS=$'\t' read -r added deleted f; do
    case "$f" in
      Gemfile.lock|yarn.lock)
        # Lockfiles are generated files, so they live in overlays/, not patches/.
        # Copy them over when the merged one changed.
        if ! cmp -s "$MERGED/$f" "$ROOT/overlays/$f"; then
          cp "$MERGED/$f" "$ROOT/overlays/$f"
          echo "overlay updated (lockfile): overlays/$f"
        fi
        continue ;;
      db/structure.sql) continue ;;
    esac
    [[ "$added" == "-" ]] && { echo "skip (binary, belongs in overlays/): $f"; continue; }
    [[ -f "$MERGED/$f" ]] || { echo "skip (deleted, covered by REMOVALS): $f"; continue; }
    FILES+=("$f")
  done < <(git -C "$MERGED" diff HEAD --numstat)

  # Delete obsolete patches: their file no longer differs from upstream.
  for p in $(find "$ROOT/patches" -name '*.patch'); do
    f="${p#"$ROOT"/patches/}"; f="${f%.patch}"
    if [[ -f "$MERGED/$f" ]] && git -C "$MERGED" diff HEAD --quiet -- "$f" 2>/dev/null; then
      rm "$p"
      echo "deleted (file matches upstream again): patches/$f.patch"
    fi
  done

  [[ ${#FILES[@]} -ge 1 ]] || { echo "Nothing to export — merged/ matches the patches."; exit 0; }
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
  git -C "$MERGED" add -- "$f"          # clears the unmerged state
  mkdir -p "$(dirname "$ROOT/patches/$f.patch")"
  git -C "$MERGED" diff --cached -- "$f" > "$ROOT/patches/$f.patch"
  echo "updated: patches/$f.patch"
done

echo ""
echo "When ALL conflicted patches are exported, record the new base:"
echo "  git -C merged rev-parse HEAD > UPSTREAM_BASE"
