#!/usr/bin/env bash
# Apply OHM customizations on top of an openstreetmap-website checkout.
# 1. patches/  — per-file diffs for upstream files OHM modifies
# 2. overlays/ — whole files OHM adds (plus modified binaries)
# 3. REMOVALS  — upstream files OHM deletes
# Usage: ./scripts/apply.sh /path/to/checkout
set -euo pipefail

DEST="${1:-${OHM_WEBSITE_DIR:-/var/www}}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$DEST" ]]; then
  echo "Error: destination not found: $DEST" >&2
  exit 1
fi

echo "Upstream base expected: $(cat "$HERE/UPSTREAM_BASE")"

echo "Applying patches from $HERE/patches to $DEST"
FAILED=0
while IFS= read -r -d '' p; do
  rel="${p#"$HERE"/patches/}"
  if git -C "$DEST" apply --3way "$p" 2>/dev/null || git -C "$DEST" apply "$p" 2>/dev/null; then
    echo "  patch: ${rel%.patch}"
  else
    echo "  FAILED: ${rel%.patch}" >&2
    FAILED=$((FAILED + 1))
  fi
done < <(find "$HERE/patches" -name '*.patch' -print0 | sort -z)

echo "Applying overlays from $HERE/overlays to $DEST"
(
  cd "$HERE/overlays"
  find . -type f | while IFS= read -r f; do
    target="$DEST/${f#./}"
    mkdir -p "$(dirname "$target")"
    cp "$f" "$target"
    echo "  overlay: ${f#./}"
  done
)

if [[ -f "$HERE/REMOVALS" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" && -e "$DEST/$f" ]] && rm "$DEST/$f" && echo "  removed: $f"
  done < "$HERE/REMOVALS"
fi

if [[ "$FAILED" -gt 0 ]]; then
  echo "Done with $FAILED failed patch(es) — resolve manually." >&2
  exit 1
fi
echo "Done."
