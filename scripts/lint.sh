#!/usr/bin/env bash
# Run the same linters as the Lint workflow in ohm-website-merged, locally.
# Usage: ./scripts/lint.sh
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose run --rm --no-deps web bash -c '
  cd /app
  set -e
  echo "== rubocop ==";  bundle exec rubocop
  echo "== erb_lint =="; bundle exec erb_lint .
  echo "== herb ==";     bundle exec herb analyze app/
  echo "== eslint ==";   node_modules/.bin/eslint -c config/eslint.config.mjs --no-warn-ignored --format compact app/ config/ test/
  echo "All linters passed."
'
