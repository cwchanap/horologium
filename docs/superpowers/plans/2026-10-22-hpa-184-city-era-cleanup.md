# HPA-184 — City-Era Cleanup Implementation Plan

- Date: 2026-10-22
- Linear: HPA-184 — [Cleanup] Remove city-era assets, scripts, and stale docs
- Design: `docs/superpowers/specs/2026-10-22-hpa-184-city-era-cleanup-design.md`
- Baseline: `main` at `15fd4c0887a18168dd2a7366da2637c103f9f74e`

## Delivery rule

One ticket = one PR.

This draft PR is the implementation PR opened early for planning review. After review, continue the cleanup on this same branch; do not open a second PR.

No image generation or SFX work is required.

## Task 1 — Reference gate

Before deleting anything, reuse the existing reference searches, widened to find Flame-relative `building/` and `resource/` paths:

```sh
rg -n "(building|resource|background)/|scripts/" \
  lib test pubspec.yaml .github README.md CLAUDE.md

rg -n "PARALLAX_TERRAIN_GUIDE|TERRAIN_ASSETS_GUIDE|TERRAIN_SYSTEM_SUMMARY|terrain_camera_alignment|terrain_grouping_todo|features_prd|production_chains|production_chain_recommendations|2026-05-03-production-chain" \
  lib test README.md CLAUDE.md pubspec.yaml .github
```

Expected old references: retired image roots in `pubspec.yaml`, and relative `building/` / `resource/` constants in `lib/constants/assets_path.dart`. Repository search finds no active imports of that Dart file or use of its `flutterAssetPath` helper. The only active production-chain-document reference is the historical guardrail in `CLAUDE.md`.

No ignored-file inventory is a PR prerequisite: the tracked deletion is fixed, and ignored source art on the owner's checkout must be left alone.

## Task 2 — Remove only tracked unused assets, scripts, and Flame constants

```sh
git rm -r -q -- \
  assets/images/building assets/images/resource assets/images/background \
  scripts lib/constants/assets_path.dart
```

This deletes only Git-tracked legacy files. The dead `lib/constants/assets_path.dart` is unimported and contains exclusively the retiring `building/` / `resource/` paths and Flame-era helper. There is no new asset-path registry or replacement helper.

Leave ignored `original/` PNGs, `.DS_Store`, and `scripts/__pycache__/` untouched. The PR cannot remove ignored local files or restore them from git history; after merge, the owner may separately remove the four local directories if their generated/source art is no longer needed.

Edit `pubspec.yaml`:

- remove `assets/images/building/`;
- remove `assets/images/resource/`;
- leave every `assets/images/mining/`, audio, and font entry unchanged.

Do not introduce replacement scripts or asset tooling. Leave `.gitignore`'s generic `assets/**/original` protection unchanged: it is not an active-reference link to city-era assets and may protect future local source art from accidental commits.

Focused check:

```sh
rg -n "(building|resource|background)/|scripts/" \
  lib test pubspec.yaml .github README.md CLAUDE.md
```

Expected: no matches to deleted paths.

Reuse the existing mining-bundle proof immediately after the manifest and dead-file edit:

```sh
flutter analyze --fatal-infos
flutter test test/mining/presentation/mining_visuals_test.dart
```

Its host `rootBundle` test loads all authored mining visuals and fonts; do not add another asset test.

## Task 3 — Delete stale city/terrain/production-chain docs

Delete exactly:

```text
docs/PARALLAX_TERRAIN_GUIDE.md
docs/TERRAIN_ASSETS_GUIDE.md
docs/TERRAIN_SYSTEM_SUMMARY.md
docs/terrain_camera_alignment.md
docs/terrain_grouping_todo.md
docs/features_prd.md
docs/production_chains.md
docs/production_chain_recommendations.md
docs/superpowers/specs/2026-05-03-production-chain-expansion-design.md
docs/superpowers/plans/2026-05-03-production-chain-expansion.md
```

Do not delete retained mining specs/plans that mention those documents as historical context.

Edit `CLAUDE.md` so its durable rule no longer names deleted working-tree files:

```text
Do not revive the city-era Building/Resources/recipe/worker/city-tick
architecture in mining; its docs were removed and remain in git history.
```

No `AGENTS.md` edit is needed because it is a repository-relative symlink to `CLAUDE.md`.

Focused check:

```sh
rg -n "PARALLAX_TERRAIN_GUIDE|TERRAIN_ASSETS_GUIDE|TERRAIN_SYSTEM_SUMMARY|terrain_camera_alignment|terrain_grouping_todo|features_prd|production_chains|production_chain_recommendations|2026-05-03-production-chain" \
  lib test README.md CLAUDE.md pubspec.yaml .github
```

Expected: no active-surface references.

## Task 4 — Make README stable instead of numerically authoritative

Edit `README.md`.

Keep:

- short Horologium summary;
- active ownership diagram (but **remove** its prose ownership recap beneath it, because `CLAUDE.md` is authoritative);
- Run, test, and build;
- Local agent commands.

Remove the detailed `State, economy, and persistence` and `Assets and resource identity` sections.

Replace them with concise non-numeric product/reference copy:

- Horologium uses authored planets and mine sites; players merge/deploy rigs, sell cargo, research technology, and unlock the next frontier.
- `CLAUDE.md` is the authoritative architecture, save-contract, and economy reference.
- `Audio sources and playback notes: [docs/audio-assets.md](docs/audio-assets.md).` Keep this live documentation link from the deleted section; it is currently the only README pointer to the audio source/target details.

Do not retain planet/site counts, rewards, storage windows, offline caps, or root-key inventories in README.

Update the integration journey wording from the stale fresh-to-Mars text to the current final-frontier wording. Prefer wording that does not need another edit when a later planet ships, e.g. "the public fresh-to-final-frontier journey."

## Task 5 — Diff audit

Inspect:

```sh
git diff --name-status main...HEAD
git diff --check
```

Expected changed surface:

Planning:

- `docs/superpowers/specs/2026-10-22-hpa-184-city-era-cleanup-design.md`
- `docs/superpowers/plans/2026-10-22-hpa-184-city-era-cleanup.md`

Implementation:

- deleted **tracked** legacy building/resource/background assets, `scripts/`, and `lib/constants/assets_path.dart`;
- deleted the ten explicitly listed stale docs;
- edited `pubspec.yaml`, `CLAUDE.md`, and `README.md`;
- ignored local source images and caches remain outside the Git diff.

Unexpected and should stop the task:

- any `lib/` change **except deleting** `lib/constants/assets_path.dart`;
- any `test/` change;
- dependency/version change;
- native platform change;
- CI change;
- mining asset deletion.

## Task 6 — Repository gates

Run:

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

No test-source changes are expected.

If a test/build fails because a deleted item was actually consumed:

1. restore that item;
2. identify the live owner;
3. note the exception in the PR;
4. do not rewrite runtime behavior merely to preserve the planned deletion.

## Completion criteria

- app manifest no longer bundles the city-era building/resource roots;
- obsolete Git-tracked non-mining scripts and the unimported `lib/constants/assets_path.dart` are gone;
- stale city/terrain/production-chain guidance is gone from the working tree;
- `CLAUDE.md` retains the durable anti-revival rule without dead links;
- README no longer duplicates volatile economy/save numbers;
- active-surface searches contain no deleted-path references;
- no runtime/test/content/save behavior changes;
- full repository gates pass;
- implementation remains on this same PR.
