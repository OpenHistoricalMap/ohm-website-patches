#!/usr/bin/env bash
# Apply the OHM customizations on an openstreetmap-website checkout:
#   patches/   diffs for the upstream files OHM modifies
#   overlays/  whole files OHM adds (and modified binaries)
#   REMOVALS   upstream files OHM deletes
# Used by CI. Exits non-zero if a patch fails.
# Usage: ./scripts/apply.sh /path/to/checkout
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-/var/www}"

[ -d "$DEST" ] || { echo "Error: destination not found: $DEST" >&2; exit 1; }
# Make it absolute: the copy step below runs from another folder.
DEST="$(cd "$DEST" && pwd)"

echo "Upstream base expected: $(cat "$ROOT/UPSTREAM_BASE")"
echo "Applying patches to $DEST"

FAILED=0
for p in $(find "$ROOT/patches" -name '*.patch' | sort); do
  f="${p#"$ROOT"/patches/}"; f="${f%.patch}"
  if git -C "$DEST" apply --3way "$p" 2>/dev/null || git -C "$DEST" apply "$p" 2>/dev/null; then
    echo "  patch: $f"
  else
    echo "  FAILED: $f" >&2
    FAILED=$((FAILED + 1))
  fi
done

echo "Copying overlays"
cp -R "$ROOT/overlays/." "$DEST"

echo "Deleting the files listed in REMOVALS"
while read -r f; do
  [ -n "$f" ] || continue
  rm -rf "$DEST/$f"
done < "$ROOT/REMOVALS"

if [ "$FAILED" -gt 0 ]; then
  echo "Done with $FAILED failed patch(es) — resolve them by hand." >&2
  exit 1
fi
echo "Done."
