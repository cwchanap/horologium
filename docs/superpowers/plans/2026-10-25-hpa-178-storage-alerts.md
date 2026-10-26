# HPA-178 — Storage-full alerts implementation plan

- Status: Proposed (2026-10-25)
- Ticket: https://linear.app/cwchanap/issue/HPA-178/mining-retention-notify-the-player-when-site-storage-fills-while-away
- Design: [2026-10-25-hpa-178-storage-alerts-design.md](../specs/2026-10-25-hpa-178-storage-alerts-design.md)
- Baseline: `main` as of 2026-10-25
- Delivery: **one draft PR for planning and implementation**. Do not split the ticket into a planning PR plus implementation PR; commit implementation onto this same branch when the design is approved.

## Reuse survey

| Existing seam | Action |
| --- | --- |
| `SiteMetrics.of` / `MiningSiteCardView.timeToFull` | Reuse for exact same rate/capacity/rounding |
| `MiningController.checkpoint` / `MiningShell.didChangeAppLifecycleState` | Reuse, but await checkpoint in notification workflow; preserve error handling and normal resume |
| `MiningShell._runSheetAction` | Reuse success path to detect first commissioning |
| `MiningSettingsSheet` / `MiningSheetFrame` | Add one styled switch; don't add a Settings subsystem |
| `AudioManager` preference/testing pattern | Reuse small service ownership pattern, but notification prefs are independent |
| Existing native Android/Flutter configuration | Minimal plugin-specific changes only |

## Task 1 — Pure fill-time projection (tests first)

- Add `nextStorageFull(MiningContentRegistry, MiningSave, DateTime)` alongside `SiteMetrics` in `lib/mining/site_deck_view.dart`.
- Iterate **unlocked** planets and authored sites; require commissioned site and positive deployed-rig rate/capacity; skip full sites.
- Reuse card microsecond-ceiling formula and choose the earliest, with stable authored-order ties.
- Add cases to `test/mining/site_deck_view_test.dart`: no producer, one site, locked/full/idle exclusions, earliest across planets, ties, and parity with `MiningSiteCardView.timeToFull`.

Gate: `flutter test test/mining/site_deck_view_test.dart`.

## Task 2 — Small local notification adapter and settings preferences

- Add compatible pinned constraints for `flutter_local_notifications` and `timezone` in `pubspec.yaml`; run `flutter pub get` and commit `pubspec.lock`.
- Add `lib/game/storage_alerts.dart`: one `StorageAlerts` facade and `StorageAlertPlatform` interface, with real Android/iOS adapter, no-op for web/desktop, and test-injected fake.
- Adapter: lazy initialize, no permission request on initialize, one fixed notification ID, one channel, UTC `zonedSchedule` with **inexact** Android mode, platform default sound, cancel pending alert.
- Facade: default on, persistent `notifications.storageFullEnabled` and `notifications.permissionAsked`; first permission request exactly once; off persists and cancels; no schedule when disabled.
- Add `test/game/storage_alerts_test.dart` with `SharedPreferences.setMockInitialValues`, fake adapter call records, service recreation, replacement and cancellation cases.

Gate: `flutter test test/game/storage_alerts_test.dart`.

## Task 3 — Shell lifecycle and first commission

- Add optional injected `StorageAlerts?` to `MiningShell` like `audioManager`; preserve its injected `nowUtc` closure as a field.
- During shell initialization load alert prefs and cancel a stale alert only once the controller is initialized.
- Replace the lifecycle fire-and-forget checkpoint path with a tiny async background scheduling method that **awaits the existing** `MiningController.checkpoint()` (best-effort, catch/log errors), then chooses the site from the latest controller snapshot.
- Use a generation token to avoid `inactive`/ `paused` duplicate schedules and slow post-resume scheduling. On resume invalidate pending work, cancel and call existing `_resumeMining()`. Dispose must not cancel alert.
- In the existing successful `_runSheetAction` deploy path, detect first commissioned site and request permission asynchronously; avoid permission prompts for failed actions or app launch.
- Extend `pumpShell` injection in `test/mining/presentation/mining_shell_test.dart`; test initialization, first commission, pause earliest, pause null, resume cancel, pause→resume race, and no disposal cancellation.

Gate: `flutter test test/mining/presentation/mining_shell_test.dart`.

## Task 4 — Mobile Settings and native setup

- Extend `MiningSettingsSheet` with `StorageAlerts` and injectable mobile-visibility flag. Add one NOTIFICATIONS group and switch `Key('mining-storage-alerts-switch')`, retaining existing styles/semantics. Ensure the added group does not overflow on a 360×640 portrait screen (scroll only if necessary).
- Pass the service when shell opens Settings. Off persists/cancels; on enables and asks only when never prompted.
- Extend `test/mining/presentation/mining_settings_sheet_test.dart`: flag hides/shows, updates preference, cancel-on-off, no overflow.
- Configure `android/app/build.gradle.kts`: check pinned plugin requirements; current AGP 8.11.1 is already present, but Java/Kotlin 11 may need Java 17 + core-library desugaring, library dependency, and appropriate compile SDK.
- Add manifest permission/receiver required for scheduled notifications; no exact alarm permission. Verify explicit authorization on iOS without adding push capabilities.
- Document the single notification ownership rule in `CLAUDE.md`.

Gates: focused presentation tests, `flutter build apk --debug`, `flutter build ios --simulator --debug` on appropriate CI, and `flutter build web`.

## Task 5 — Repository verification and merge criteria

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

Run native builds on supported runners, not by assuming a web/widget test validates native registration. Optional manual mobile delivery check for UX; do not gate this hobby-project ticket on device-specific battery behavior.

## Expected implementation changes on THIS PR

- `pubspec.yaml`, `pubspec.lock`
- `lib/game/storage_alerts.dart` (new)
- `lib/mining/site_deck_view.dart`
- `lib/mining/presentation/mining_shell.dart`
- `lib/mining/presentation/mining_settings_sheet.dart`
- `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, iOS plugin lockfile if changed
- Tests for the service, projection, shell, and Settings
- `CLAUDE.md`
- This proposed design and plan, updated to implemented status after coding

## Must remain unchanged

`MiningController` behavior/API, `MiningSimulation`, `MiningSave`, `MiningSaveRepository`, authored mining content, and all art/SFX. Do not build a push service, new scheduler framework, clock abstraction outside the existing shell, or additional tickets/PRs for technical layers.

## Practical risks to check during implementation

1. **Checkpoint race:** the existing `_checkpoint()` returns void; merely chaining schedule after it does not await persistence. Test rapid pause/resume.
2. **Native toolchain:** latest plugin README may require Java 17/desugaring; the app's current Android app module is Java 11. Validate exact pinned version against current Flutter/AGP, not memory.
3. **Notification icon:** existing `@mipmap/ic_launcher` avoids new art but should be smoke-tested on Android release; prefer a valid existing drawable if available.
4. **Permission semantics:** a user denial is not an error or a reason to reprompt automatically. Explain how to re-enable via OS settings if needed, without adding an in-app permission management flow.
