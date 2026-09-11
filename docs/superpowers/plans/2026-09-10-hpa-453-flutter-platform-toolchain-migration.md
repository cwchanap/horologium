# HPA-453 Flutter Platform Toolchain Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Horologium's Android/iOS scaffold and every existing repository-managed Flutter pin from the 3.32.5-era baseline to Flutter 3.47.2 without changing Dart/gameplay behavior.

**Architecture:** This is a generated-platform cutover, not a toolchain rewrite. Keep the Flutter application/domain untouched; accept the nine already-observed Android/iOS migration files, update the two existing GitHub Actions pins plus the existing Cloud Agent pin, and hard-stop on unexplained generated drift. The migrated iOS host must be compiled on macOS and its successful simulator-build evidence must be visible on the PR.

**Tech Stack:** Flutter 3.47.2 stable, Dart bundled with Flutter 3.47.2, Android Gradle project, iOS/Xcode, CocoaPods, GitHub Actions, Cloud Agent bootstrap.

**Spec:** `docs/superpowers/specs/2026-09-10-hpa-453-flutter-platform-toolchain-migration-design.md`

## Global Constraints

- One Linear task and one implementation PR: HPA-453.
- Target Flutter version is exactly `3.47.2` on the stable channel.
- Jump directly from 3.32.5 to 3.47.2; do not add intermediate-version PRs or a 3.32.5 compatibility layer.
- Do not add FVM, mise, asdf, `.flutter-version`, reusable workflows, or another toolchain abstraction.
- Do not intentionally change `pubspec.yaml`, `lib/`, `test/`, or `assets/`.
- Do not upgrade hosted package versions/hashes, Gradle, AGP, Kotlin, or CocoaPods as separate modernization work.
- Normal production/configuration changes are limited to the nine platform scaffold paths plus `.github/workflows/flutter_ci.yml`, `.github/workflows/flutter_tests.yml`, and `.cursor/install.sh`.
- `.metadata` and an SDK-constraint-only `pubspec.lock` diff are conditional reviewed exceptions only; neither is blanket-allowed.
- The reverted HPA-451 commit `3855f0e3c75ec0626a1f38454910e7c0e545826d` is the semantic review oracle for the platform migration.
- Retain `android.builtInKotlin=false` and `android.newDsl=false`; do not perform the built-in Kotlin/new Gradle DSL migration here.
- Do not add a custom `SceneDelegate.swift` unless Flutter 3.47.2 proves the stock migration is insufficient; that result would require scope reassessment.
- Backward compatibility with Flutter 3.32.5 is not required after this PR.

---

### Task 0: Prove the starting baseline and select the target SDK

**Files:**
- Read only: `.github/workflows/flutter_ci.yml`
- Read only: `.github/workflows/flutter_tests.yml`
- Read only: `.cursor/install.sh`
- Read only: `android/gradle.properties`
- Read only: `ios/Podfile`
- Read only: `ios/Runner.xcodeproj/project.pbxproj`
- Read only: `ios/Runner/AppDelegate.swift`
- Read only: `ios/Runner/Info.plist`
- Read only: `ios/Flutter/AppFrameworkInfo.plist`
- Read only: `pubspec.lock`
- Read only: `.metadata`

**Interfaces:**
- Consumes: clean branch created from current `main`.
- Produces: verified Flutter 3.47.2 execution environment and evidence that all existing pins and native scaffold are still on the pre-migration baseline.

- [ ] **Step 1: Verify the branch is clean before generated tooling runs**

Run:

```sh
git status --short
git rev-parse --abbrev-ref HEAD
```

Expected:

```text
<no git status output>
<the HPA-453 implementation branch>
```

Do not continue from a dirty worktree because generated platform changes become impossible to attribute safely.

- [ ] **Step 2: Verify all three repository-managed Flutter pins are still 3.32.5**

Run:

```sh
grep -R "3\.32\.5" \
  .github/workflows/flutter_ci.yml \
  .github/workflows/flutter_tests.yml \
  .cursor/install.sh
```

Expected:

- one match in `flutter_ci.yml`;
- two matches in `flutter_tests.yml`;
- one `FLUTTER_VERSION="3.32.5"` match in `.cursor/install.sh`.

The Cloud Agent bootstrap is an existing pin and must move with CI; do not leave it on 3.32.5.

- [ ] **Step 3: Verify the real pre-migration iOS 12 baseline**

Run:

```sh
grep -n "platform :ios, '12.0'" ios/Podfile
grep -n "IPHONEOS_DEPLOYMENT_TARGET = 12.0;" ios/Runner.xcodeproj/project.pbxproj
count="$(grep -c "IPHONEOS_DEPLOYMENT_TARGET = 12.0;" ios/Runner.xcodeproj/project.pbxproj)"
test "$count" -eq 3
grep -n "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist
```

Expected: the Podfile comment exists, exactly three Xcode build configurations have a 12.0 deployment target, and `AppFrameworkInfo.plist` still contains the old `MinimumOSVersion` key.

The three pbxproj settings are the authoritative deployment-target assertion; the Podfile line is only a generated comment.

- [ ] **Step 4: Verify the remaining pre-migration markers**

Run:

```sh
grep -n "GeneratedPluginRegistrant.register(with: self)" ios/Runner/AppDelegate.swift
! grep -q "FlutterImplicitEngineDelegate" ios/Runner/AppDelegate.swift
! grep -q "UIApplicationSceneManifest" ios/Runner/Info.plist
! grep -q "android.builtInKotlin" android/gradle.properties
! grep -q "android.newDsl" android/gradle.properties
```

Expected: all commands succeed.

- [ ] **Step 5: Snapshot generated metadata before migration**

Run:

```sh
cp pubspec.lock /tmp/hpa-453-pubspec.lock.before
cp .metadata /tmp/hpa-453-metadata.before
```

These copies are only review aids; do not add them to git.

- [ ] **Step 6: Select Flutter 3.47.2 without adding repository-managed version tooling**

Use the developer/agent machine's existing SDK-management method, then run:

```sh
flutter --version
flutter channel
```

Expected: Flutter `3.47.2` on the stable channel. If the machine cannot provide exactly 3.47.2, stop; do not substitute a newer/older SDK and do not add another version-manager file to the repo.

---

### Task 1: Generate and constrain the Android/iOS scaffold migration

**Files:**
- Modify: `android/gradle.properties`
- Modify: `ios/Flutter/AppFrameworkInfo.plist`
- Modify: `ios/Podfile`
- Create: `ios/Podfile.lock`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- Modify: `ios/Runner.xcworkspace/contents.xcworkspacedata`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Runner/Info.plist`
- Conditional review only: `.metadata`
- Conditional review only: `pubspec.lock`

**Interfaces:**
- Consumes: Flutter 3.47.2 environment and baseline evidence from Task 0.
- Produces: the intentional nine-file platform scaffold migration validated by Android and iOS build tooling, with any metadata-only drift explicitly classified.

- [ ] **Step 1: Resolve the existing dependency graph without upgrading packages**

Run:

```sh
flutter pub get
```

Then inspect manifests immediately:

```sh
git diff -- pubspec.yaml pubspec.lock .metadata
```

Required result:

- `pubspec.yaml` must not change;
- no package name/version/source/hash entry in `pubspec.lock` may change;
- `.metadata` and `pubspec.lock` may remain unchanged, which is preferred.

If `pubspec.lock` changes only under its terminal `sdks:` block, do **not** classify it as a package upgrade or automatically accept it. Confirm all package entries are byte-for-byte unchanged:

```sh
python3 - <<'PY'
from pathlib import Path

def package_block(text: str) -> str:
    return text.split('\nsdks:\n', 1)[0]

before = Path('/tmp/hpa-453-pubspec.lock.before').read_text()
after = Path('pubspec.lock').read_text()
if package_block(before) != package_block(after):
    raise SystemExit('package portion of pubspec.lock changed')
print('package portion unchanged; inspect sdks: delta manually')
PY

git diff -- pubspec.lock
```

Accept an SDK-constraint-only delta only if it is generated by Flutter 3.47.2, required for a successful unchanged dependency graph, and its rationale is recorded in the PR. Otherwise restore `pubspec.lock`.

If `.metadata` changes, inspect it separately:

```sh
git diff -- .metadata
```

Only Flutter-generated revision/channel/migration bookkeeping is potentially acceptable. A change to project type, unmanaged files, or platform capabilities is a stop condition.

- [ ] **Step 2: Trigger the Android project migrator under Flutter 3.47.2**

Run:

```sh
flutter build apk --debug
```

Expected: successful debug APK build and these exact compatibility additions in `android/gradle.properties`:

```properties
# This builtInKotlin flag was added automatically by Flutter migrator
android.builtInKotlin=false
# This newDsl flag was added automatically by Flutter migrator
android.newDsl=false
```

Do not manually update Gradle, AGP, Kotlin, or convert to the new DSL in this ticket.

- [ ] **Step 3: Trigger the iOS project migrator under Flutter 3.47.2 and compile Runner.app**

On macOS, run:

```sh
set -o pipefail
flutter build ios --simulator --debug 2>&1 | tee /tmp/hpa-453-ios-build.log
```

Expected: successful simulator `Runner.app` build. This command is both the migrator trigger and the native compile gate.

The generated migration must semantically match `3855f0e3c75ec0626a1f38454910e7c0e545826d`:

- the Podfile baseline comment moves 12.0 -> 13.0;
- all three `IPHONEOS_DEPLOYMENT_TARGET` settings move 12.0 -> 13.0;
- `ios/Podfile.lock` is generated/committed;
- Xcode project/workspace gains the generated Pods and `FlutterGeneratedPluginSwiftPackage` wiring;
- Runner scheme gains the generated Flutter pre-action/build preparation;
- `AppDelegate` adopts `FlutterImplicitEngineDelegate` and registers plugins through `FlutterImplicitEngineBridge.pluginRegistry`;
- `Info.plist` gains `UIApplicationSceneManifest` with Flutter's default scene delegate;
- `AppFrameworkInfo.plist` removes the old `MinimumOSVersion` entry rather than rewriting it to 13.0.

Do not create `SceneDelegate.swift` unless Flutter explicitly proves the stock migration cannot apply; that is a stop/rescope signal.

- [ ] **Step 4: Assert the migrated iOS baseline rather than trusting the generated diff visually**

Run:

```sh
grep -n "platform :ios, '13.0'" ios/Podfile
count="$(grep -c "IPHONEOS_DEPLOYMENT_TARGET = 13.0;" ios/Runner.xcodeproj/project.pbxproj)"
test "$count" -eq 3
! grep -q "IPHONEOS_DEPLOYMENT_TARGET = 12.0;" ios/Runner.xcodeproj/project.pbxproj
! grep -q "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist
grep -q "FlutterImplicitEngineDelegate" ios/Runner/AppDelegate.swift
grep -q "FlutterImplicitEngineBridge" ios/Runner/AppDelegate.swift
grep -q "UIApplicationSceneManifest" ios/Runner/Info.plist
grep -q "FlutterSceneDelegate" ios/Runner/Info.plist
```

Expected: all commands succeed and the 13.0 deployment-target count is exactly 3.

- [ ] **Step 5: Enforce the generated-file allowlist before accepting anything else**

Run:

```sh
git status --short
git diff --name-only | sort
```

Ignoring the already-committed HPA-453 planning docs, the normal changed platform files at this point are exactly:

```text
android/gradle.properties
ios/Flutter/AppFrameworkInfo.plist
ios/Podfile
ios/Podfile.lock
ios/Runner.xcodeproj/project.pbxproj
ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
ios/Runner.xcworkspace/contents.xcworkspacedata
ios/Runner/AppDelegate.swift
ios/Runner/Info.plist
```

Conditional exceptions:

- `.metadata` only under the narrow generated-bookkeeping rule from Step 1;
- `pubspec.lock` only when its package portion is identical and only `sdks:` changed under the reviewed rule from Step 1.

Any other Android/iOS/config file is a hard stop. Do not accept extra migration because Flutter generated it.

- [ ] **Step 6: Compare the semantic migration with the rejected HPA-451 patch**

Inspect commit:

```text
3855f0e3c75ec0626a1f38454910e7c0e545826d
```

Expected: the same nine file roles and migration intent. Generated Xcode object IDs/checksums may differ, but there must be no new product behavior, custom scene delegate, built-in Kotlin migration, or unrelated native customization.

- [ ] **Step 7: Re-run both platform builds after the generated files settle**

Run:

```sh
flutter build apk --debug
set -o pipefail
flutter build ios --simulator --debug 2>&1 | tee /tmp/hpa-453-ios-build-final.log
```

Expected: both pass without a second wave of unreviewed scaffold changes.

- [ ] **Step 8: Commit the platform scaffold cutover**

Stage the nine expected scaffold files plus only an explicitly approved metadata exception, if one exists:

```sh
git add android/gradle.properties \
  ios/Flutter/AppFrameworkInfo.plist \
  ios/Podfile \
  ios/Podfile.lock \
  ios/Runner.xcodeproj/project.pbxproj \
  ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme \
  ios/Runner.xcworkspace/contents.xcworkspacedata \
  ios/Runner/AppDelegate.swift \
  ios/Runner/Info.plist
```

If a reviewed `.metadata` or SDK-constraint-only `pubspec.lock` delta was accepted, add that file explicitly after documenting why.

Commit:

```sh
git commit -m "chore(ios,android): migrate platform scaffold for Flutter 3.47.2"
```

---

### Task 2: Pin CI and Cloud Agent to Flutter 3.47.2

**Files:**
- Modify: `.github/workflows/flutter_ci.yml`
- Modify: `.github/workflows/flutter_tests.yml`
- Modify: `.cursor/install.sh`

**Interfaces:**
- Consumes: platform scaffold that builds on Flutter 3.47.2.
- Produces: every existing repository-managed execution environment selecting the same Flutter 3.47.2 SDK.

- [ ] **Step 1: Change the build workflow's matrix version only**

In `.github/workflows/flutter_ci.yml`, replace:

```yaml
flutter-version: ['3.32.5']
```

with:

```yaml
flutter-version: ['3.47.2']
```

Do not restructure the matrix or workflow steps.

- [ ] **Step 2: Change both mobile/web test workflow pins only**

In `.github/workflows/flutter_tests.yml`, replace both occurrences of:

```yaml
flutter-version: '3.32.5'
```

with:

```yaml
flutter-version: '3.47.2'
```

Do not add a new workflow, new job, reusable workflow, or permanent iOS build step in the normal path. HPA-453's native iOS compile evidence is supplied by the required local macOS build in Tasks 1 and 3.

- [ ] **Step 3: Change the existing Cloud Agent bootstrap pin**

In `.cursor/install.sh`, replace:

```bash
FLUTTER_VERSION="3.32.5"
```

with:

```bash
FLUTTER_VERSION="3.47.2"
```

Keep the existing download URL construction, install location, profile setup, and dependency resolution logic unchanged.

- [ ] **Step 4: Prove no active 3.32.5 repository pin remains**

Run:

```sh
! grep -R "3\.32\.5" \
  .github/workflows/flutter_ci.yml \
  .github/workflows/flutter_tests.yml \
  .cursor/install.sh

grep -R "3\.47\.2" \
  .github/workflows/flutter_ci.yml \
  .github/workflows/flutter_tests.yml \
  .cursor/install.sh
```

Expected: no 3.32.5 matches; four 3.47.2 matches across the three files.

- [ ] **Step 5: Verify the Cloud Agent URL shape still resolves to the stable Linux tarball name**

Run:

```sh
bash -n .cursor/install.sh
grep -n 'flutter_linux_${FLUTTER_VERSION}-stable.tar.xz' .cursor/install.sh
```

Expected: shell syntax passes and the installer still derives the tarball from `FLUTTER_VERSION` rather than introducing another pin.

- [ ] **Step 6: Commit the explicit toolchain pins**

Run:

```sh
git add \
  .github/workflows/flutter_ci.yml \
  .github/workflows/flutter_tests.yml \
  .cursor/install.sh
git commit -m "ci: pin Flutter 3.47.2 across repo environments"
```

---

### Task 3: Run the full migration gate and publish iOS compile evidence

**Files:**
- Verify only; no new production files should be introduced.
- Update: existing HPA-453 PR body/comment with verification evidence.

**Interfaces:**
- Consumes: Tasks 1-2.
- Produces: review-ready HPA-453 implementation with repository-wide regression evidence and a PR-visible native iOS compile result.

- [ ] **Step 1: Run formatting and static analysis**

Run:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: both pass.

If the newer analyzer requires edits under `lib/` or `test/`, stop. Do not silently fix application code in this platform migration.

- [ ] **Step 2: Run VM/widget and coverage tests**

Run:

```sh
flutter test
flutter test --coverage
```

Expected: both pass. Existing skipped visual goldens remain skipped; do not regenerate them for this ticket.

- [ ] **Step 3: Run Chrome tests**

Run:

```sh
flutter test --platform chrome
```

Expected: pass.

- [ ] **Step 4: Run all supported build gates under Flutter 3.47.2**

Run:

```sh
flutter build apk --debug
flutter build web
set -o pipefail
flutter build ios --simulator --debug 2>&1 | tee /tmp/hpa-453-ios-build-merge-gate.log
```

Expected: all pass. The iOS command must execute on macOS and must produce the simulator app successfully.

- [ ] **Step 5: Verify the PR did not drift into application code or dependency upgrades**

Run:

```sh
git diff main...HEAD --name-only | sort
git diff --exit-code main...HEAD -- lib test assets pubspec.yaml
```

Expected: the second command is empty/successful.

The first command may contain only:

- the two HPA-453 planning docs;
- the nine allowed platform scaffold paths;
- `.github/workflows/flutter_ci.yml`;
- `.github/workflows/flutter_tests.yml`;
- `.cursor/install.sh`;
- optional `.metadata` only if the narrow generated-bookkeeping exception was explicitly accepted;
- optional `pubspec.lock` only if its package section is identical and only the reviewed `sdks:` constraint block changed.

If `pubspec.lock` is present, rerun the package-section equality check from Task 1 against `main` before merge.

- [ ] **Step 6: Reassert the deployment target and scene migration after all edits**

Run:

```sh
count="$(grep -c "IPHONEOS_DEPLOYMENT_TARGET = 13.0;" ios/Runner.xcodeproj/project.pbxproj)"
test "$count" -eq 3
! grep -q "IPHONEOS_DEPLOYMENT_TARGET = 12.0;" ios/Runner.xcodeproj/project.pbxproj
! grep -q "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist
grep -q "FlutterImplicitEngineDelegate" ios/Runner/AppDelegate.swift
grep -q "FlutterSceneDelegate" ios/Runner/Info.plist
```

Expected: all checks pass.

- [ ] **Step 7: Review every non-doc diff against the ticket boundary**

Run:

```sh
git diff main...HEAD -- \
  android/gradle.properties \
  ios/Flutter/AppFrameworkInfo.plist \
  ios/Podfile \
  ios/Podfile.lock \
  ios/Runner.xcodeproj/project.pbxproj \
  ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme \
  ios/Runner.xcworkspace/contents.xcworkspacedata \
  ios/Runner/AppDelegate.swift \
  ios/Runner/Info.plist \
  .github/workflows/flutter_ci.yml \
  .github/workflows/flutter_tests.yml \
  .cursor/install.sh \
  .metadata \
  pubspec.lock
```

Confirm every hunk is one of:

- the semantic nine-file Flutter scaffold migration;
- the literal 3.32.5 -> 3.47.2 pin changes;
- a specifically reviewed generated `.metadata` bookkeeping delta;
- a specifically reviewed `pubspec.lock` SDK-constraint-only delta with identical package entries.

- [ ] **Step 8: Publish required PR-visible iOS compile evidence**

Read the final build log:

```sh
tail -n 50 /tmp/hpa-453-ios-build-merge-gate.log
flutter --version
```

Update the existing HPA-453 PR body or add a PR comment containing a fenced verification block with:

```text
Flutter: 3.47.2 stable
Command: flutter build ios --simulator --debug
Result: exit 0
Success line: <exact final Flutter/Xcode line showing the simulator Runner.app build completed>
```

Include any accepted `.metadata` or `pubspec.lock` conditional-exception rationale in the same verification note.

Do not write only "iOS tested locally". The command/version/result must be review-visible.

If local macOS execution is unavailable, the only fallback is to add a conditional `flutter build ios --simulator --debug` step to the existing `macos-latest` / `platform: ios` matrix row. Do not create a new workflow or job.

- [ ] **Step 9: Keep implementation on the existing HPA-453 draft PR**

Do not create a second PR for Cloud Agent pinning, iOS verification, CI, or generated scaffold follow-up work.

## Expected risks / hard stops

- **UIScene:** Flutter 3.41+ should auto-migrate Horologium's stock AppDelegate to the oracle's implicit-engine/default `FlutterSceneDelegate` shape. Custom native lifecycle source is a rescope.
- **Built-in Kotlin/new DSL:** keep the two Android compatibility opt-outs. Extra Android migration files or Gradle/AGP/Kotlin upgrades are a rescope.
- **Analyzer drift:** new `--fatal-infos` diagnostics that require `lib/` or `test/` edits are not permission to broaden this PR.
- **Generated metadata:** `.metadata` and `pubspec.lock` are inspect-first conditional exceptions; package changes are still prohibited.
- **Xcode/CocoaPods identifiers:** generated IDs/checksums may differ from `3855f0e`; compare semantics, not byte identity.
- **iOS compile:** a green `flutter test` on macOS is not native-host verification. A successful simulator build must be visible in PR evidence.

## Final review checklist

- [ ] Flutter target is exactly 3.47.2 stable.
- [ ] Both GitHub Actions workflows and `.cursor/install.sh` use 3.47.2; no active 3.32.5 pin remains.
- [ ] Android contains only the two expected migrator compatibility flags; no built-in Kotlin/new DSL modernization was accepted.
- [ ] Exactly three Xcode project deployment targets moved from 12.0 to 13.0.
- [ ] `AppFrameworkInfo.plist` removed the old `MinimumOSVersion` entry rather than manually rewriting it.
- [ ] UIScene uses the generated `FlutterImplicitEngineDelegate` + default `FlutterSceneDelegate` path; no custom SceneDelegate was added.
- [ ] iOS simulator `Runner.app` compiles successfully under Flutter 3.47.2 and the PR contains command/version/success evidence.
- [ ] CocoaPods/Swift-package/Xcode workspace changes are generated scaffold changes, not hand-built architecture.
- [ ] No Dart/gameplay/save/UI/assets/golden/hosted-package changes exist.
- [ ] Any `.metadata` or `pubspec.lock` exception is narrow, documented, and independently reviewed.
- [ ] Full repository gate passes.
- [ ] One HPA-453 PR contains the entire migration.
