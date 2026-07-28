#!/usr/bin/env bash
# Merge upstream openstreetmap-website + OHM patches/overlays into a HOST
# worktree you can edit with your normal editor. Patch conflicts leave <<<<<<<
# markers in the files. Nothing is committed or pushed anywhere.
#
# Usage:
#   ./scripts/merge.sh                     # against the upstream clone's HEAD (latest)
#   ./scripts/merge.sh $(cat UPSTREAM_BASE)  # against the known-good base
#   ./scripts/merge.sh --clean             # remove the merged worktree
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OSM="${OSM_CLONE:-$HERE/../openstreetmap-website}"
MERGED="${MERGED_DIR:-$HERE/../ohm-website-merged}"

if [[ "${1:-}" == "--clean" ]]; then
  git -C "$OSM" worktree remove --force "$MERGED" 2>/dev/null || rm -rf "$MERGED"
  echo "Removed $MERGED"
  exit 0
fi

REF="${1:-HEAD}"

if [[ -d "$MERGED" ]]; then
  echo "!! $MERGED already exists."
  echo "   Run './scripts/merge.sh --clean' first (you lose local edits not exported as patches)."
  exit 1
fi

echo "Creating merged tree at $MERGED (upstream ref: $REF)"
git -C "$OSM" worktree add --detach "$MERGED" "$REF" || exit 1
cd "$MERGED"

CONFLICTS=()
while IFS= read -r -d '' p; do
  git apply --3way "$p" 2>/dev/null || CONFLICTS+=("${p#"$HERE"/patches/}")
done < <(find "$HERE/patches" -name '*.patch' -print0 | sort -z)

cp -R "$HERE/overlays/." .
chmod +x start.sh 2>/dev/null || true
while IFS= read -r f; do
  [[ -n "$f" && -e "$f" ]] && rm -rf "$f"
done < "$HERE/REMOVALS"

echo ""
if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
  echo "=== ${#CONFLICTS[@]} patch(es) conflicted — fix the <<<<<<< markers in: ==="
  grep -rl '^<<<<<<< ' --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null \
    | sed "s|^\./|  $MERGED/|"
  echo ""
  echo "After fixing a file, export the updated patch:"
  echo "  ./scripts/export-patch.sh <relative/path/to/file>"
else
  echo "=== All patches applied cleanly ==="
fi
echo ""
echo "Run the site:  docker compose -f docker-compose.upstream.yml up --build"
