# HPA-453 Flutter Platform Toolchain Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Horologium from its Flutter 3.32.5-era Android/iOS scaffold and repository pins to the current Flutter 3.47 stable hotfix while preserving application behavior.

**Architecture:** This is a generated-platform cutover, not a toolchain rewrite. Use Flutter's normal build commands to produce the expected nine-file scaffold migration, update the three existing repository pin surfaces, add native-iOS compilation to the existing macOS CI row, and perform one simulator runtime smoke for the native audio/persistence plugins. Keep hard stops for unrelated generated drift and application-code changes.

**Tech Stack:** Flutter 3.47 stable, bundled Dart SDK, Android Gradle project, iOS/Xcode, CocoaPods + Flutter-generated local Swift package, GitHub Actions, Cloud Agent bootstrap.

**Spec:** `docs/superpowers/specs/2026-09-10-hpa-453-flutter-platform-toolchain-migration-design.md`

## Global Constraints

- One Linear task and one implementation PR: HPA-453.
- Target the latest stable **3.47.x** hotfix at implementation start; pin the exact resolved patch version everywhere. As of 2026-09-10 the expected version is `3.47.3`.
- If `flutter upgrade` resolves to Flutter 3.50 or another feature line, stop and reassess instead of silently broadening this PR.
- Do not add FVM, mise, asdf, `.flutter-version`, reusable workflows, or another pin mechanism.
- Do not edit `lib/`, `test/`, or `assets/` to accommodate the SDK bump.
- Do not upgrade hosted packages.
- Retain `android.builtInKotlin=false` and `android.newDsl=false`; do not perform the built-in Kotlin/new Gradle DSL migration.
- The reverted HPA-451 commit `3855f0e3c75ec0626a1f38454910e7c0e545826d` is the semantic oracle for the expected platform migration.
- A tool-enforced minimum Android compatibility bump is allowed only when Flutter 3.47.x explicitly requires it; discretionary Android modernization remains out of scope.
- `.metadata` must not change. `pubspec.lock` may change only in its terminal `sdks:` block; any package name/version/source/hash change is a hard stop.
- Backward compatibility with Flutter 3.32.5 is not required after this PR.

---

### Task 0: Resolve the target SDK and preflight platform compatibility

**Files:**
- Read only: `.github/workflows/flutter_ci.yml`
- Read only: `.github/workflows/flutter_tests.yml`
- Read only: `.cursor/install.sh`
- Read only: `android/settings.gradle.kts`
- Read only: `android/gradle/wrapper/gradle-wrapper.properties`
- Read only: `android/app/build.gradle.kts`
- Read only: `android/gradle.properties`
- Read only: `ios/Runner.xcodeproj/project.pbxproj`
- Read only: `ios/Flutter/AppFrameworkInfo.plist`
- Read only: `ios/Runner/AppDelegate.swift`
- Read only: `ios/Runner/Info.plist`

**Interfaces:**
- Consumes: clean HPA-453 branch based on current `main`.
- Produces: exact target Flutter 3.47.x version plus an explicit decision on whether the current Android floor is already compatible.

- [ ] **Step 1: Verify the worktree is clean before SDK/tooling changes**

Run:

```sh
git status --short
git rev-parse --abbrev-ref HEAD
```

Expected: no status output and the HPA-453 implementation branch.

- [ ] **Step 2: Prove the four existing 3.32.5 pin occurrences**

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

- [ ] **Step 3: Prove the pre-migration native baselines**

Run:

```sh
test "$(grep -c "IPHONEOS_DEPLOYMENT_TARGET = 12.0;" ios/Runner.xcodeproj/project.pbxproj)" -eq 3
grep -n "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist
grep -n "GeneratedPluginRegistrant.register(with: self)" ios/Runner/AppDelegate.swift
! grep -q "UIApplicationSceneManifest" ios/Runner/Info.plist
! grep -q "android.builtInKotlin" android/gradle.properties
! grep -q "android.newDsl" android/gradle.properties
```

Expected: all checks succeed.

- [ ] **Step 4: Record the existing Android build-tool floor**

Run:

```sh
grep -n 'com.android.application' android/settings.gradle.kts
grep -n 'org.jetbrains.kotlin.android' android/settings.gradle.kts
grep -n 'distributionUrl' android/gradle/wrapper/gradle-wrapper.properties
grep -n 'JavaVersion.VERSION_' android/app/build.gradle.kts
```

Expected current values:

```text
AGP 8.7.3
KGP 2.1.0
Gradle 8.12
Java source/target 11
```

Do not change them yet.

- [ ] **Step 5: Upgrade the local SDK checkout to stable and resolve the exact 3.47 hotfix**

Run:

```sh
flutter channel stable
flutter upgrade
flutter --version
```

Then capture the exact version:

```sh
TARGET_FLUTTER_VERSION="$(flutter --version | sed -E -n 's/^Flutter ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')"
case "$TARGET_FLUTTER_VERSION" in
  3.47.*) printf 'Using Flutter %s\n' "$TARGET_FLUTTER_VERSION" ;;
  *) printf 'Expected stable Flutter 3.47.x, got %s\n' "$TARGET_FLUTTER_VERSION" >&2; exit 1 ;;
esac
```

Expected as of plan review: `Using Flutter 3.47.3`.

The implementation must use this exact resolved version for both GitHub Actions pins and `.cursor/install.sh`.

- [ ] **Step 6: Preflight Android compatibility before any migration build**

Run:

```sh
flutter doctor -v
flutter analyze --suggestions
```

Interpretation:

- if Flutter reports the existing AGP 8.7.3 / KGP 2.1.0 / Gradle 8.12 / host JDK combination as compatible, keep those versions unchanged;
- if Flutter explicitly requires a higher AGP, KGP, Gradle, JDK, or Java source/target floor, record the reported minimum and allow only that minimum bump in HPA-453;
- do not upgrade to template/latest versions merely because Flutter 3.47 generates newer projects that way.

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
- Conditional only if Task 0 proves a minimum bump is required: `android/settings.gradle.kts`
- Conditional only if Task 0 proves a minimum bump is required: `android/gradle/wrapper/gradle-wrapper.properties`
- Conditional only if Task 0 proves a minimum bump is required: `android/app/build.gradle.kts`
- Conditional review only: `pubspec.lock`

**Interfaces:**
- Consumes: exact stable Flutter 3.47.x version and Android compatibility decision from Task 0.
- Produces: the intended generated scaffold cutover with no application-code changes.

- [ ] **Step 1: Resolve dependencies and inspect lockfile metadata directly**

Run:

```sh
flutter pub get
git diff -- pubspec.yaml pubspec.lock .metadata
```

Required result:

- `pubspec.yaml` is unchanged;
- `.metadata` is unchanged; if it changed, stop and determine what invoked project migration tooling;
- any `pubspec.lock` package name/version/source/hash change is a hard stop;
- an `sdks:`-only lockfile delta may be retained after direct review, but it is not automatically required or automatically forbidden.

Do not add a custom comparator script; the lockfile diff is small enough to review directly.

- [ ] **Step 2: Apply a required Android minimum-floor fix only if Task 0 identified one**

If Task 0 reported no incompatibility, make no changes in this step.

If Task 0 reported a concrete minimum requirement, change only the file/value that owns that requirement:

- AGP or KGP: `android/settings.gradle.kts`;
- Gradle: `android/gradle/wrapper/gradle-wrapper.properties`;
- Java source/target: `android/app/build.gradle.kts`;
- host JDK only: change the execution environment, not repository files.

Set the minimum compatible version reported by Flutter tooling; do not jump to newest available versions.

- [ ] **Step 3: Trigger the Android migrator**

Run:

```sh
flutter build apk --debug
```

Expected: successful APK build and these generated compatibility flags in `android/gradle.properties`:

```properties
# This builtInKotlin flag was added automatically by Flutter migrator
android.builtInKotlin=false
# This newDsl flag was added automatically by Flutter migrator
android.newDsl=false
```

If Flutter attempts the built-in Kotlin/new DSL conversion despite these opt-outs, stop rather than accepting the wider migration.

- [ ] **Step 4: Trigger the iOS migrator and native compile**

On macOS, run:

```sh
flutter build ios --simulator --debug
```

Expected: successful simulator `Runner.app` build and a migration semantically matching `3855f0e`:

- Podfile baseline comment 12.0 -> 13.0;
- exactly three `IPHONEOS_DEPLOYMENT_TARGET` entries 12.0 -> 13.0;
- `ios/Podfile.lock` created;
- Pods build phases/framework references and `FlutterGeneratedPluginSwiftPackage` added to the Xcode project;
- workspace includes Pods;
- Runner scheme gains generated Flutter preparation;
- `AppDelegate` moves registration to `FlutterImplicitEngineDelegate` / `FlutterImplicitEngineBridge.pluginRegistry`;
- `Info.plist` gains the default `FlutterSceneDelegate` manifest;
- `AppFrameworkInfo.plist` removes `MinimumOSVersion` rather than rewriting it.

Do not create a custom `SceneDelegate.swift`.

- [ ] **Step 5: Assert the iOS migration and preserve existing Info.plist behavior**

Run on macOS:

```sh
plutil -lint ios/Runner/Info.plist
test "$(grep -c "IPHONEOS_DEPLOYMENT_TARGET = 13.0;" ios/Runner.xcodeproj/project.pbxproj)" -eq 3
! grep -q "IPHONEOS_DEPLOYMENT_TARGET = 12.0;" ios/Runner.xcodeproj/project.pbxproj
! grep -q "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist
grep -q "FlutterImplicitEngineDelegate" ios/Runner/AppDelegate.swift
grep -q "FlutterImplicitEngineBridge" ios/Runner/AppDelegate.swift
grep -q "UIApplicationSceneManifest" ios/Runner/Info.plist
grep -q "FlutterSceneDelegate" ios/Runner/Info.plist
grep -q '<string>Horologium</string>' ios/Runner/Info.plist
grep -q 'CADisableMinimumFrameDurationOnPhone' ios/Runner/Info.plist
grep -q 'UIApplicationSupportsIndirectInputEvents' ios/Runner/Info.plist
test "$(grep -c '<key>UISupportedInterfaceOrientations' ios/Runner/Info.plist)" -eq 2
test "$(grep -c '<string>UIInterfaceOrientation' ios/Runner/Info.plist)" -eq 7
```

Expected: all commands pass. The orientation value count is seven: three phone values plus four iPad values.

- [ ] **Step 6: Enforce the generated-file boundary**

Run:

```sh
git status --short
git diff --name-only | sort
```

Normal generated platform files are exactly:

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

Allowed conditional additions are only:

- a Task-0-proven minimum Android compatibility file from Step 2;
- `pubspec.lock` with an `sdks:`-only delta.

`.metadata`, any application file, any new native source file, or any other generated platform file is a hard stop.

- [ ] **Step 7: Compare semantics with the HPA-451 oracle**

Inspect commit `3855f0e3c75ec0626a1f38454910e7c0e545826d` and confirm the same nine generated file roles. Generated Xcode IDs/checksums may differ; do not hand-normalize them.

- [ ] **Step 8: Re-run both platform builds after generated state settles**

Run:

```sh
flutter build apk --debug
flutter build ios --simulator --debug
```

Expected: both pass without producing a second wave of unexplained files.

- [ ] **Step 9: Commit the scaffold migration**

Stage the nine expected files, plus only a Task-0-proven Android minimum-floor file or reviewed `pubspec.lock` SDK-only delta if one actually exists.

Commit:

```sh
git commit -m "chore(ios,android): migrate platform scaffold to Flutter 3.47"
```

---

### Task 2: Pin the resolved Flutter version and make the existing macOS CI row compile iOS

**Files:**
- Modify: `.github/workflows/flutter_ci.yml`
- Modify: `.github/workflows/flutter_tests.yml`
- Modify: `.cursor/install.sh`

**Interfaces:**
- Consumes: exact resolved `3.47.x` version from Task 0 and migrated native scaffold from Task 1.
- Produces: one exact SDK version across CI/Cloud Agent plus persistent native-iOS compile coverage.

- [ ] **Step 1: Replace every existing 3.32.5 pin with the exact Task 0 version**

Use the exact version printed by `flutter --version` in Task 0. As of plan review this is `3.47.3`.

Update:

```yaml
# .github/workflows/flutter_ci.yml
flutter-version: ['3.47.3']
```

```yaml
# both occurrences in .github/workflows/flutter_tests.yml
flutter-version: '3.47.3'
```

```bash
# .cursor/install.sh
FLUTTER_VERSION="3.47.3"
```

If Task 0 resolved a later `3.47.x` hotfix, substitute that exact version in all four occurrences instead. Never use a range in these files.

- [ ] **Step 2: Add iOS compilation to the existing macOS matrix row**

In `.github/workflows/flutter_tests.yml`, immediately after the existing test step, add:

```yaml
      - name: Build iOS (simulator, debug)
        if: matrix.platform == 'ios'
        run: flutter build ios --simulator --debug
```

Do not add a workflow, job, matrix dimension, or artifact upload.

- [ ] **Step 3: Verify pins and installer syntax**

Run, replacing `3.47.3` below only if Task 0 resolved a later 3.47.x hotfix:

```sh
! grep -R "3\.32\.5" \
  .github/workflows/flutter_ci.yml \
  .github/workflows/flutter_tests.yml \
  .cursor/install.sh

grep -R "3\.47\.3" \
  .github/workflows/flutter_ci.yml \
  .github/workflows/flutter_tests.yml \
  .cursor/install.sh
bash -n .cursor/install.sh
grep -n 'flutter_linux_${FLUTTER_VERSION}-stable.tar.xz' .cursor/install.sh
```

Expected: zero old pins, four exact new pins, valid shell syntax, unchanged tarball construction.

- [ ] **Step 4: Review the workflow diff for one-purpose changes**

Run:

```sh
git diff -- \
  .github/workflows/flutter_ci.yml \
  .github/workflows/flutter_tests.yml \
  .cursor/install.sh
```

Expected changes only:

- 3.32.5 -> exact resolved 3.47.x pins;
- one conditional iOS simulator build step on the existing macOS/iOS row.

- [ ] **Step 5: Commit the pin and CI changes**

Commit:

```sh
git commit -am "ci: pin current Flutter 3.47 and compile iOS"
```

---

### Task 3: Prove runtime plugin registration and run the final repository gate

**Files:**
- Verify only; no application code should be added.
- Update: existing PR description/comment with the two manual smoke results and any conditional Android-floor rationale.

**Interfaces:**
- Consumes: migrated scaffold and exact pinned SDK from Tasks 1-2.
- Produces: review-ready HPA-453 branch with native compile coverage and runtime proof for audio + persistence.

- [ ] **Step 1: Perform the real iOS plugin smoke on a fresh simulator install**

Boot an iOS simulator, then run:

```sh
open -a Simulator
flutter devices
xcrun simctl uninstall booted com.example.horologium || true
```

Use the booted simulator ID shown by `flutter devices`:

```sh
flutter run -d <booted-simulator-id>
```

Manual assertions in the running app:

1. fresh mining state starts with the normal two T1 rigs;
2. open Settings, toggle music off and back on, and hear playback respond;
3. merge the two T1 rigs;
4. deploy the resulting T2 rig to Landing Basin;
5. quit the app completely without uninstalling it;
6. run the app again on the same simulator;
7. confirm Landing Basin remains commissioned/deployed.

Record exactly these two results on PR #27:

```text
iOS runtime smoke: audio PASS
SharedPreferences mining reload: PASS
```

If either native plugin throws `MissingPluginException`, fails to respond, or loses state, stop. Do not patch around it in Dart tests.

- [ ] **Step 2: Run formatting and analyzer gates**

Run:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: both pass. If the newer analyzer requires `lib/` or `test/` edits, stop and rescope those application-code fixes separately.

- [ ] **Step 3: Run VM/widget, coverage, and Chrome tests**

Run:

```sh
flutter test
flutter test --coverage
flutter test --platform chrome
```

Expected: all pass. Existing skipped visual goldens remain skipped; do not regenerate them.

- [ ] **Step 4: Run local build gates once more**

Run:

```sh
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

Expected: all pass under the exact pinned Flutter 3.47.x SDK.

- [ ] **Step 5: Reassert the native migration contract**

Run:

```sh
test "$(grep -c "IPHONEOS_DEPLOYMENT_TARGET = 13.0;" ios/Runner.xcodeproj/project.pbxproj)" -eq 3
! grep -q "IPHONEOS_DEPLOYMENT_TARGET = 12.0;" ios/Runner.xcodeproj/project.pbxproj
! grep -q "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist
grep -q "FlutterImplicitEngineDelegate" ios/Runner/AppDelegate.swift
grep -q "FlutterSceneDelegate" ios/Runner/Info.plist
grep -q '<string>Horologium</string>' ios/Runner/Info.plist
grep -q 'CADisableMinimumFrameDurationOnPhone' ios/Runner/Info.plist
grep -q 'UIApplicationSupportsIndirectInputEvents' ios/Runner/Info.plist
test "$(grep -c '<key>UISupportedInterfaceOrientations' ios/Runner/Info.plist)" -eq 2
test "$(grep -c '<string>UIInterfaceOrientation' ios/Runner/Info.plist)" -eq 7
```

Expected: all pass.

- [ ] **Step 6: Review the whole branch for scope drift**

Run:

```sh
git diff main...HEAD --name-only | sort
git diff --exit-code main...HEAD -- lib test assets pubspec.yaml .metadata
```

Expected: the second command is empty/successful.

The first command may contain only:

- the two HPA-453 planning docs;
- the nine expected platform scaffold paths;
- `.github/workflows/flutter_ci.yml`;
- `.github/workflows/flutter_tests.yml`;
- `.cursor/install.sh`;
- `pubspec.lock` only for an `sdks:`-only delta;
- a documented minimum-floor Android file only when Task 0 proved it was required.

Review any `pubspec.lock` diff directly:

```sh
git diff main...HEAD -- pubspec.lock
```

Any package entry change is a stop.

- [ ] **Step 7: Verify CI, especially the existing macOS/iOS row**

Push the same draft PR branch and require the existing workflows to pass. Confirm the `platform: ios` / `macos-latest` matrix execution includes and passes:

```text
Build iOS (simulator, debug)
```

This CI result is the merge-time native compile gate; no separate PR evidence protocol or new workflow is needed.

- [ ] **Step 8: Perform final one-PR review**

Confirm PR #27 contains the planning docs and implementation. Do not create follow-up PRs for the Cloud Agent pin, iOS build step, runtime smoke, or generated scaffold changes.

## Expected risks / hard stops

- **SPM plugin registration:** compile success is insufficient; the mandatory simulator smoke must prove `audioplayers` and `shared_preferences` work through the new generated Swift-package/implicit-engine path.
- **UIScene:** custom native lifecycle source or `SceneDelegate.swift` is not expected and requires reassessment.
- **Android floor:** a Flutter-reported minimum AGP/Gradle/KGP/JDK/Java bump is allowed at exactly the minimum; unrelated modernization is not.
- **Built-in Kotlin/new DSL:** retain both opt-outs; do not accept the larger migration.
- **Analyzer drift:** application-code edits are not part of this PR.
- **Metadata:** `.metadata` must stay unchanged; `pubspec.lock` is direct-review only and package changes are prohibited.
- **Info.plist:** generated reserialization is allowed only if display name, both orientation arrays, and the existing frame/input flags survive.
- **Generated Xcode IDs:** compare semantics, not byte identity.

## Final review checklist

- [ ] The exact pinned SDK is the latest stable Flutter 3.47.x hotfix resolved at implementation start (3.47.3 as of plan review).
- [ ] Both GitHub Actions workflows and `.cursor/install.sh` use that same exact version; no 3.32.5 pin remains.
- [ ] The expected nine-file scaffold migration is present, with only a proven minimum Android-floor addition if required.
- [ ] Both Android migration opt-out flags remain false; no built-in Kotlin/new DSL migration landed.
- [ ] Exactly three Xcode deployment targets are 13.0 and `MinimumOSVersion` is removed.
- [ ] Info.plist retains Horologium display name, two orientation arrays/seven values, and existing frame/input keys.
- [ ] The existing macOS/iOS CI row compiles the simulator app.
- [ ] Manual iOS runtime smoke records `audio PASS` and `SharedPreferences mining reload: PASS`.
- [ ] No `lib/`, `test/`, `assets/`, `.metadata`, hosted-package, custom SceneDelegate, or golden-regeneration changes exist.
- [ ] Full repository format/analyze/test/build gates pass.
- [ ] One HPA-453 PR contains the complete cutover.