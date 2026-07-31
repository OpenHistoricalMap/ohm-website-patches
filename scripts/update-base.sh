#!/usr/bin/env bash
# Move OHM to a newer upstream commit with one command.
# Clones openstreetmap-website if needed, rebuilds the merged tree and
# updates UPSTREAM_BASE.
# Usage:
#   ./scripts/update-base.sh            # latest upstream master
#   ./scripts/update-base.sh <sha|tag>  # a specific upstream commit
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OSM="$HERE/../openstreetmap-website"

[ -d "$OSM/.git" ] || git clone https://github.com/openstreetmap/openstreetmap-website.git "$OSM"
git -C "$OSM" fetch origin master --tags

SHA=$(git -C "$OSM" rev-parse --verify "${1:-origin/master}^{commit}")
OLD=$(cat "$HERE/UPSTREAM_BASE")

echo "Current base: $OLD"
echo "New base:     $SHA"
echo "Upstream commits in between: $(git -C "$OSM" rev-list --count "$OLD..$SHA" 2>/dev/null || echo "?")"
echo ""

"$HERE/scripts/merge.sh" "$SHA"

echo "$SHA" > "$HERE/UPSTREAM_BASE"
echo "UPSTREAM_BASE updated: $OLD -> $SHA"
echo "If there were conflicts: fix the markers in ../ohm-website-merged, then ./scripts/export-patch.sh --all"
echo "Validate before pushing: ./scripts/lint.sh && ./scripts/test.sh"
