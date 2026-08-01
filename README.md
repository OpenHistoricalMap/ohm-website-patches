# ohm-website-patches

OHM customizations for [openstreetmap-website](https://github.com/openstreetmap/openstreetmap-website), kept separate from the fork history. Upstream code flows in untouched; every OHM change is an explicit patch, overlay, or removal ([issues#735](https://github.com/OpenHistoricalMap/issues/issues/735)).

The three repos live side by side; only this one needs a manual clone, the other two are created by the scripts:

```
.
├── ohm-website-patches/      # this repo
├── openstreetmap-website/    # upstream clone (update-base.sh creates it)
└── ohm-website-merged/       # generated tree (upstream + OHM applied)
```

## Upstream sync

Move OHM to a newer upstream commit and/or add functionality on top of it. OHM stays current by moving `UPSTREAM_BASE` forward, not by merging fork history.

```bash
# Step 1 — update the base (clones/fetches upstream by itself)
./scripts/update-base.sh              # latest upstream master, or: ./scripts/update-base.sh <sha>

# Step 2 — fix conflicts (only if reported): <<<<<<< markers in ../ohm-website-merged
# list the files that still have markers:
grep -rl '^<<<<<<<' ../ohm-website-merged --exclude-dir=node_modules --exclude-dir=.git

# Step 3 — run the site, test it, add your features in ../ohm-website-merged
docker compose up                     # → http://localhost:3000
# if package.json/Gemfile changed: regenerate lockfiles in the container
# (yarn install / bundle lock) — Step 4 copies them into overlays/ automatically

# Step 4 — save everything back into patches/ (unexported edits are lost on rebuild)
./scripts/export-patch.sh --all

# Step 5 — validate
./scripts/lint.sh
./scripts/test.sh

# Step 6 — commit patches/, overlays/ and UPSTREAM_BASE, then push
#          CI opens a PR in ohm-website-merged with the rendered tree

# Step 7 — merge that PR with "Create a merge commit" (never squash:
#          it would flatten the upstream history)
```


## Development workflow

Step by step, from a fresh merge to a pushed change. Stays on the current `UPSTREAM_BASE`; run `update-base.sh` first only if you also want to sync upstream.

```bash
# 1. Build the merged tree (fix any <<<<<<< markers it reports)
./scripts/merge.sh

# 2. Start the site in development
docker compose up    # → http://localhost:3000
# docker compose run  --service-ports web bash

# 3. Make your changes in ../ohm-website-merged and reload the browser —
#    Rails picks up edits on save (edit real files there, never .patch files).
#    Restart the container only after config/Gemfile changes.

# 4. Save your edits back into this repo
./scripts/export-patch.sh <file>      # one file, or --all for everything

# 5. Validate locally
./scripts/lint.sh
./scripts/test.sh                     # or a single test: ./scripts/test.sh test/...:123

# 6. Commit patches/ and overlays/, then push
```

On push, CI applies the patches on upstream and runs the full OSM test suite. On `main`, when `patches/`, `overlays/`, `REMOVALS` or `UPSTREAM_BASE` change, the publish workflow opens a pull request in `ohm-website-merged` with the rendered tree. Doc-only changes do not trigger it.

Only exported changes survive a re-merge — anything edited in `../ohm-website-merged` but not exported is lost the next time `merge.sh` runs.

If CSS/JS stop loading in dev (404s in the console) after running `test.sh`, the precompiled test assets went stale — clear them with `docker compose exec web rm -rf public/assets tmp/cache/assets` and reload.

## Layout

- `patches/` — one `.patch` per upstream file OHM modifies, mirroring the repo tree.
- `overlays/` — whole files OHM adds, plus modified binaries. `overlays/config/locales/overrides/en.yml` holds OHM strings; upstream `en.yml` is never patched.
- `REMOVALS` — upstream files OHM deletes.
- `UPSTREAM_BASE` — upstream commit the patches were last resolved against.
- `docker-compose.yml`, `dev.env`, `start.sh` — local development only; none of this reaches the merged tree or production (ohm-deploy has its own image and entrypoint).
- Lockfiles (`Gemfile.lock`, `yarn.lock`) live in `overlays/`. After changing `Gemfile`/`package.json`, regenerate them in the dev container (`bundle lock` / `yarn install`); `export-patch.sh --all` copies them into `overlays/` automatically. `config/locales/*` is never exported (Translatewiki).

## Scripts

| Script | What it does |
|---|---|
| `update-base.sh [ref]` | Moves OHM to a newer upstream commit: clones/fetches upstream, rebuilds the merged tree and updates `UPSTREAM_BASE`. No ref = latest master. |
| `merge.sh [ref]` | Builds a folder called `../ohm-website-merged` (worktree of `../openstreetmap-website`) with everything applied. Default ref: `UPSTREAM_BASE`. Conflicts stay as `<<<<<<< OSM upstream / OHM patch` markers. Needs `../openstreetmap-website` to exist and does not fetch. |
| `export-patch.sh <file>` \| `--all` | Saves edits in the merged tree back into `patches/`. `--all` exports everything modified and prunes obsolete patches. |
| `apply.sh <checkout>` | One-shot apply onto any checkout. For CI/Docker builds; exits non-zero on failure. |
| `test.sh [test file[:line]]` | Runs the OSM test suite (or a single test) against the merged tree in Docker, mirroring CI. `PREPARE=1` recompiles assets. |
| `lint.sh` | Runs the same linters as the merged repo's Lint workflow: rubocop, erb_lint, herb, eslint. |
