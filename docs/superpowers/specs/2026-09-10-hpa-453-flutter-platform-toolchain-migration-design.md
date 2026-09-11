# HPA-453 Flutter Platform Toolchain Migration Design

## Goal

Intentionally adopt the Flutter-generated Android/iOS scaffold migration that was removed from HPA-451, and make every existing repository-managed Flutter pin agree with the current Flutter 3.47 stable hotfix.

This is a platform-maintenance PR only. It must not change Horologium gameplay, mining domain behavior, presentation, or authored assets.

## Context

HPA-451 temporarily contained commit `3855f0e3c75ec0626a1f38454910e7c0e545826d`, generated after a newer Flutter SDK migrated Android plus eight iOS project files. Review correctly removed it because that feature PR still validated on Flutter 3.32.5 and the platform baseline would otherwise depend on an unspecified local SDK.

As of 2026-09-10:

- `main` is still on the pre-migration platform scaffold;
- `.github/workflows/flutter_ci.yml` and `.github/workflows/flutter_tests.yml` pin Flutter `3.32.5`;
- `.cursor/install.sh` also pins `FLUTTER_VERSION="3.32.5"` for Cloud Agent environments;
- Flutter `3.47.3` is the current 3.47 stable hotfix;
- Flutter 3.41+ uses the UIScene lifecycle by default and auto-migrates eligible stock AppDelegate apps when `flutter build ios`/`flutter run` executes;
- Horologium's `AppDelegate.swift` is still the stock registration shape and does not need a custom `SceneDelegate.swift`;
- the known migration raises the real Xcode iOS deployment target from 12.0 to 13.0, adopts the implicit-engine/UIScene lifecycle, moves generated iOS plugin resolution into `FlutterGeneratedPluginSwiftPackage`, keeps Flutter itself wired through CocoaPods, and adds the Android migrator compatibility flags;
- Horologium relies on native iOS plugins for both `audioplayers` audio and `shared_preferences` persistence, so a native compile alone does not prove the new plugin-registration path works at runtime.

HPA-453 is the existing task for this work. It remains one ticket and one PR.

## Decision

Cut the repository over in one jump from Flutter **3.32.5** to the **latest stable hotfix in the Flutter 3.47 line at implementation start**. As of this review that exact version is **3.47.3**.

At implementation start, run `flutter channel stable && flutter upgrade`, record `flutter --version`, and require the result to be `3.47.x`. Pin that exact resolved version in all repository-managed environments. If stable has moved to a later `3.47.x` hotfix, use that exact hotfix consistently. If stable has moved to Flutter 3.50 or another feature line, stop and reassess rather than silently broadening HPA-453.

Use reverted commit `3855f0e` as the semantic oracle for the expected platform migration, not as a cherry-pick and not as permission for arbitrary generated drift.

Update all three existing repository-managed Flutter pin locations in the same PR:

- `.github/workflows/flutter_ci.yml`;
- `.github/workflows/flutter_tests.yml`;
- `.cursor/install.sh`.

Do not introduce a fourth pin mechanism or a compatibility layer for Flutter 3.32.5.

## Expected implementation surface

### Generated platform scaffold

These nine paths are the expected generated scaffold migration:

1. `android/gradle.properties`
   - add `android.builtInKotlin=false` and `android.newDsl=false`;
2. `ios/Podfile`
   - update the Flutter-generated iOS baseline comment from 12.0 to 13.0;
3. `ios/Podfile.lock`
   - commit the generated CocoaPods lock; Flutter remains the CocoaPods dependency while Flutter plugins are represented through the generated local Swift package;
4. `ios/Runner.xcodeproj/project.pbxproj`
   - change all three `IPHONEOS_DEPLOYMENT_TARGET = 12.0` settings to `13.0`;
   - adopt generated CocoaPods build phases/framework references and `FlutterGeneratedPluginSwiftPackage` integration;
5. `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
   - adopt the generated Flutter scheme preparation changes;
6. `ios/Runner.xcworkspace/contents.xcworkspacedata`
   - wire the Pods project into the workspace;
7. `ios/Runner/AppDelegate.swift`
   - conform to `FlutterImplicitEngineDelegate` and register plugins through `FlutterImplicitEngineBridge.pluginRegistry`;
8. `ios/Runner/Info.plist`
   - add the generated `UIApplicationSceneManifest` using Flutter's default `FlutterSceneDelegate`;
   - preserve the Horologium display name, both orientation arrays, `CADisableMinimumFrameDurationOnPhone`, and `UIApplicationSupportsIndirectInputEvents`;
9. `ios/Flutter/AppFrameworkInfo.plist`
   - match the oracle: remove the old `MinimumOSVersion` key/value rather than hand-writing it to 13.0.

A custom `SceneDelegate.swift` is not part of the expected migration. If Flutter requests custom lifecycle source because it detects app-specific lifecycle behavior, stop and reassess.

### Existing toolchain pins and CI signal

These three existing pin surfaces move from 3.32.5 to the exact resolved 3.47.x hotfix:

- `.github/workflows/flutter_ci.yml`;
- `.github/workflows/flutter_tests.yml`;
- `.cursor/install.sh`.

The existing `macos-latest` / `platform: ios` row in `flutter_tests.yml` must also run:

```yaml
- name: Build iOS (simulator, debug)
  if: matrix.platform == 'ios'
  run: flutter build ios --simulator --debug
```

Do not create a new workflow or job. Horologium is public, so the existing standard GitHub-hosted macOS runner is already free/unlimited and should provide native-iOS signal after this migration rather than duplicating a Dart-only test run.

### Conditional Android compatibility floor

Before running the first Android migration build, execute `flutter doctor -v` and `flutter analyze --suggestions` under the resolved Flutter 3.47.x SDK.

The current repository uses AGP 8.7.3, KGP 2.1.0, Gradle 8.12, and Java 11 source/target compatibility. Do not proactively modernize those values. If Flutter 3.47.x explicitly reports that a higher AGP, Gradle, KGP, JDK, or Java source/target floor is required to build, raise only the required value to the minimum compatible version in this same PR. A forced minimum compatibility bump is part of the toolchain cutover; discretionary modernization beyond that minimum is out of scope.

Any such conditional bump must be documented in the PR and limited to the Android build files that own the reported incompatibility.

## Generated metadata

Keep this simple:

- `.metadata` should not change because this plan does not run `flutter create` or `flutter migrate`. If it changes, stop and identify what wrote it rather than accepting it as normal migration noise.
- Run `git diff -- pubspec.lock` after `flutter pub get`. Any package name/version/source/hash change is a stop. If only the terminal `sdks:` constraint block changes, review that small diff directly and keep it only if the target SDK requires it.

The committed lockfile already has a Dart SDK constraint newer than the currently pinned Flutter 3.32.5 / Dart 3.8.1 environment, so do not assume either that the lockfile must change or that it must stay byte-identical.

## Native runtime smoke

The iOS migration changes both plugin resolution and registration lifecycle. A successful Xcode build proves the app links; it does not prove the audio and persistence channels answer at runtime.

After the migrated app builds, perform one simulator smoke with the real plugins:

1. start from a fresh simulator app install;
2. launch Horologium with `flutter run` on the iOS simulator;
3. open Settings, toggle music off and back on, and confirm audible playback responds;
4. on the fresh mining state, merge the two starting T1 rigs and deploy the resulting T2 rig to Landing Basin;
5. fully terminate the app and relaunch it;
6. confirm the deployed/commissioned Landing Basin state survives the relaunch.

This is intentionally a manual smoke rather than new integration-test infrastructure. Record the two results (`audio PASS`, `save reload PASS`) on the existing PR.

## Explicit non-goals

Do not:

- change files under `lib/`, `test/`, or `assets/` to accommodate the SDK bump;
- upgrade hosted Dart/Flutter packages;
- perform Flutter's built-in Kotlin/new Gradle DSL migration; retain the two compatibility opt-outs;
- proactively upgrade AGP/Gradle/Kotlin/JDK beyond a tool-enforced minimum;
- add FVM, mise, asdf, `.flutter-version`, or another version manager;
- refactor the three existing pins into a reusable workflow/custom action;
- add a custom `SceneDelegate.swift` without a concrete migration requirement;
- regenerate skipped visual goldens;
- alter bundle identifiers, signing, provisioning, app capabilities, display name, orientations, or existing Horologium Info.plist behavior;
- preserve compatibility with Flutter 3.32.5 after the cutover.

## Migration workflow

1. Start from current `main` with a clean worktree.
2. Prove all four existing 3.32.5 pin occurrences and the three Xcode `IPHONEOS_DEPLOYMENT_TARGET = 12.0` settings.
3. Run `flutter channel stable && flutter upgrade`; require stable 3.47.x and record the exact hotfix.
4. Run `flutter doctor -v` and `flutter analyze --suggestions`; allow only a forced minimum Android compatibility bump if required.
5. Run `flutter pub get`; inspect `pubspec.lock` directly and require `.metadata` to remain unchanged.
6. Trigger the scoped migration with `flutter build apk --debug` and `flutter build ios --simulator --debug`.
7. Inspect the generated file list before accepting changes. Compare the expected nine scaffold files semantically to `3855f0e`.
8. Update all three repository pin surfaces to the exact resolved 3.47.x hotfix.
9. Add the conditional iOS simulator build step to the existing macOS test matrix row.
10. Run the full repository gate, then perform the one manual iOS runtime smoke for audio and save persistence.

Do not use `flutter create .` as a blanket regeneration command.

## Risks and stop conditions

### Swift Package Manager plugin resolution

The oracle moves Flutter plugin resolution to `FlutterGeneratedPluginSwiftPackage` while Flutter itself remains in the CocoaPods workspace. The compile gate catches Xcode/SPM/Pods wiring failures; the simulator smoke catches plugin-registration failures that would otherwise leave audio or SharedPreferences unavailable.

### UIScene lifecycle cutover

Flutter 3.41+ should auto-migrate Horologium's stock AppDelegate to the oracle's implicit-engine/default `FlutterSceneDelegate` shape. Custom native lifecycle source is a stop/rescope signal.

### Android toolchain floor

The compatibility opt-outs do not waive Flutter's minimum Android build-tool requirements. Preflight them before the first Android build. A tool-enforced minimum bump is allowed; discretionary modernization is not.

### New analyzer diagnostics

If the new bundled Dart/analyzer requires edits under `lib/` or `test/`, do not silently fold them into HPA-453. Record the failure and rescope application-code fixes separately.

### Generated file drift

`.metadata` is not expected to move. `pubspec.lock` is inspect-only. Additional generated Android/iOS files outside the expected migration or an explicitly required Android minimum-floor fix remain a hard stop.

### Xcode/CocoaPods generated identifiers

Generated object IDs and checksums may differ from `3855f0e`; compare semantic roles, not byte identity.

## Validation

### Baseline assertions

Before migration:

```sh
grep -R "3\.32\.5" .github/workflows/flutter_ci.yml .github/workflows/flutter_tests.yml .cursor/install.sh
test "$(grep -c "IPHONEOS_DEPLOYMENT_TARGET = 12.0;" ios/Runner.xcodeproj/project.pbxproj)" -eq 3
grep -n "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist
grep -n "GeneratedPluginRegistrant.register(with: self)" ios/Runner/AppDelegate.swift
! grep -q "android.builtInKotlin" android/gradle.properties
! grep -q "UIApplicationSceneManifest" ios/Runner/Info.plist
```

After migration:

```sh
test "$(grep -c "IPHONEOS_DEPLOYMENT_TARGET = 13.0;" ios/Runner.xcodeproj/project.pbxproj)" -eq 3
! grep -q "IPHONEOS_DEPLOYMENT_TARGET = 12.0;" ios/Runner.xcodeproj/project.pbxproj
! grep -q "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist
grep -q "FlutterImplicitEngineDelegate" ios/Runner/AppDelegate.swift
grep -q "UIApplicationSceneManifest" ios/Runner/Info.plist
grep -q "FlutterSceneDelegate" ios/Runner/Info.plist
grep -q '<string>Horologium</string>' ios/Runner/Info.plist
grep -q 'CADisableMinimumFrameDurationOnPhone' ios/Runner/Info.plist
grep -q 'UIApplicationSupportsIndirectInputEvents' ios/Runner/Info.plist
test "$(grep -c '<key>UISupportedInterfaceOrientations' ios/Runner/Info.plist)" -eq 2
test "$(grep -c '<string>UIInterfaceOrientation' ios/Runner/Info.plist)" -eq 7
```

For toolchain pins, assert all four occurrences use the exact resolved `3.47.x` hotfix and no 3.32.5 occurrence remains.

### Repository gate

Run under the exact resolved Flutter 3.47.x stable hotfix:

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

CI must independently compile the iOS simulator app on the existing macOS row.

## Acceptance criteria

HPA-453 is complete when:

- GitHub Actions and Cloud Agent bootstrap all pin the same exact current Flutter 3.47.x stable hotfix;
- the known nine-file Android/iOS scaffold migration is intentionally present, plus only a documented minimum Android compatibility bump if the Flutter tooling requires one;
- all three Xcode deployment targets are 13.0;
- `AppFrameworkInfo.plist` no longer carries the old `MinimumOSVersion` entry;
- Info.plist retains Horologium's display name, both orientation arrays, and existing frame/input flags;
- the existing macOS CI row compiles `Runner.app` for the iOS simulator;
- a real simulator smoke proves audio playback responds and mining state survives a full kill/relaunch through the new plugin-registration path;
- Android debug and web builds still succeed;
- the existing test/analyze/format gates pass without application-code edits;
- no hosted-package, built-in Kotlin/new DSL, custom SceneDelegate, golden-regeneration, or new toolchain-management abstraction is bundled into the PR.