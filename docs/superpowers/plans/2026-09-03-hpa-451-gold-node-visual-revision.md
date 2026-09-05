# HPA-451 Gold Node Visual Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the oversized procedural Landing Basin hit effect with approved staged gold-node art, resource-local idle/hit/exhaust animation frames, and the existing articulated robot-arm motion.

**Architecture:** Reuse the existing site `cargo / capacity` progress already calculated by `_MineNodeButton`; pass it into `LandingBasinMiningNodeVisual` and choose one of four gold stages without changing simulation, controller, view, or persistence contracts. Keep the existing one-second impact sequence and articulated rig layers, but render gold-specific PNG frames in the node bounds instead of separate procedural particles. This addendum supersedes only the original HPA-451 constraints that required N1-N4 deposit variants and prohibited sprite sheets.

**Tech Stack:** Flutter/Dart, `AnimationController`, PNG assets, Flutter widget tests, existing Linux golden workflow.

**Spec:** `/Users/chanwaichan/.codex/attachments/72f6ca5b-c457-4b81-be62-5f34250218ed/pasted-text.txt`

## Global Constraints

- Preserve `MiningController`, `MiningSimulation`, `MiningSaveRepository`, `MineSiteView`, save schema, economy, progression, and shell impact ownership unchanged.
- Animate only `MiningSiteId.landingBasin`; all other sites keep their current presentation.
- `MediaQuery.disableAnimations` remains the source of truth; reduced motion shows a static stage plate and a stationary arm.
- The resource image owns the gold glow, chips, sparks, dust, and depletion change; do not retain a second procedural impact layer.
- The robot chassis stays fixed; only the authored arm layer moves.
- Stage thresholds are: S1 for `progress < .25`, S2 for `.25 <= progress < .60`, S3 for `.60 <= progress < .90`, and S4 for `progress >= .90`.
- S1 remains byte-identical to `assets/images/mining/nodes/gold.png`.
- Every frame is a 512×512 transparent PNG in the approved locked camera and footprint. Horizontal strips use 512px cells with no gutters.
- Idle is four S1 frames at 8fps; hit is three S1 frames at 12fps; exhaust is four frames from exact S3 to exact S4 at 10fps.
- Add no package, registry, state owner, save field, random selection, audio, haptic, event bus, Rive, Lottie, Flame, or physics layer.

---

### Task 1: Publish the Approved Four-Stage Gold Plates

**Files:**
- Create: `assets/images/mining/nodes/node-gold-s1.png`
- Create: `assets/images/mining/nodes/node-gold-s2.png`
- Create: `assets/images/mining/nodes/node-gold-s3.png`
- Create: `assets/images/mining/nodes/node-gold-s4.png`
- Modify: `lib/mining/presentation/mining_visuals.dart`
- Modify: `test/mining/presentation/mining_visuals_test.dart`

**Interfaces:**
- Consumes: the four user-approved, already-generated 512×512 RGBA files in the worktree.
- Produces: `MiningVisuals.goldNodeStageAsset(int stage)` returning the closed S1-S4 paths.

- [ ] **Step 1: Add the failing closed-path test**

Add this table-driven assertion to `test/mining/presentation/mining_visuals_test.dart`:

```dart
for (final entry in const {
  1: 'assets/images/mining/nodes/node-gold-s1.png',
  2: 'assets/images/mining/nodes/node-gold-s2.png',
  3: 'assets/images/mining/nodes/node-gold-s3.png',
  4: 'assets/images/mining/nodes/node-gold-s4.png',
}.entries) {
  expect(MiningVisuals.goldNodeStageAsset(entry.key), entry.value);
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: compile failure because `goldNodeStageAsset` does not exist.

- [ ] **Step 3: Add the minimal closed mapping**

Add to `MiningVisuals`:

```dart
static String goldNodeStageAsset(int stage) => switch (stage) {
  1 || 2 || 3 || 4 =>
    'assets/images/mining/nodes/node-gold-s$stage.png',
  _ => throw RangeError.range(stage, 1, 4, 'stage'),
};
```

- [ ] **Step 4: Prove S1 identity and bundle availability**

Load all four paths in the existing host-only bundle test, then run:

```sh
shasum -a 256 assets/images/mining/nodes/gold.png assets/images/mining/nodes/node-gold-s1.png
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: identical hashes and a passing test.

- [ ] **Step 5: Commit the approved stage seam**

```sh
git add assets/images/mining/nodes/node-gold-s*.png lib/mining/presentation/mining_visuals.dart test/mining/presentation/mining_visuals_test.dart
git commit -m "feat(mining): add staged gold node art"
```

---

### Task 2: Replace Procedural Impact Effects With Gold Frame Animation

**Files:**
- Create: `assets/images/mining/nodes/node-gold-idle-01.png` through `node-gold-idle-04.png`
- Create: `assets/images/mining/nodes/node-gold-hit-01.png` through `node-gold-hit-03.png`
- Create: `assets/images/mining/nodes/node-gold-exhaust-01.png` through `node-gold-exhaust-04.png`
- Create: `assets/images/mining/nodes/node-gold-idle-strip.png`
- Create: `assets/images/mining/nodes/node-gold-hit-strip.png`
- Create: `assets/images/mining/nodes/node-gold-exhaust-strip.png`
- Delete: `assets/images/mining/landing_basin/deposit_n1.png` through `deposit_n4.png`
- Delete: `assets/images/mining/landing_basin/impact.png`
- Modify: `lib/mining/presentation/mining_visuals.dart`
- Modify: `lib/mining/presentation/landing_basin_mining_node_visual.dart`
- Modify: `lib/mining/presentation/mine_site_screen.dart`
- Modify: `test/mining/presentation/mining_visuals_test.dart`
- Modify: `test/mining/presentation/landing_basin_mining_node_visual_test.dart`

**Interfaces:**
- Consumes: `MiningVisuals.goldNodeStageAsset(int)`, `_MineNodeButton.progress`, and the existing `impactSequence`.
- Produces: `LandingBasinMiningNodeVisual.progress`, `MiningVisuals.goldNodeIdleAsset(int)`, `goldNodeHitAsset(int)`, and `goldNodeExhaustAsset(int)`.

- [ ] **Step 1: Add failing consumer-visible widget tests**

Extend `_pumpVisual` with `double progress = 0` and pass it to `LandingBasinMiningNodeVisual`. Add literal boundary cases that find the `Image` below `landing-basin-gold-node` and assert its `AssetImage.assetName`:

```dart
const cases = {
  0.0: 'assets/images/mining/nodes/node-gold-s1.png',
  .249: 'assets/images/mining/nodes/node-gold-s1.png',
  .25: 'assets/images/mining/nodes/node-gold-s2.png',
  .599: 'assets/images/mining/nodes/node-gold-s2.png',
  .60: 'assets/images/mining/nodes/node-gold-s3.png',
  .899: 'assets/images/mining/nodes/node-gold-s3.png',
  .90: 'assets/images/mining/nodes/node-gold-s4.png',
  1.0: 'assets/images/mining/nodes/node-gold-s4.png',
};
```

Pump every boundary with `reducedMotion: true` so idle animation cannot alter the expected stage. Add focused tests proving:

- S1 idle advances `idle-01` → `idle-02` → `idle-03` → `idle-04` every 125ms and loops after 500ms.
- An S1 impact shows `hit-01`, `hit-02`, and `hit-03` during the contact window while the chassis transform stays fixed and the arm transform moves.
- A `.899` → `.90` update paired with a new impact sequence holds S3 during wind-up, then shows `exhaust-01` through `exhaust-04` every 100ms and settles on S4.
- Reduced motion remains on the static stage plate with fixed chassis and arm throughout an impact.
- None of the old `landing-basin-impact`, `sparks`, `rock-chips`, `dust`, or `gold-glow` keys exists.

- [ ] **Step 2: Run the widget test and verify RED**

Run:

```sh
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Expected: compile failure because `progress` is not accepted.

- [ ] **Step 3: Generate the exact frame family with the image-generation skill**

Use the approved stage plates as edit references, one image-generation call per frame. Preserve the locked camera, individual rock identity, transparent background, and registered base footprint. Apply only these changes:

```text
Idle 01: exact S1, emissive intensity 70%, no particles.
Idle 02: exact S1 geometry, emissive intensity 90%, slight inner-vein bleed.
Idle 03: exact S1 geometry, emissive intensity 100%, one or two tiny sparkle motes.
Idle 04: exact S1 geometry, emissive intensity 85%, the tiny motes fading.

Hit 01: S1 compressed vertically by 4px at the top, emissive intensity 130%, 3-5 pea-sized chips at the upper-left contact point.
Hit 02: S1 at full height, chips moving a short distance outward, a few short sparks, low dust bloom contained inside the 512px cell.
Hit 03: S1 settled, chips nearly gone, sparks fading, a thin base haze.

Exhaust 01: exact S3.
Exhaust 02: S3 crown slumps inward, gold gutters dim, one small contained dust puff.
Exhaust 03: lower inward slump approaching S4, only sparse patchy glow remains.
Exhaust 04: exact S4.
```

Normalize only edge-connected baked checkerboard pixels to alpha when necessary. Register idle/hit frames to the S1 bbox `(58, 7, 454, 504)`, exhaust 01 to S3 bbox `(58, 270, 454, 504)`, and exhaust 04 to S4 bbox `(58, 340, 454, 504)`. Assemble the approved individual frames left-to-right into 2048×512 idle, 1536×512 hit, and 2048×512 exhaust strips with no gutters. Do not commit temporary cleanup scripts or generator drafts.

- [ ] **Step 4: Add minimal asset helpers and bundle checks**

Add closed 1-based frame-path helpers for idle `1..4`, hit `1..3`, and exhaust `1..4`, plus constants for the three strip paths. Update the host-only bundle test to load every individual frame and strip, and use Flutter image codecs to assert frame dimensions are 512×512 and strip dimensions are 2048×512, 1536×512, and 2048×512.

- [ ] **Step 5: Implement stage and frame selection**

Pass `_MineNodeButton.progress` into `LandingBasinMiningNodeVisual`. In that widget:

```dart
int _stageForProgress(double progress) {
  if (progress < .25) return 1;
  if (progress < .60) return 2;
  if (progress < .90) return 3;
  return 4;
}
```

Use the existing one-second controller for arm/hit/exhaust timing and one 500ms repeating controller for the S1 idle loop. The hit contact window starts at normalized impact time `.24`; select three frames at 12fps. Exhaust is armed only when a new `impactSequence` arrives with `old.progress < .90 && progress >= .90`; hold S3 during wind-up, then select four frames at 10fps and settle on S4. Stop idle ticking outside S1 and whenever reduced motion is enabled.

- [ ] **Step 6: Delete the obsolete effect implementation and assets**

Remove `landingBasinDepositAsset`, `landingBasinImpact`, `_effectWidgets`, `_paintedEffect`, `_LandingBasinEffectPainter`, `_LandingBasinEffectKind`, and their now-unused math/opacity/scale/translation helpers. Keep `_armAngle`, easing, robot body/arm keys, node/tier semantics, and layout dimensions.

- [ ] **Step 7: Run focused tests and commit**

Run:

```sh
dart format --output=none --set-exit-if-changed lib/mining/presentation test/mining/presentation
flutter analyze --fatal-infos
flutter test test/mining/presentation/mining_visuals_test.dart test/mining/presentation/landing_basin_mining_node_visual_test.dart test/mining/presentation/mine_site_screen_test.dart
```

Expected: all pass.

```sh
git add assets/images/mining/nodes lib/mining/presentation test/mining/presentation
git rm assets/images/mining/landing_basin/deposit_n1.png assets/images/mining/landing_basin/deposit_n2.png assets/images/mining/landing_basin/deposit_n3.png assets/images/mining/landing_basin/deposit_n4.png assets/images/mining/landing_basin/impact.png
git commit -m "feat(mining): animate gold resource depletion"
```

---

### Task 3: Refresh Visual Evidence and Repository Gates

**Files:**
- Modify: `test/mining/presentation/goldens/mine_site_430x932.png`
- Modify: `test/mining/presentation/goldens/mine_site_874x402.png`

**Interfaces:**
- Consumes: the complete Task 2 visual at real Mine Site node/rig sizes.
- Produces: current Linux golden evidence and a user-visible runtime capture.

- [ ] **Step 1: Run the Linux golden test before updating**

Run the established Flutter 3.32.5 Linux container command with Docker `--platform linux/amd64` for `test/mining/presentation/visual_parity_golden_test.dart` without `--update-goldens` and confirm the Landing Basin goldens fail only because the approved node art changed.

- [ ] **Step 2: Update and re-run the Linux goldens**

Run the same test with `--update-goldens`, then again without it. Expected: all visual parity goldens pass.

- [ ] **Step 3: Capture the real-size visual sequence**

Render the Landing Basin widget at the existing portrait Mine Site size and capture representative idle, hit-contact, S2, S3/exhaust, and S4 frames. Inspect that every effect stays within the node bounds, the base footprint does not drift, the chassis stays fixed, and the arm remains readable.

- [ ] **Step 4: Run repository verification**

Run:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

Expected: every gate passes.

- [ ] **Step 5: Commit refreshed evidence**

```sh
git add test/mining/presentation/goldens
git commit -m "test(mining): refresh staged gold node goldens"
```
