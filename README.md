# ohm-website-patches

OHM customizations for [openstreetmap-website](https://github.com/openstreetmap/openstreetmap-website), kept separate from the fork history. Upstream code flows in untouched; every OHM change is an explicit patch, overlay, or removal ([issues#735](https://github.com/OpenHistoricalMap/issues/issues/735)).

Everything lives in this single repo; the scripts create two git-ignored folders inside it:

```
ohm-website-patches/
├── patches/, overlays/, ...  # the OHM customizations (tracked)
├── upstream/                 # openstreetmap-website clone (git-ignored, sync.sh creates it)
└── merged/                   # generated tree, upstream + OHM applied (git-ignored) — develop here
```

## Before you start

You need `git`, `node` (for the `npm run` shortcuts) and Docker with Compose v2. Everything else — Ruby, Postgres, the linters — runs inside containers, so there is nothing to install on your machine.

The first run clones the upstream repository and builds the images, and the first `npm run dev` downloads a seed database and loads it. Both take several minutes; later runs reuse them.

```bash
git clone https://github.com/OpenHistoricalMap/ohm-website-patches.git
cd ohm-website-patches
npm run build                 # clones upstream/ and builds merged/
npm run dev                   # → http://localhost:3000
```

## Upstream sync

Move OHM to a newer upstream commit and/or add functionality on top of it. OHM stays current by moving `UPSTREAM_BASE` forward, not by merging fork history.

```bash
# Step 1 — update the base (clones/fetches upstream by itself)
npm run sync                  # latest upstream master, or: npm run sync -- <sha>

# Step 2 — fix conflicts (only if reported): <<<<<<< markers in merged/
npm run conflicts             # lists the files that still have markers

# Step 3 — run the site, test it, add your features in merged/
npm run dev                   # → http://localhost:3000
# if package.json/Gemfile changed: regenerate lockfiles in the container
# (yarn install / bundle lock) — Step 4 copies them into overlays/ automatically

# Step 4 — save everything back into patches/ (unexported edits are lost on rebuild)
npm run export

# Step 5 — validate
npm run check                 # lint + full test suite

# Step 6 — commit patches/, overlays/ and UPSTREAM_BASE, then push
#          CI opens a PR in ohm-website-merged with the rendered tree

# Step 7 — merge that PR with "Create a merge commit" (never squash:
#          it would flatten the upstream history)
```


## Development workflow

Step by step, from a fresh merge to a pushed change. Stays on the current `UPSTREAM_BASE`; run `npm run sync` first only if you also want to move upstream.

```bash
# 1. Build the merged tree (fix any <<<<<<< markers it reports)
npm run build

# 2. Start the site in development
npm run dev                           # → http://localhost:3000
# docker compose run --service-ports web bash

# 3. Make your changes in merged/ and reload the browser —
#    Rails picks up edits on save (edit real files there, never .patch files).
#    Restart the container only after config/Gemfile changes.

# 4. Save your edits back into this repo
npm run export                        # all modified files
./scripts/export.sh <file>            # or just one
npm run export:check                  # anything still missing?

# 5. Validate locally
npm run check                         # unexported edits + lint + full suite
npm test -- test/system/foo_test.rb:12   # or a single test

# 6. Commit patches/ and overlays/, then push
```

On push, CI applies the patches on upstream and runs the full OSM test suite. On `main`, when `patches/`, `overlays/`, `REMOVALS` or `UPSTREAM_BASE` change, the publish workflow opens a pull request in `ohm-website-merged` with the rendered tree. Doc-only changes do not trigger it.

Only exported changes survive a rebuild — anything edited in `merged/` but not exported is lost the next time `build.sh` runs. `npm run export:check` tells you what is still missing. Files under `overlays/` are the exception: `npm run export` does not copy them back (only the lockfiles), so edit them in `overlays/` or copy them by hand.

If CSS/JS stop loading in dev (404s in the console) after running `test.sh`, the precompiled test assets went stale — clear them with `docker compose exec web rm -rf public/assets tmp/cache/assets` and reload.

## Layout

- `patches/` — one `.patch` per upstream file OHM modifies, mirroring the repo tree.
- `overlays/` — whole files OHM adds, plus modified binaries. `overlays/config/locales/overrides/en.yml` holds OHM strings; upstream `en.yml` is never patched.
- `REMOVALS` — upstream files OHM deletes.
- `UPSTREAM_BASE` — upstream commit the patches were last resolved against.
- `docker-compose.yml`, `dev.env`, `start.sh` — local development only; none of this reaches the merged tree or production (ohm-deploy has its own image and entrypoint).
- Lockfiles (`Gemfile.lock`, `yarn.lock`) live in `overlays/`. After changing `Gemfile`/`package.json`, regenerate them in the dev container (`bundle lock` / `yarn install`); `export.sh --all` copies them into `overlays/` automatically. `config/locales/*` is never exported (Translatewiki).

## Scripts

Everyday commands. Pass arguments after `--`, e.g. `npm run sync -- 49598db`.

| Command | What it does |
|---|---|
| `npm run sync [-- <ref>]` | Move to a newer upstream commit and rebuild `merged/`. No ref = latest master. |
| `npm run build` | Rebuild `merged/` on the current `UPSTREAM_BASE`. |
| `npm run dev` | Start the site at http://localhost:3000. |
| `npm run conflicts` | List files in `merged/` that still have `<<<<<<<` markers. |
| `npm run export` | Save every edit in `merged/` back into `patches/` and `overlays/`. |
| `npm run export:check` | List edits in `merged/` that are not saved yet. Changes nothing, exits 1 if it finds any. |
| `npm run check` | Check for unexported edits, then run the linters and the full test suite. |
| `npm test [-- <file>[:line]]` | Run the test suite, or a single test. |
| `npm run reset` | Wipe the dev database and containers. |

Each one wraps a script in `scripts/`, which you can also call directly:

| Script | What it does |
|---|---|
| `sync.sh [ref]` | Moves OHM to a newer upstream commit: clones/fetches upstream, rebuilds `merged/` and updates `UPSTREAM_BASE`. No ref = latest master. |
| `build.sh [ref]` | Builds `merged/` (worktree of `upstream/`) with everything applied. Default ref: `UPSTREAM_BASE`. Conflicts stay as `<<<<<<< OSM upstream / OHM patch` markers. Clones `upstream/` on the first run and fetches only when the ref is missing. |
| `export.sh <file>` \| `--all` \| `--check` | Saves edits in `merged/` back into `patches/`. `--all` exports everything modified and deletes obsolete patches. `--check` only reports what is missing. |
| `apply.sh <checkout>` | One-shot apply onto any checkout. Used by CI; exits non-zero on failure. |
| `test.sh [test file[:line]]` | Runs the OSM test suite (or a single test) against `merged/` in Docker, mirroring CI. `PREPARE=1` recompiles assets. |
| `lint.sh` | Runs the same linters as the merged repo's Lint workflow: rubocop, erb_lint, herb, eslint. |
