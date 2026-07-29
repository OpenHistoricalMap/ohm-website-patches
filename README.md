# ohm-website-patches

OHM customizations for [openstreetmap-website](https://github.com/openstreetmap/openstreetmap-website), kept separate from the fork history. Upstream code flows in untouched; every OHM change is an explicit patch, overlay, or removal ([issues#735](https://github.com/OpenHistoricalMap/issues/issues/735)).

## Layout

- `patches/` — one `.patch` per upstream file OHM modifies, mirroring the repo tree.
- `overlays/` — whole files OHM adds, plus modified binaries. `overlays/config/locales/overrides/en.yml` holds OHM strings; upstream `en.yml` is never patched.
- `REMOVALS` — upstream files OHM deletes.
- `UPSTREAM_BASE` — upstream commit the patches were last resolved against.
- Excluded: `config/locales/*` (Translatewiki) and lockfiles (regenerate from the patched `Gemfile`/`package.json`).

## Scripts

| Script | What it does |
|---|---|
| `merge.sh [ref]` | Builds `../ohm-website-merged` (worktree of `../openstreetmap-website`) with everything applied. Conflicts stay as `<<<<<<< OSM upstream / OHM patch` markers. |
| `export-patch.sh <file>` \| `--all` | Saves edits in the merged tree back into `patches/`. `--all` exports everything modified and prunes obsolete patches. |
| `apply.sh <checkout>` | One-shot apply onto any checkout. For CI/Docker builds; exits non-zero on failure. |

## Workflow

```bash
./scripts/merge.sh                    # build merged tree; fix any <<<<<<< markers
./scripts/export-patch.sh --all       # save your fixes into patches/

cd ../ohm-website-merged              # run the site
docker compose -f docker-compose.dev.yml up db -d
docker compose -f docker-compose.dev.yml run --service-ports web bash
bundle install && ./start.sh          # → http://localhost:3000
```

Rules: edit files in `../ohm-website-merged`, never `.patch` files by hand. Only exported changes survive a re-merge.

## Upstream sync

```bash
git -C ../openstreetmap-website pull
./scripts/merge.sh                    # 0 conflicts → done; else fix, export, commit
git -C ../ohm-website-merged rev-parse HEAD > UPSTREAM_BASE
```
