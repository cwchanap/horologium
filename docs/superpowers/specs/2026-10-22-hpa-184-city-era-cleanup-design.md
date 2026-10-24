# HPA-184 — City-Era Repository Cleanup Design

- Date: 2026-10-22
- Status: Implemented
- Linear: HPA-184 — [Cleanup] Remove city-era assets, scripts, and stale docs
- Baseline: `main` at `15fd4c0887a18168dd2a7366da2637c103f9f74e`

## Problem

Horologium is now a mining-only Flutter game, but the repository still carries city-era artifacts that look current enough to mislead future work:

- old building/resource image roots remain in the Flutter asset manifest even though active mining code does not load them;
- the unimported Flame-era `lib/constants/assets_path.dart` still lists the retired `building/` and `resource/` paths, alongside an obsolete terrain/building-resource preprocessing `scripts/` directory;
- city-builder PRD, terrain guides, and production-chain documents remain under `docs/`;
- `README.md` duplicates detailed economy/save facts and is already stale after the storage-pacing and Ceres work;
- `CLAUDE.md` currently has to warn contributors not to revive production-chain documents that should simply no longer be present in the working tree.

This is repository hygiene, not a gameplay change.

## Goals

- Remove city-era assets that are still bundled only because `pubspec.yaml` lists them, and the dead `lib/constants/assets_path.dart` constants.
- Remove obsolete non-mining preprocessing scripts.
- Delete stale city/terrain/production-chain documentation that no longer describes the active product.
- Keep the durable "do not revive city production architecture" rule in `CLAUDE.md`, with git history as the historical source.
- Make `README.md` stable and descriptive rather than a second copy of economy/save contracts.
- Preserve all mining behavior, state, content, tests, and current assets.
- Deliver planning and cleanup in one PR.

## Non-goals

This PR does not:

- change `lib/` except deleting the unimported `lib/constants/assets_path.dart`, or change any `test/` source/behavior;
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
- `lib/constants/assets_path.dart` defines only Flame-prefixed city building/resource paths; repository search finds no active `lib/` or `test/` imports or uses of its `flutterAssetPath` helper.
- The four named script files and all ten named stale docs currently exist.
- `CLAUDE.md` already labels the city production-chain documents as historical.
- `README.md` still describes pre-Ceres/pre-HPA-401 details, including the old site count, Mars reward, Logistics offline-cap behavior, and a fresh-to-Mars journey.
- The active `docs/audio-assets.md` is linked only from that README's detailed economy/audio prose, so the replacement must retain one audio-doc link.
- `test/mining/presentation/mining_visuals_test.dart` already resolves every authored mining visual through `rootBundle`, including the font manifest; reuse it rather than adding a cleanup-specific test.

The tracked deletion list is supported by current repository evidence. The review also found local **ignored** `original/` art PNGs and `scripts/__pycache__/`, which do **not** belong to the Git commit and cannot be restored from its history. This PR must delete **tracked files only**. Local ignored/generated sources remain untouched for the owner to inspect or remove separately.

## Design decisions

### 1. Tracked-only removal protects uncommitted source images

The relevant tracked paths have been surveyed. Avoid any local `rm -rf` or ignored-file inventory as a merge gate. Remove only files registered in Git:

```sh
git rm -r -q -- \
  assets/images/building assets/images/resource assets/images/background \
  scripts lib/constants/assets_path.dart
```

This deletes the tracked background placeholder, retired asset images and scripts, and dead Flame constants file. Git leaves ignored `original/` images, `.DS_Store`, and `scripts/__pycache__/` untouched. Those local-only files will no longer be bundled after the manifest edit, and deciding whether to discard their source art is the owner's separate local-cleanup choice.

Do not promise that merging this PR removes ignored files from any contributor's checkout. The PR description may note that owners can manually remove the four directories locally **if they no longer want the source PNGs**.

### 2. Asset cleanup is manifest cleanup too

Delete the **tracked** retired building/resource image roots and remove their two Flutter asset-directory entries from `pubspec.yaml`. Also delete `lib/constants/assets_path.dart`, which is unimported and contains exclusively deleted Flame-era building/resource paths. There is no replacement asset-path helper: live mining assets are already defined in `lib/mining/presentation/mining_visuals.dart` and `lib/mining/mining_content.dart`.

Do not touch any path under `assets/images/mining/`, `assets/audio/`, or `assets/fonts/`.

The tracked background placeholder is deleted with the old toolchain; leave any ignored `background/original/` source images intact.

### 3. Delete obsolete scripts as one retired toolchain

The named scripts form one obsolete preprocessing toolchain:

- `scripts/process_terrain_assets.py`
- `scripts/finalize_generated_terrain_asset.py`
- `scripts/resize_images.py`
- `scripts/requirements.txt`

Remove the tracked scripts through the same `git rm` command. Leave any ignored `__pycache__/` local files intact rather than bundling their disposal into a repository PR.

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

> Do not revive the city-era `Building`/`Resources`/recipe/worker/city-tick architecture in mining; its docs were removed and remain in git history.

Do not add links to deleted files.

`AGENTS.md` is a symlink to `CLAUDE.md`, so no second edit is needed.

### 6. README becomes an entry point, not a second architecture specification

Keep:

- the short product summary;
- the active ownership diagram **without** the ownership prose below it, which duplicates `CLAUDE.md`;
- Run, test, and build.

Remove the `Local agent commands` section: it documents the
`.opencode/command` → `.claude/commands` symlink, and neither path is
Git-tracked, so the section points readers at files absent from a fresh clone.

Replace the detailed state/economy/persistence and asset/resource sections with two stable ideas:

1. Horologium is an authored multi-planet mining game where the player merges/deploys rigs, sells cargo, researches technology, and unlocks the next frontier.
2. `CLAUDE.md` is the authoritative architecture, save-contract, and economy reference.

Retain the sole README pointer to the live audio source/playback documentation: `Audio sources and playback notes: [docs/audio-assets.md](docs/audio-assets.md).`

Do **not** put planet counts, site counts, reward values, storage durations, offline caps, or save root-key inventories in README. HPA-184 explicitly wants README free of numeric facts that can drift.

Update the integration-test description from "fresh-to-Mars" to the current final frontier without hard-coding another count.

### 7. No test edits are planned

No runtime behavior changes, so no test source should need modification. After removing the dead asset constants and updating the asset manifest, run `flutter analyze` and the existing `flutter test test/mining/presentation/mining_visuals_test.dart` asset bundle check before the full gates.

If a test or build fails because a deleted asset/script/doc was actually consumed, restore that item and record the live dependency rather than rewriting behavior to make the cleanup pass.

## Active-reference checks

Before deletion, use active-surface searches to prove expected ownership:

```sh
rg -n "(building|resource|background)/|scripts/" \
  lib test pubspec.yaml .github README.md CLAUDE.md

rg -n "PARALLAX_TERRAIN_GUIDE|TERRAIN_ASSETS_GUIDE|TERRAIN_SYSTEM_SUMMARY|terrain_camera_alignment|terrain_grouping_todo|features_prd|production_chains|production_chain_recommendations|2026-05-03-production-chain" \
  lib test README.md CLAUDE.md pubspec.yaml .github
```

After cleanup, both commands should return no active references to deleted paths. The first command still matches two comments containing `background/resume` — `test/game/audio_manager_test.dart` and `lib/mining/presentation/animated_mining_grid_visual_layer.dart` — which refer to app lifecycle, not the deleted `assets/images/background/` root; those are expected.

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

- deletions only under the explicitly approved tracked legacy asset/script/doc paths plus `lib/constants/assets_path.dart` (local ignored files are untouched and not represented in the Git diff);
- edits to `pubspec.yaml`, `CLAUDE.md`, and `README.md`;
- this design and implementation plan;
- no `lib/` change except deletion of `lib/constants/assets_path.dart`; no `test/`, dependency, platform, or CI changes.

## Delivery

This draft is the single HPA-184 delivery PR opened early for planning review. Implementation continues on the same branch/PR after review; do not open a second implementation PR.
