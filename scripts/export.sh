#!/usr/bin/env bash
# Save the current state of file(s) in merged/ back into patches/, replacing the
# old patch with one that applies cleanly on the current upstream ref.
# Usage:
#   ./scripts/export.sh config/routes.rb [config/layers.yml ...]
#   ./scripts/export.sh --all       # every modified file in merged/
#   ./scripts/export.sh --check     # list what is missing, change nothing (exit 1 if any)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERGED="$ROOT/merged"

# --check walks the same list as --all, but only reports.
CHECK=0
[[ "${1:-}" == "--check" ]] && { CHECK=1; set -- --all; }

if [[ "${1:-}" == "--all" ]]; then
  # Every tracked upstream TEXT file with unexported edits. Skipped on purpose:
  # untracked files (overlays), binaries (overlays), REMOVALS deletions, and
  # generated lockfiles.
  FILES=()
  PENDING=0
  while IFS=$'\t' read -r added deleted f; do
    case "$f" in
      Gemfile.lock|yarn.lock)
        # Lockfiles are generated files, so they live in overlays/, not patches/.
        # Copy them over when the merged one changed.
        if ! cmp -s "$MERGED/$f" "$ROOT/overlays/$f"; then
          if [[ "$CHECK" == 1 ]]; then
            echo "not exported (lockfile): overlays/$f"
            PENDING=$((PENDING + 1))
          else
            cp "$MERGED/$f" "$ROOT/overlays/$f"
            echo "overlay updated (lockfile): overlays/$f"
          fi
        fi
        continue ;;
      db/structure.sql) continue ;;
      config/settings.yml)
        # start.sh rewrites this file inside the container on every dev boot
        # (server_url, oauth keys, memcached), and merged/ is a bind mount, so
        # those dev values would end up in the patch. Export it on purpose:
        #   ./scripts/export.sh config/settings.yml
        continue ;;
    esac
    # The skip notes are for --all; --check only reports what is missing.
    if [[ "$added" == "-" ]]; then
      [[ "$CHECK" == 1 ]] || echo "skip (binary, belongs in overlays/): $f"
      continue
    fi
    if [[ ! -f "$MERGED/$f" ]]; then
      [[ "$CHECK" == 1 ]] || echo "skip (deleted, covered by REMOVALS): $f"
      continue
    fi
    FILES+=("$f")
  done < <(git -C "$MERGED" diff HEAD --numstat)

  # Delete obsolete patches: their file no longer differs from upstream.
  for p in $(find "$ROOT/patches" -name '*.patch'); do
    f="${p#"$ROOT"/patches/}"; f="${f%.patch}"
    if [[ -f "$MERGED/$f" ]] && git -C "$MERGED" diff HEAD --quiet -- "$f" 2>/dev/null; then
      if [[ "$CHECK" == 1 ]]; then
        echo "obsolete (file matches upstream again): patches/$f.patch"
        PENDING=$((PENDING + 1))
      else
        rm "$p"
        echo "deleted (file matches upstream again): patches/$f.patch"
      fi
    fi
  done

  if [[ "$CHECK" == 1 ]]; then
    # A patched file is exported when its diff still matches the stored .patch.
    # Guarded: expanding an empty array trips `set -u` on bash 3.2 (macOS).
    if [[ ${#FILES[@]} -gt 0 ]]; then
      for f in "${FILES[@]}"; do
        if ! diff -q <(git -C "$MERGED" diff HEAD -- "$f") "$ROOT/patches/$f.patch" >/dev/null 2>&1; then
          echo "not exported: $f"
          PENDING=$((PENDING + 1))
        fi
      done
    fi

    # Overlays are OHM-only files, so git does not track them in merged/.
    # `--all` does not export them either: copy them back by hand.
    for o in $(find "$ROOT/overlays" -type f); do
      f="${o#"$ROOT"/overlays/}"
      [[ -f "$MERGED/$f" ]] || continue
      if ! cmp -s "$o" "$MERGED/$f"; then
        echo "not exported (overlay, copy it by hand): $f"
        PENDING=$((PENDING + 1))
      fi
    done

    [[ "$PENDING" == 0 ]] && { echo "merged/ matches the patches."; exit 0; }
    echo ""
    echo "$PENDING change(s) would be lost on the next build. Run: npm run export"
    exit 1
  fi

  [[ ${#FILES[@]} -ge 1 ]] || { echo "Nothing to export — merged/ matches the patches."; exit 0; }
  set -- "${FILES[@]}"
fi

[[ $# -ge 1 ]] || { echo "Usage: $0 <relative/path> [...] | --all | --check"; exit 1; }

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
