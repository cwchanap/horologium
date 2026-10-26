# HPA-178 — Storage-full alerts implementation plan

- Status: Proposed; revised after PR #49 reviews (2026-10-26)
- Ticket: https://linear.app/cwchanap/issue/HPA-178/mining-retention-notify-the-player-when-site-storage-fills-while-away
- Design: [2026-10-25-hpa-178-storage-alerts-design.md](../specs/2026-10-25-hpa-178-storage-alerts-design.md)
- Baseline: current `main` at implementation start
- Delivery: **one PR total for this ticket**: spec/plan now, code and tests committed to this same draft PR after review.

## Reuse survey

| Existing code | Reuse rather than introduce |
| --- | --- |
| `SiteMetrics.of` and `MiningSiteCardView.timeToFull` | Move their arithmetic into one `SiteMetrics.timeToFull(cargo)` method; card and projection both call it |
| `MiningSave.lastAccruedAtUtc` | Anchor projected fill timestamp; no injected clock field |
| `MiningController.checkpoint` | Await its existing queued mutation/persistence Future, then project from controller state |
| `MiningShell.didChangeAppLifecycleState` | Check Flutter binding lifecycle after the await; no generation counter |
| `MiningShell._runSheetAction` | Reuse existing commissioned transition for the first permission attempt |
| `AudioManager` | Follow independent preferences and serialized platform-operation queue pattern |
| `MiningSettingsSheet` | Existing switch styles; support derived from `StorageAlerts.supported` |
| CI native build jobs | Android/web CI plus existing macOS iOS-simulator job; no new workflow |

## Task 1 — Pure projection and shared formula

**Production**

- In `lib/mining/site_deck_view.dart`, move the microsecond-ceiling duration formula into `SiteMetrics.timeToFull(double cargo)`.
- Make the existing `MiningSiteCardView.timeToFull` delegate to that method using its displayed fields and operational state.
- Add `nextStorageFull(MiningContentRegistry content, MiningSave state)` beside SiteMetrics. Iterate `content.planets.entries` and authored site order like `MiningSimulation.accrue`; skip locked planet, non-commissioned/unlocked site, no deployed rigs, zero rate/full storage; compare fill timestamps anchored at `state.lastAccruedAtUtc.toUtc()` strictly (stable tie).
- This function takes **no clock parameter** and does not accrue, mutate or persist. Shell calls it only after the queued checkpoint completes.

**Tests**

- Add focused projection cases in `test/mining/site_deck_view_test.dart`: none, one, two planets with different full times, locked/full/idle exclusions and authored ties.
- Keep existing Site Deck `timeToFull` tests, add a null case for a **commissioned site with no rig**, and do not add a redundant dedicated parity test: both consumers use the same method.

Gate: `flutter test test/mining/site_deck_view_test.dart`.

## Task 2 — Service, dependencies AND native configuration together

**Production**

- In `pubspec.yaml`, add compatible versions of `flutter_local_notifications` and direct `timezone` dependency; resolve and commit `pubspec.lock`.
- Add `lib/game/storage_alerts.dart` with `StorageAlerts`, a minimal three-method `StorageAlertPlatform` interface, one concrete Android/iOS plugin adapter and an injected fake for tests.
- `StorageAlertPlatform.scheduleAt` accepts title, body and UTC time, **not an id**. The real adapter owns one fixed notification ID/channel; each schedule replaces the previous request. Serialize schedule/cancel through one Future chain so cancel cannot be overtaken by a pending plugin initialization/schedule.
- Platform factory gives `null` on web/desktop, real plugin on Android/iOS. `StorageAlerts.supported` is `_platform != null`; unsupported methods are no-ops.
- Service prefs: `notifications.storageFullEnabled` (true by default), `notifications.permissionAsked`. `setEnabled(false)` persists/cancels; no scheduling when disabled.
- `requestPermissionOnce()` checks **enabled and supported** before prompting, and persists attempt once even if denied. Explicit `requestPermission()` on Settings-on always asks the platform again and returns `bool` for UI feedback.
- Use `tz.TZDateTime.from(atUtc, tz.UTC)` for an inexact one-shot notification. Check the **selected** `timezone`/plugin versions with a focused UTC test: UTC is built in and a named-zone database should not be loaded unless the implementation genuinely needs it.
- Supply site+planet title and `Sell its cargo to keep mining.` text.
- Update Android app `build.gradle.kts` **in this task**: the selected plugin may need Java/Kotlin 17, desugaring, appropriate SDK and desugar library. Add `POST_NOTIFICATIONS` and plugin scheduled receiver to `AndroidManifest.xml` per pinned README; never request exact-alarm permission.
- Verify iOS plugin registration and explicit notification permission support in this task, not after shell integration.

**Tests**

- `test/game/storage_alerts_test.dart` using fake platform and `SharedPreferences.setMockInitialValues`: enabled/defaults, persisted preferences, disabled-before-auto-prompt does not request permission, auto-prompt exactly once across service recreation, explicit re-request after denial, cancel-on-disable, one fixed-ID replacement semantics, serialized schedule/cancel, null-platform support and planet-aware message.
- Test fake behavior, not arbitrary plugin internals. Add focused UTC construction test only if necessary for selected dependency version.

**Gates for this task (plugin is linked as soon as dependency exists)**

```sh
flutter test test/game/storage_alerts_test.dart
flutter build apk --debug
flutter build web
```

Existing `macos-latest` CI must also compile `flutter build ios --simulator --debug` before proceeding. Do not let the plugin sit broken across Tasks 3–4.

## Task 3 — Shell lifecycle and commissioning

**Production**

- `MiningShell` accepts an optional injected `StorageAlerts?` like `audioManager`, creates its default service once, and loads preferences on init. After controller initialization cancel old notifications.
- Make the shell's private `_checkpoint({accrue})` return `Future<void>`, preserving catch/log behavior (it currently returns void). On dispose call `unawaited(_checkpoint(accrue: false))`; **never cancel the scheduled notification on dispose**.
- In `didChangeAppLifecycleState`, leave the existing foreground timer and audio transitions. On `inactive` and `paused`, call `_checkpoint().whenComplete(_scheduleStorageAlert)`. In that callback, first check mounted/initialized and `WidgetsBinding.instance.lifecycleState` remains backgrounded, then derive from the post-checkpoint `_controller.state` and schedule/cancel.
- On resume cancel via `StorageAlerts` serialized queue, keep `_resumeMining()` exactly as the existing offline-return path. Duplicate inactive→paused callbacks are harmless: the same ID/time gets replaced and operations remain ordered. No extra injected-clock field, generation token, timer, or simulation call.
- Reuse the successful newly-`commissioned` transition already computed by `_runSheetAction` for milestone audio, calling `requestPermissionOnce()` (service handles disabled/no-support). Failed deploy and launch do not prompt.

**Tests**

- Extend `pumpShell` with `storageAlerts` injected fake in `test/mining/presentation/mining_shell_test.dart`.
- Initialization cancels, first successful commission asks if enabled, disabled-before-commission does not prompt, idle/no-producing pause cancels, pause with production schedules earliest across unlocked planets, resume cancels.
- Races: **slow checkpoint then resume → no late schedule**; `inactive`→`paused` → one effective pending alert (fixed ID); **in-flight sale then pause** → projection uses post-sale cargo; dispose → no cancellation.

Gate: `flutter test test/mining/presentation/mining_shell_test.dart`.

## Task 4 — One Settings switch and docs

**Production**

- In `lib/mining/presentation/mining_settings_sheet.dart` accept `StorageAlerts`; add `NOTIFICATIONS` group and `Key('mining-storage-alerts-switch')` using the existing `SwitchListTile` convention. Show only when `storageAlerts.supported` (tests inject a fake platform; no extra visibility flag).
- OFF calls `setEnabled(false)` and cancels. ON calls `setEnabled(true)` and then `requestPermission()` regardless of a previous automatic denial. If false, show one short `SnackBar`: `Notifications are off for Horologium in system settings.` No permission management page.
- Pass the service from `MiningShell.openSettings()`, and keep the existing 360×640 bottom-sheet experience without overflow.
- Update only `CLAUDE.md`: `StorageAlerts` owns `notifications.*`; the shell schedules after checkpoint and cancels on init/resume; mining logic never calls the plugin.

**Tests**

- Extend `test/mining/presentation/mining_settings_sheet_test.dart`: unsupported hidden, fake-platform supported visible, off cancels and persists, on requests again even if previously declined, denial feedback, and no overflow at 360×640.

Gate: `flutter test test/mining/presentation/mining_settings_sheet_test.dart`.

## Task 5 — Complete repository gates, on this PR

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

iOS simulator build must run on existing macOS CI; do not treat passing widget tests as native plugin validation. Optional real-device notification smoke test for UX, not merge blocking. Mark this design and plan implemented only after the code/CI gates actually pass.

## Expected changed paths (single PR)

- `pubspec.yaml`, `pubspec.lock`
- `lib/game/storage_alerts.dart` (new)
- `lib/mining/site_deck_view.dart`
- `lib/mining/presentation/mining_shell.dart`, `mining_settings_sheet.dart`
- `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`; native generated/lockfiles only as needed
- Tests for projection, service, shell and Settings
- `CLAUDE.md`
- These two design/plan documents

## Out of scope and implementation risks

No changes to `MiningController` APIs, `MiningSimulation`, `MiningSave`, `MiningSaveRepository`, mining content, assets or sound. No push/Firebase/exact alarms, new background service or scheduler, OS-permission wizard, backward compatibility work, or extra tickets/PRs.

Risks to test: background/resume and checkpoint ordering; an active sale when app pauses; denied notification permission; Android plugin Java/desugaring compatibility; valid small icon. A single inexact notification may be delayed or dropped by mobile OS battery/notification settings, so don't gate merge on actual-device timing.
