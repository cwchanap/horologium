# HPA-178 Storage-Full Alerts Implementation Plan

- Date: 2026-10-22
- Linear: [HPA-178](https://linear.app/cwchanap/issue/HPA-178/mining-retention-notify-the-player-when-site-storage-fills-while-away)
- Design: `docs/superpowers/specs/2026-10-22-hpa-178-storage-full-alerts-design.md`

## Delivery rule

One ticket = one PR. Planning lands first on this draft PR; implementation lands on the same PR after plan review. No art or SFX.

## Task 1: Fill-time function

### Production

- `lib/mining/site_deck_view.dart`: add top-level `nextStorageFull(content, state, nowUtc)` returning `({MiningSiteId site, DateTime atUtc})?`. Loop unlocked planets in authored order and their sites; skip sites without rigs or already at capacity; use `SiteMetrics.of` for rate and capacity; keep the earliest; ties go to the first in authored order.

### Tests

- `test/mining/site_deck_view_test.dart`, new group `nextStorageFull`: the six cases in the design's Testing section, including parity with `MiningSiteCardView.timeToFull`.

```sh
flutter test test/mining/site_deck_view_test.dart
```

## Task 2: Service and platform seam

### Production

- `pubspec.yaml`: add `flutter_local_notifications` and `timezone` at their current stable versions; `flutter pub get`.
- `lib/game/storage_alerts.dart`:
  - `abstract interface class StorageAlertPlatform { Future<bool> requestPermission(); Future<void> scheduleAt({required int id, required String title, required String body, required DateTime atUtc}); Future<void> cancelAll(); }`
  - `LocalStorageAlertPlatform` over `FlutterLocalNotificationsPlugin`: lazy `initialize` with `AndroidInitializationSettings('@mipmap/ic_launcher')` and Darwin settings that do not request permission on init; `zonedSchedule` with `tz.TZDateTime.from(atUtc, tz.UTC)` and `AndroidScheduleMode.inexactAllowWhileIdle`; Android and iOS permission requests through the platform-specific implementations.
  - `NoopStorageAlertPlatform` for web and desktop; `StorageAlertPlatform.forCurrentPlatform()` picks it when `kIsWeb` or not Android/iOS.
  - `StorageAlerts` with the API in design section 2 and the two preference keys.

### Tests

- `test/game/storage_alerts_test.dart` with a recording fake platform and `SharedPreferences.setMockInitialValues`: default enabled; schedule forwards title, body, and time with one fixed id; a second schedule replaces the first; disabled schedule is a no-op; `setEnabled(false)` cancels and persists; `requestPermissionOnce` calls the platform once across two instances.

```sh
flutter test test/game/storage_alerts_test.dart
```

## Task 3: Shell, Settings, and native setup

### Production

- `lib/mining/presentation/mining_shell.dart`:
  - optional `StorageAlerts? storageAlerts` parameter, owned and created like `audioManager`;
  - `_initialize`: `await _storageAlerts.loadPrefs()`, and after the controller initializes, `cancel()`;
  - `didChangeAppLifecycleState`: on `inactive`/`paused`, after the checkpoint, compute `nextStorageFull` from `_controller.state` and schedule with the site's name, or cancel when null; on `resumed`, cancel;
  - after a successful deploy whose result moved the commissioned-site count from 0 to 1, `unawaited(_storageAlerts.requestPermissionOnce())`.
- `lib/mining/presentation/mining_settings_sheet.dart`: take `StorageAlerts` and a `showNotifications` flag (default from the current platform); add the `NOTIFICATIONS` group with `Key('mining-storage-alerts-switch')`.
- `android/app/build.gradle.kts`: enable core library desugaring and add the `desugar_jdk_libs` dependency the plugin README names.
- `android/app/src/main/AndroidManifest.xml`: `POST_NOTIFICATIONS` permission and the plugin's `ScheduledNotificationReceiver`.

### Tests

- `test/mining/presentation/mining_shell_test.dart`, with a fake `StorageAlerts` (or the real one over the fake platform): pause schedules the earliest site's name and time; resume cancels; pause with nothing producing cancels; initialization cancels; the first commissioning requests permission once and a second does not.
- `test/mining/presentation/mining_settings_sheet_test.dart`: switch hidden by default under test, shown with `showNotifications: true`, toggles the preference, no overflow at 360×640.

```sh
flutter test test/mining/presentation
```

## Task 4: Docs and gates

- `CLAUDE.md`, Audio section or a new short "Notifications" paragraph: "`StorageAlerts` owns local notifications and its `notifications.*` preferences; the shell schedules one storage-full alert on pause from `nextStorageFull` and cancels it on resume and initialization. Mining code never touches the plugin."
- Mark the design `- Status: Implemented`.

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

The apk and iOS builds are the proof that the native setup compiles. In the cloud session they run in CI.

## Expected changed paths

Planning (this draft PR as opened):

- `docs/superpowers/specs/2026-10-22-hpa-178-storage-full-alerts-design.md`
- `docs/superpowers/plans/2026-10-22-hpa-178-storage-full-alerts.md`

Implementation (same PR, after review):

- `pubspec.yaml`, `pubspec.lock`
- `lib/game/storage_alerts.dart` (new)
- `lib/mining/site_deck_view.dart`
- `lib/mining/presentation/mining_shell.dart`, `mining_settings_sheet.dart`
- `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- possibly `ios/Podfile.lock` and generated plugin registrants
- `test/game/storage_alerts_test.dart` (new), `test/mining/site_deck_view_test.dart`, `test/mining/presentation/mining_shell_test.dart`, `mining_settings_sheet_test.dart`
- `CLAUDE.md`

No change to the controller, simulation, repository, save, or content.
