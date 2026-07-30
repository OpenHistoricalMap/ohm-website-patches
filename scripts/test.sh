#!/usr/bin/env bash
# Run tests locally against the merged tree, like CI does.
# Usage:
#   ./scripts/test.sh                                # full suite
#   ./scripts/test.sh test/system/some_test.rb:295   # single test
#   PREPARE=1 ./scripts/test.sh ...                  # recompile assets (after JS/CSS/locale changes)
set -euo pipefail
cd "$(dirname "$0")/.."

MERGED="${MERGED_DIR:-../ohm-website-merged}"
[ -f "$MERGED/config/database.yml" ] || cp "$MERGED/config/docker.database.yml" "$MERGED/config/database.yml"
[ -f "$MERGED/config/storage.yml" ] || cp "$MERGED/config/example.storage.yml" "$MERGED/config/storage.yml"
touch "$MERGED/config/settings.local.yml"

docker compose -f docker-compose.dev.yml up -d db memcached
until docker compose -f docker-compose.dev.yml exec -T db pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
docker compose -f docker-compose.dev.yml exec -T db psql -U postgres -qc \
  "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='openstreetmap') THEN CREATE ROLE openstreetmap SUPERUSER LOGIN PASSWORD 'openstreetmap'; END IF; END \$\$;"

CMD=${*:+"test $*"}
docker compose -f docker-compose.dev.yml run --rm --no-deps -e RAILS_ENV=test web bash -c "
  unset DATABASE_URL RAILS_MASTER_KEY RAILS_CREDENTIALS_YML_ENC
  set -e
  bundle exec rails db:create db:migrate 2>&1 | tail -1
  if [ ${PREPARE:-0} = 1 ] || [ ! -d public/assets ]; then
    bundle exec i18n export && bundle exec rails assets:precompile
  fi
  bundle exec rails ${CMD:-test:all}
"
