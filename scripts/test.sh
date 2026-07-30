#!/usr/bin/env bash
# Run tests locally against the merged tree, like CI does.
# Usage:
#   ./scripts/test.sh                                # full suite
#   ./scripts/test.sh test/system/some_test.rb:295   # single test
#   PREPARE=1 ./scripts/test.sh ...                  # recompile assets (after JS/CSS/locale changes)
#   WORKERS=2 ./scripts/test.sh                      # override test parallelism (default 4, like CI)
#   WAIT=10 ./scripts/test.sh                        # override Capybara max wait (default 20; CI uses 10)
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
# More parallel Firefox instances than the Docker VM can boot within Selenium's
# 45s driver-startup lock makes tests error out; 4 matches the CI runner.
# Wait above CI's 10s because 4 Firefoxes contending for the local VM's cores
# can stall page loads past 10s and fail asserts on pages that render fine.
docker compose -f docker-compose.dev.yml run --rm --no-deps -e RAILS_ENV=test \
  -e PARALLEL_WORKERS="${WORKERS:-4}" -e CAPYBARA_MAX_WAIT_TIME="${WAIT:-20}" web bash -c "
  unset DATABASE_URL RAILS_MASTER_KEY RAILS_CREDENTIALS_YML_ENC
  set -e
  bundle exec rails db:create db:migrate 2>&1 | tail -1
  if [ ${PREPARE:-0} = 1 ] || [ ! -d public/assets ]; then
    bundle exec i18n export && bundle exec rails assets:precompile
  fi
  bundle exec rails ${CMD:-test:all}
"
