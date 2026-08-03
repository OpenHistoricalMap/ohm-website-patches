#!/usr/bin/env bash
# Move OHM to a newer upstream commit with one command: clones
# openstreetmap-website if needed, rebuilds merged/ and updates UPSTREAM_BASE.
# Usage:
#   ./scripts/sync.sh            # latest upstream master
#   ./scripts/sync.sh <sha|tag>  # a specific upstream commit
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[ -d "$ROOT/upstream/.git" ] || git clone https://github.com/openstreetmap/openstreetmap-website.git "$ROOT/upstream"
git -C "$ROOT/upstream" fetch origin master --tags

SHA=$(git -C "$ROOT/upstream" rev-parse --verify "${1:-origin/master}^{commit}")
OLD=$(cat "$ROOT/UPSTREAM_BASE")

echo "Current base: $OLD"
echo "New base:     $SHA"
echo "Upstream commits in between: $(git -C "$ROOT/upstream" rev-list --count "$OLD..$SHA" 2>/dev/null || echo "?")"
echo ""

"$ROOT/scripts/build.sh" "$SHA"

echo "$SHA" > "$ROOT/UPSTREAM_BASE"
echo "UPSTREAM_BASE updated: $OLD -> $SHA"
echo "If there were conflicts: fix the markers in merged/, then ./scripts/export.sh --all"
echo "Validate before pushing: ./scripts/lint.sh && ./scripts/test.sh"
