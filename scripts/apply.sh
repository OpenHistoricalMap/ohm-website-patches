#!/usr/bin/env bash
# Apply OHM overlays on top of an ohm-website checkout.
# Usage: ./scripts/apply.sh /path/to/ohm-website
set -euo pipefail

DEST="${1:-${OHM_WEBSITE_DIR:-/var/www}}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/overlays"

if [[ ! -d "$DEST" ]]; then
  echo "Error: destination not found: $DEST" >&2
  exit 1
fi

if [[ ! -d "$SRC" ]]; then
  echo "Error: overlays directory not found: $SRC" >&2
  exit 1
fi

echo "Applying overlays from $SRC to $DEST"
cd "$SRC"
find . -type f | while read -r f; do
  target="$DEST/${f#./}"
  mkdir -p "$(dirname "$target")"
  cp "$f" "$target"
  echo "  $f"
done
echo "Done."
