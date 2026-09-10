# HPA-453 Flutter Platform Toolchain Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Horologium's Android/iOS scaffold and active CI workflows from the implicit Flutter 3.32.5-era baseline to an explicit Flutter 3.47.2 baseline without changing Dart/gameplay behavior.

**Architecture:** This is a generated-platform cutover, not a new abstraction. Keep the existing Flutter application/domain untouched; accept only the nine already-observed Android/iOS migration files and update the two existing GitHub Actions Flutter pins in place. Treat any additional generated file as a scope failure until reviewed.

**Tech Stack:** Flutter 3.47.2 stable, Dart bundled with Flutter 3.47.2, Android Gradle project, iOS/Xcode, CocoaPods, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-10-hpa-453-flutter-platform-toolchain-migration-design.md`

## Global Constraints

- One Linear task and one implementation PR: HPA-453.
- Target Flutter version is exactly `3.47.2` on the stable channel.
- Do not add FVM, mise, asdf, `.flutter-version`, reusable workflows, or another toolchain abstraction.
- Do not intentionally change `pubspec.yaml`, `pubspec.lock`, `lib/`, `test/`, or `assets/`.
- Do not upgrade package dependencies, Gradle, AGP, Kotlin, or CocoaPods as separate modernization work.
- Production/configuration changes are limited to the nine platform scaffold paths plus `.github/workflows/flutter_ci.yml` and `.github/workflows/flutter_tests.yml`.
- The reverted HPA-451 commit `3855f0e3c75ec0626a1f38454910e7c0e545826d` is the semantic review oracle for the platform migration.
- If Flutter 3.47.2 generates additional platform/configuration drift, stop before committing it and reassess the ticket scope.
- Backward compatibility with Flutter 3.32.5 is not required after this PR.

---

### Task 0: Prove the starting baseline and select the target SDK

**Files:**
- Read only: `.github/workflows/flutter_ci.yml`
- Read only: `.github/workflows/flutter_tests.yml`
- Read only: `android/gradle.properties`
- Read only: `ios/Podfile`
- Read only: `ios/Runner/AppDelegate.swift`
- Read only: `ios/Runner/Info.plist`
- Read only: `ios/Flutter/AppFrameworkInfo.plist`

**Interfaces:**
- Consumes: clean branch created from current `main`.
- Produces: verified Flutter 3.47.2 execution environment and evidence that the repo is still on the pre-migration scaffold.

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

- [ ] **Step 2: Verify the repository still pins Flutter 3.32.5**

Run:

```sh
grep -R "3\.32\.5" .github/workflows/flutter_ci.yml .github/workflows/flutter_tests.yml
```

Expected: one pin in `flutter_ci.yml` and two pins in `flutter_tests.yml`.

- [ ] **Step 3: Verify the pre-migration platform markers are still present**

Run:

```sh
grep -n "platform :ios, '12.0'" ios/Podfile
grep -n "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist
grep -n "GeneratedPluginRegistrant.register(with: self)" ios/Runner/AppDelegate.swift
! grep -q "android.builtInKotlin" android/gradle.properties
! grep -q "UIApplicationSceneManifest" ios/Runner/Info.plist
```

Expected: all commands succeed.

- [ ] **Step 4: Select Flutter 3.47.2 without adding repository-managed version tooling**

Use the developer/agent machine's existing SDK management method, then run:

```sh
flutter --version
flutter channel
```

Expected: Flutter `3.47.2` and stable channel. If the machine cannot provide Flutter 3.47.2, stop; do not substitute a newer or older SDK and do not add a version-manager file to the repo.

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

**Interfaces:**
- Consumes: Flutter 3.47.2 environment from Task 0.
- Produces: the intentional nine-file platform scaffold migration validated by Android and iOS build tooling.

- [ ] **Step 1: Resolve the existing dependency graph without upgrading packages**

Run:

```sh
flutter pub get
```

Then verify dependency manifests did not change:

```sh
git diff --exit-code -- pubspec.yaml pubspec.lock
```

Expected: no diff. If dependency resolution changes either manifest/lock unexpectedly, restore those files and investigate before continuing; package upgrades are outside HPA-453.

- [ ] **Step 2: Trigger the Android project migrator under Flutter 3.47.2**

Run:

```sh
flutter build apk --debug
```

Expected: successful debug APK build and Flutter-generated Android compatibility migration where required.

After the build, `android/gradle.properties` must contain:

```properties
# This builtInKotlin flag was added automatically by Flutter migrator
android.builtInKotlin=false
# This newDsl flag was added automatically by Flutter migrator
android.newDsl=false
```

Do not use this ticket to change AGP/Kotlin/Gradle versions manually.

- [ ] **Step 3: Trigger the iOS project migrator and CocoaPods/Xcode generation under Flutter 3.47.2**

On macOS, run:

```sh
flutter build ios --simulator --debug
```

Expected: successful iOS simulator build. The generated migration must semantically match `3855f0e3c75ec0626a1f38454910e7c0e545826d`:

- iOS deployment baseline becomes 13.0;
- `ios/Podfile.lock` is generated/committed;
- Xcode project/workspace gains the generated Pods and `FlutterGeneratedPluginSwiftPackage` wiring;
- Runner scheme gains the generated Flutter pre-action/build preparation;
- `AppDelegate` adopts `FlutterImplicitEngineDelegate` and registers plugins through `FlutterImplicitEngineBridge.pluginRegistry`;
- `Info.plist` gains `UIApplicationSceneManifest` while preserving existing orientation/frame-duration entries;
- `AppFrameworkInfo.plist` adopts the new Flutter-generated minimum-OS metadata shape.

- [ ] **Step 4: Enforce the generated-file allowlist before editing anything else**

Run:

```sh
git status --short
git diff --name-only | sort
```

Ignoring the already-committed HPA-453 planning docs, the only changed production/platform files allowed at this point are:

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

If any other Android/iOS/config file appears, stop. Do not accept extra generated migration simply because Flutter produced it.

- [ ] **Step 5: Compare the semantic migration with the rejected HPA-451 patch**

Use GitHub or local git history to inspect commit:

```text
3855f0e3c75ec0626a1f38454910e7c0e545826d
```

Expected: the same nine file roles and migration intent. Exact Xcode-generated identifiers/checksums may differ when regenerated, but there must be no new product behavior or unrelated platform customization.

- [ ] **Step 6: Re-run the two platform builds after the generated files settle**

Run:

```sh
flutter build apk --debug
flutter build ios --simulator --debug
```

Expected: both pass without producing a second wave of unreviewed scaffold changes.

- [ ] **Step 7: Commit the platform scaffold cutover**

Run:

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
git commit -m "chore(ios,android): migrate platform scaffold for Flutter 3.47.2"
```

---

### Task 2: Pin both existing CI workflows to Flutter 3.47.2

**Files:**
- Modify: `.github/workflows/flutter_ci.yml`
- Modify: `.github/workflows/flutter_tests.yml`

**Interfaces:**
- Consumes: platform scaffold that builds on Flutter 3.47.2.
- Produces: CI that tests the same explicit Flutter version as the migrated platform baseline.

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

- [ ] **Step 2: Change both test workflow setup pins only**

In `.github/workflows/flutter_tests.yml`, replace both occurrences of:

```yaml
flutter-version: '3.32.5'
```

with:

```yaml
flutter-version: '3.47.2'
```

Do not add a reusable workflow, environment variable indirection, new matrix dimension, or permanent iOS build job.

- [ ] **Step 3: Prove no active 3.32.5 CI pin remains**

Run:

```sh
! grep -R "3\.32\.5" .github/workflows/flutter_ci.yml .github/workflows/flutter_tests.yml
grep -R "3\.47\.2" .github/workflows/flutter_ci.yml .github/workflows/flutter_tests.yml
```

Expected: no 3.32.5 matches; three 3.47.2 matches.

- [ ] **Step 4: Commit the explicit CI toolchain pin**

Run:

```sh
git add .github/workflows/flutter_ci.yml .github/workflows/flutter_tests.yml
git commit -m "ci: pin Flutter 3.47.2"
```

---

### Task 3: Run the full migration gate and perform whole-branch scope review

**Files:**
- Verify only; no new production files should be introduced.

**Interfaces:**
- Consumes: Tasks 1-2.
- Produces: review-ready HPA-453 implementation with repository-wide regression evidence.

- [ ] **Step 1: Run formatting and static analysis**

Run:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: both pass.

- [ ] **Step 2: Run VM/widget and coverage tests**

Run:

```sh
flutter test
flutter test --coverage
```

Expected: both pass.

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
flutter build ios --simulator --debug
```

Expected: all pass. The iOS command must execute on macOS.

- [ ] **Step 5: Verify the PR did not drift into application code or dependency upgrades**

Run:

```sh
git diff main...HEAD --name-only | sort
git diff --exit-code main...HEAD -- lib test assets pubspec.yaml pubspec.lock
```

Expected: the second command is empty/successful. The first command contains only:

- the two HPA-453 planning docs;
- the nine allowed platform scaffold paths;
- the two existing workflow files.

- [ ] **Step 6: Review every non-doc diff against the ticket boundary**

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
  .github/workflows/flutter_tests.yml
```

Confirm every hunk is either Flutter-generated scaffold migration or the literal `3.32.5` -> `3.47.2` CI pin change.

- [ ] **Step 7: Record verification in the existing HPA-453 pull request**

Update the PR body with the executed Flutter version and gate results. Do not create a second PR for CI or generated iOS follow-up work.

## Final review checklist

- [ ] Flutter target is exactly 3.47.2 stable.
- [ ] Android contains only the two expected migrator flags.
- [ ] iOS baseline is 13.0 and simulator build passes.
- [ ] CocoaPods/Swift-package/Xcode workspace changes are generated scaffold changes, not hand-built architecture.
- [ ] Both active workflows pin 3.47.2.
- [ ] No Dart/gameplay/save/UI/assets/package dependency changes exist.
- [ ] Full repository gate passes.
- [ ] One HPA-453 PR contains the entire migration.
