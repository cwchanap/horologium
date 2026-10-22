# HPA-184 — City-Era Repository Cleanup Design

- Date: 2026-10-22
- Status: Proposed
- Linear: HPA-184 — [Cleanup] Remove city-era assets, scripts, and stale docs
- Baseline: `main` at `15fd4c0887a18168dd2a7366da2637c103f9f74e`

## Problem

Horologium is now a mining-only Flutter game, but the repository still carries city-era artifacts that look current enough to mislead future work:

- old building/resource image roots remain in the Flutter asset manifest even though active mining code does not load them;
- an obsolete terrain/building-resource preprocessing `scripts/` directory remains even though it does not target the mining asset families;
- city-builder PRD, terrain guides, and production-chain documents remain under `docs/`;
- `README.md` duplicates detailed economy/save facts and is already stale after the storage-pacing and Ceres work;
- `CLAUDE.md` currently has to warn contributors not to revive production-chain documents that should simply no longer be present in the working tree.

This is repository hygiene, not a gameplay change.

## Goals

- Remove city-era assets that are still bundled only because `pubspec.yaml` lists them.
- Remove obsolete non-mining preprocessing scripts.
- Delete stale city/terrain/production-chain documentation that no longer describes the active product.
- Keep the durable "do not revive city production architecture" rule in `CLAUDE.md`, with git history as the historical source.
- Make `README.md` stable and descriptive rather than a second copy of economy/save contracts.
- Preserve all mining behavior, state, content, tests, and current assets.
- Deliver planning and cleanup in one PR.

## Non-goals

This PR does not:

- change `lib/` or `test/` behavior;
- change mining content, pacing, save schema, persistence, or balance;
- regenerate, replace, optimize, or add mining art;
- alter audio, fonts, native platform code, dependencies, or CI behavior;
- delete merged mining specs/plans merely because they mention old files historically;
- perform a broad documentation rewrite beyond `README.md` and the one durable `CLAUDE.md` rule.

No image generation or SFX work is needed.

## Reuse / deletion survey

Current `main` confirms:

- `pubspec.yaml` still manifests `assets/images/building/` and `assets/images/resource/`.
- Repository search finds `assets/images/building/` in the stale city PRD and manifest, not active mining code.
- Repository search finds `assets/images/resource/` in the manifest, not active mining code.
- `scripts/process_terrain_assets.py` points at retired `assets/images/background/` paths.
- The four named script files and all ten named stale docs currently exist.
- `CLAUDE.md` already labels the city production-chain documents as historical.
- `README.md` still describes pre-Ceres/pre-HPA-401 details, including the old site count, Mars reward, Logistics offline-cap behavior, and a fresh-to-Mars journey.

The deletion list is therefore supported by current repository evidence, but implementation must still inventory directories before using recursive deletion.

## Design decisions

### 1. Inventory before recursive deletion

Do not trust historical file counts as a deletion contract.

Before deleting, run:

```sh
git ls-files assets/images/building assets/images/resource assets/images/background scripts
```

Expected intent:

- every tracked file under `assets/images/building/` is city-era;
- every tracked file under `assets/images/resource/` is city-era;
- `assets/images/background/` contains only the placeholder being removed;
- `scripts/` contains only the retired terrain/building-resource tooling.

If an unexpected file is active or mining-related, stop and narrow the deletion instead of deleting the whole directory.

This keeps HPA-184 deletion-first without turning a stale ticket inventory into an unsafe command.

### 2. Asset cleanup is manifest cleanup too

Delete the retired building/resource image roots and remove their two Flutter asset-directory entries from `pubspec.yaml`.

Do not touch any path under `assets/images/mining/`, `assets/audio/`, or `assets/fonts/`.

The background placeholder may be removed because the old script is its only current repository consumer and the folder carries no active asset.

### 3. Delete obsolete scripts as one retired toolchain

The named scripts form one obsolete preprocessing toolchain:

- `scripts/process_terrain_assets.py`
- `scripts/finalize_generated_terrain_asset.py`
- `scripts/resize_images.py`
- `scripts/requirements.txt`

After the inventory gate confirms there are no other live scripts in that directory, remove the directory.

Do not replace the scripts with a new asset pipeline. Mining art already has its own authored workflow and this ticket is cleanup only.

### 4. Delete stale docs, preserve historical implementation records

Delete the explicitly scoped stale documents:

- terrain/asset guides:
  - `docs/PARALLAX_TERRAIN_GUIDE.md`
  - `docs/TERRAIN_ASSETS_GUIDE.md`
  - `docs/TERRAIN_SYSTEM_SUMMARY.md`
  - `docs/terrain_camera_alignment.md`
  - `docs/terrain_grouping_todo.md`
- city product documentation:
  - `docs/features_prd.md`
- retired production-chain documentation:
  - `docs/production_chains.md`
  - `docs/production_chain_recommendations.md`
  - `docs/superpowers/specs/2026-05-03-production-chain-expansion-design.md`
  - `docs/superpowers/plans/2026-05-03-production-chain-expansion.md`

Merged mining specs/plans remain even if they mention these paths as part of historical cutover work. They document what happened and are not active product guidance.

### 5. Move the durable retirement rule into CLAUDE.md without dead links

Replace the current paragraph that names the soon-to-be-deleted production-chain files with one durable rule:

> Do not revive the city-era `Building`/`Resources`/recipe/worker/city-tick architecture in mining; its docs were removed by HPA-184 and remain in git history.

Do not add links to deleted files.

`AGENTS.md` is a symlink to `CLAUDE.md`, so no second edit is needed.

### 6. README becomes an entry point, not a second architecture specification

Keep:

- the short product summary;
- the active ownership diagram;
- Run, test, and build;
- Local agent commands.

Replace the detailed state/economy/persistence and asset/resource sections with two stable ideas:

1. Horologium is an authored multi-planet mining game where the player merges/deploys rigs, sells cargo, researches technology, and unlocks the next frontier.
2. `CLAUDE.md` is the authoritative architecture, save-contract, and economy reference.

Do **not** put planet counts, site counts, reward values, storage durations, offline caps, or save root-key inventories in README. HPA-184 explicitly wants README free of numeric facts that can drift.

Update the integration-test description from "fresh-to-Mars" to the current final frontier without hard-coding another count.

### 7. No test edits are planned

No runtime behavior changes, so no test source should need modification.

If a test or build fails because a deleted asset/script/doc was actually consumed, restore that item and record the live dependency rather than rewriting behavior to make the cleanup pass.

## Active-reference checks

Before deletion, use active-surface searches to prove expected ownership:

```sh
rg -n "images/building|images/resource|images/background|scripts/" \
  lib test pubspec.yaml .github README.md CLAUDE.md

rg -n "PARALLAX_TERRAIN_GUIDE|TERRAIN_ASSETS_GUIDE|TERRAIN_SYSTEM_SUMMARY|terrain_camera_alignment|terrain_grouping_todo|features_prd|production_chains|production_chain_recommendations|2026-05-03-production-chain" \
  lib test README.md CLAUDE.md pubspec.yaml .github
```

After cleanup, both commands should return no active references to deleted paths.

Historical mentions inside retained merged specs/plans are intentionally outside these checks.

## Verification

Run the repository gates after the deletions and documentation edits:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
git diff --check
```

Also inspect:

```sh
git diff --name-status main...HEAD
```

Expected shape:

- deletions only under the explicitly approved legacy asset/script/doc paths;
- edits to `pubspec.yaml`, `CLAUDE.md`, and `README.md`;
- this design and implementation plan;
- no `lib/`, `test/`, dependency, platform, or CI changes.

## Delivery

This draft is the single HPA-184 delivery PR opened early for planning review. Implementation continues on the same branch/PR after review; do not open a second implementation PR.
