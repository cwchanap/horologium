# HPA-178 — Storage-full local notification: design

- Status: Proposed (2026-10-25)
- Linear: https://linear.app/cwchanap/issue/HPA-178/mining-retention-notify-the-player-when-site-storage-fills-while-away
- Prior planning PR (closed, not merged): https://github.com/cwchanap/horologium/pull/43
- This draft PR is the **one implementation PR** for HPA-178; code follows plan review on the same branch.

## Player outcome

A player leaves a producing mine, receives **one** local alert around the time the first site's storage fills, and returns through the existing resume/offline-return flow. This is a cue to sell, not a new retention subsystem.

## Existing boundaries to reuse

- `MiningShell` owns lifecycle, timer, injected `nowUtc`, action success, and Settings navigation.
- `MiningController.checkpoint()` is the sole lifecycle save/accrual path; `MiningSimulation` is authoritative production.
- `SiteMetrics.of` in `lib/mining/site_deck_view.dart` computes rate/capacity/card state; `MiningSiteCardView.timeToFull` is the visible reference.
- `AudioManager` demonstrates shell ownership and independent SharedPreferences keys.
- `MiningSettingsSheet` already owns the existing audio/accessibility controls and `MiningSheetFrame`.

Do not add a controller method, state owner, server, push API, new save key, or an alternative economy timer.

## 1. Pure next-full projection

```dart
({MiningSiteId site, DateTime atUtc})? nextStorageFull(
  MiningContentRegistry content,
  MiningSave state,
  DateTime nowUtc,
);
```

In `lib/mining/site_deck_view.dart`, traverse `content.planets`/the existing authored planet ordering, **only** planets in `state.unlockedPlanetIds`, then each planet's authored sites. Use `SiteMetrics.of` and each site's `SiteProgress.storedAmount`. Skip uncommissioned/no-rig, nonpositive-rate, nonpositive-capacity, or already-full sites. Compute:

```text
timeToFull = ceil((capacity - storedAmount) / rate * 1,000,000) microseconds
atUtc = nowUtc.toUtc() + timeToFull
```

Choose the earliest timestamp; ties retain the first authored site. No clock, platform, or preference access; no simulation mutation. This must equal the card's `timeToFull` duration when evaluated on the same state snapshot.

## 2. One shell-owned service and tiny platform seam

`lib/game/storage_alerts.dart`:

```dart
abstract interface class StorageAlertPlatform {
  Future<bool> requestPermission();
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime atUtc,
  });
  Future<void> cancelAll();
}

class StorageAlerts {
  StorageAlerts({StorageAlertPlatform? platform});
  bool get enabled;
  Future<void> loadPrefs();
  Future<void> setEnabled(bool value);
  Future<void> requestPermissionOnce();
  Future<void> schedule({required String siteName, required DateTime atUtc});
  Future<void> cancel();
}
```

- One fixed notification ID, one Android notification channel, platform default sound. Re-scheduling replaces the same ID; disabled means no scheduling.
- Own `notifications.storageFullEnabled` (default true) and `notifications.permissionAsked` separately from mining saves. `setEnabled(false)` persists and cancels.
- The real `flutter_local_notifications` adapter is instantiated only for Android/iOS; the web/desktop adapter is no-op. Unit/widget tests inject a fake.
- Lazy plugin initialization, no permissions on initialize; explicit permission through platform-specific request. A declined permission does not trigger repeated prompts.
- Android `zonedSchedule` with `AndroidScheduleMode.inexactAllowWhileIdle`; initialize the `timezone` database and use `tz.UTC`. No exact-alarm request or timezone-detection package. Inexact Android delivery is explicitly acceptable.
- Title: `<Site name> storage is full`. Body: `Sell your cargo to keep mining.`. Tapping uses the normal app launch; no deep-link navigation.

## 3. Shell lifecycle — address current async behavior

Current `MiningShell._checkpoint()` is `void` and fire-and-forget, so a call **after** `_checkpoint()` is *not* necessarily after persistence/accrual. Also, mobile can deliver `inactive` and `paused` in sequence.

- Retain the shell's injected clock as a field so notification projections use the same time source as controller actions.
- On `inactive` or `paused`: stop foreground refresh; run the existing controller checkpoint **once for that event**, await its best-effort completion, then derive `nextStorageFull` from the resulting authoritative controller state and schedule/cancel. Avoid an additional independent accrual.
- Use a small monotonic lifecycle generation token. After each `await`, schedule only if still mounted, initialized, and still backgrounded with the current token. This prevents a slow background checkpoint from scheduling **after** resume. An inactive→paused sequence lets only the latest completion schedule.
- On `resumed`: invalidate pending background scheduling, immediately cancel the local alert, and preserve the existing `_resumeMining()` flow/offline sheet.
- After initialization: cancel any stale pending alert.
- On dispose: **do not cancel** the scheduled notification; the app may be terminated in the background.
- When a successful deploy first transitions any site to commissioned, call `requestPermissionOnce()` without delaying gameplay; no permission request on app launch.

Prefer a small private shell method for this lifecycle orchestration, not another service or cross-layer dependency.

## 4. Settings and platforms

- Add `NOTIFICATIONS` / `Storage full alerts` to `MiningSettingsSheet`, using the current styling, key `mining-storage-alerts-switch`, and the existing sheet layout. Show on Android/iOS only (inject the visibility flag in tests). On -> ask only if never asked; off -> cancel.
- Add stable compatible `flutter_local_notifications` and `timezone` dependencies and commit the lockfile.
- Current Android `settings.gradle.kts` has AGP 8.11.1 already. Current `android/app/build.gradle.kts` is Java/Kotlin 11; follow the **selected plugin version's** README for its required Java compatibility (latest documented setup uses Java 17), desugaring, and `desugar_jdk_libs`. Check `compileSdk` meets the plugin minimum.
- In AndroidManifest add notification permission and `ScheduledNotificationReceiver` as required for one-shot delivery. No exact-alarm permission. Use existing launcher icon initially, with release icon check; no new artwork or SFX in this ticket.
- On iOS use the plugin's explicit notification authorization; no push capability, Firebase, or special notification deep links.

## Acceptance

1. Projection: none, single site, multi-planet earliest, full/locked/idle exclusions, authored tie, and `timeToFull` parity.
2. Service with fake adapter: preferences default/persistence, permission once across fresh instances, fixed-ID replacement, disabled skip, cancellation, expected content.
3. Shell: first successful commission asks; pause schedules; no-producer pause cancels; initialization/resume cancel; rapid pause→resume prevents late scheduling; disposal keeps a scheduled alert.
4. Settings: mobile-only switch and 360×640 overflow check.
5. `flutter analyze`, focused/full tests, Chrome tests, Android debug build, web build, and iOS simulator debug build pass in the supported CI hosts.

## Explicit non-goals

Remote or repeating notifications, multiple pending reminders, Android exact alarms, custom icons or sounds, background Dart execution, iOS/Android-specific deep links, migration/compatibility, any modification to controller/simulation/save/repository/content. No art or SFX task is mixed into this coding ticket.

## Limitations

Inexact Android alarms may arrive late and OS-level permission/battery restrictions may suppress delivery. Local CI/unit tests establish derivation, wiring and native compilation; a real-device notification appearance check is optional product validation, not a merge gate.
