# HPA-184 City-Era Cleanup Plan

- Date: 2026-10-22
- Linear: [HPA-184](https://linear.app/cwchanap/issue/HPA-184/cleanup-remove-city-era-assets-scripts-and-stale-docs)
- Baseline: `main` at `15fd4c0`

## Why

The game pivoted from a city builder to a mining idle game in August (HPA-630, HPA-636). Some city-era files survived the cutover:

- `assets/images/building/` (9 PNGs) and `assets/images/resource/` (18 PNGs) are still listed in `pubspec.yaml`, so every build bundles them, but nothing in `lib/` or `test/` loads them.
- `assets/images/background/` holds only a `.keep` placeholder.
- `scripts/` holds the terrain asset pipeline (`process_terrain_assets.py`, `finalize_generated_terrain_asset.py`), a building/resource resizer (`resize_images.py`, default `asset_type="building"`), and their `requirements.txt` (Pillow). None of them targets `assets/images/mining/`.
- `docs/` holds five terrain guides and the city-builder PRD (`features_prd.md`: population, happiness, buildings), plus the two production-chain docs that CLAUDE.md already calls historical.
- `README.md` describes the economy as it was before HPA-401 and HPA-403 (nine sites, a 25,000 Mars reward, a Logistics offline cap, a fresh-to-Mars journey).

No spec: this is deletion and one README refresh. No behavior, save, or content change.

## Delivery rule

One ticket = one PR. This plan lands first on the draft PR; the cleanup lands on the same PR after review.

## Task 1: Delete unused assets and scripts

- `git rm -r assets/images/building assets/images/resource`, and `git rm assets/images/background/.keep` (the directory holds only that placeholder).
- `pubspec.yaml`: drop `- assets/images/building/` and `- assets/images/resource/`.
- `git rm -r scripts` (all four files; the `scripts/` directory goes away).
- Check: `rg -n "images/building|images/resource|images/background|scripts/" lib test pubspec.yaml .github` returns nothing.

## Task 2: Delete stale docs

- `git rm docs/PARALLAX_TERRAIN_GUIDE.md docs/TERRAIN_ASSETS_GUIDE.md docs/TERRAIN_SYSTEM_SUMMARY.md docs/terrain_camera_alignment.md docs/terrain_grouping_todo.md docs/features_prd.md`.
- `git rm docs/production_chains.md docs/production_chain_recommendations.md docs/superpowers/specs/2026-05-03-production-chain-expansion-design.md docs/superpowers/plans/2026-05-03-production-chain-expansion.md`.
- `CLAUDE.md`: replace the "The city-era `docs/production_chains.md`, …" sentence with "Do not revive the city-era `Building`/`Resources`/recipe/worker/city-tick architecture in mining; its docs were removed in HPA-184 and remain in git history."
- Leave the merged mining specs and plans alone, including those that mention the deleted files in passing (for example HPA-636's cutover docs); they are a record of what happened.

## Task 3: Refresh the README

Shorten `README.md` so it cannot drift again:

- keep the one-paragraph game summary, the ownership diagram, and "Run, test, and build";
- replace "State, economy, and persistence" and "Assets and resource identity" with two sentences: what the game is (four planets, three sites each, merge-and-deploy rigs, sell cargo, research, unlock the next frontier) and "`CLAUDE.md` is the authoritative architecture, save-contract, and economy reference";
- fix "the public fresh-to-Mars journey" to "the public fresh-to-Ceres journey";
- keep the "Local agent commands" section.

## Task 4: Gates

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

No test changes are expected. If a test fails on a deleted path, that path was used after all: restore it and note it in the PR.

## Expected changed paths

Planning (this draft PR as opened):

- `docs/superpowers/plans/2026-10-22-hpa-184-city-era-cleanup.md`

Cleanup (same PR, after review):

- deleted: `assets/images/building/`, `assets/images/resource/`, `assets/images/background/.keep`, `scripts/`, the six city-era docs, the two production-chain docs, and the 2026-05-03 production-chain spec and plan
- `pubspec.yaml`, `CLAUDE.md`, `README.md`
