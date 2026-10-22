# HPA-178 Storage-Full Alerts Design

- Date: 2026-10-22
- Status: Proposed
- Linear: [HPA-178](https://linear.app/cwchanap/issue/HPA-178/mining-retention-notify-the-player-when-site-storage-fills-while-away) — Notify the player when site storage fills while away
- Baseline: `main` at `15fd4c0`

## Problem

HPA-401 made time away pay: every site stores two hours of base production, and offline accrual runs for up to 24 hours. The best moment to come back is when storage fills, because production stops there. The game gives no signal for that moment outside the app, so players either check too early or lose hours of production.

## Goal

> Leave the app → one local notification arrives when the first site's storage is full → tap it → the game opens and the offline-return sheet shows the haul.

## Non-goals

This work does not add:

- push notifications, a server, or Firebase;
- more than one pending notification, repeating reminders, or "come back" nags;
- notifications on web or desktop;
- a notification for anything other than storage filling (planet unlocks, research, rewards);
- a save change, or any notification code in mining logic;
- custom notification sounds or icons (it uses the app icon and the platform sound).

## Design

### 1. When storage fills is a pure function

```dart
/// The earliest moment a producing site on any unlocked planet reaches
/// capacity, or null when nothing is producing or every producing site is
/// already full.
({MiningSiteId site, DateTime atUtc})? nextStorageFull(
  MiningContentRegistry content,
  MiningSave state,
  DateTime nowUtc,
);
```

It lives in `lib/mining/site_deck_view.dart` beside `SiteMetrics` and uses `SiteMetrics.of` for rate and capacity, so it matches the Site Deck's `FULL IN` label exactly. Only unlocked planets and sites with rigs count, which is exactly what `MiningSimulation` accrues. It reads no clock and no device state.

The 24-hour offline cap does not matter: storage fills within about four hours at most (HPA-401), long before the cap.

### 2. One shell-owned service

`StorageAlerts` in `lib/game/storage_alerts.dart`, owned by `MiningShell` the way `AudioManager` is:

```dart
class StorageAlerts {
  StorageAlerts({StorageAlertPlatform? platform});
  bool get enabled;                 // preference, default true
  Future<void> loadPrefs();
  Future<void> setEnabled(bool value);
  Future<void> requestPermissionOnce();
  Future<void> schedule({required String siteName, required DateTime atUtc});
  Future<void> cancel();
}
```

- `StorageAlertPlatform` is a three-method seam (`requestPermission`, `scheduleAt`, `cancelAll`) with one real implementation over `flutter_local_notifications` and a fake in tests. On web and desktop the real implementation does nothing.
- It owns two preference keys, `notifications.storageFullEnabled` (default true) and `notifications.permissionAsked`, next to the existing `audio.*` keys. Neither touches the mining save.
- `schedule` replaces any pending alert (one fixed notification id) and does nothing when disabled.

### 3. Lifecycle

| Shell event | Alerts |
| --- | --- |
| Initialization finishes | `cancel()` (a cold start after a tap must not leave a stale alert) |
| `inactive` / `paused`, after the existing checkpoint | `schedule(...)` from `nextStorageFull(content, controller.state, now)`, or `cancel()` when it returns null |
| `resumed` | `cancel()` |
| `dispose` | nothing; an alert scheduled on pause should still fire after the app is killed |

Android schedules inexactly (`AndroidScheduleMode.inexactAllowWhileIdle`), so the app needs no exact-alarm permission and the alert may land a few minutes late. That is fine for a two-hour window.

### 4. Permission

The shell calls `requestPermissionOnce()` right after the first successful deploy that commissions a site, which is the moment storage first means something. It asks at most once, ever. If the player declines, scheduling is silently a no-op on the platform side.

### 5. Settings

The Settings sheet gains a `NOTIFICATIONS` group with one switch, `Storage full alerts`, shown only on Android and iOS. Turning it off cancels any pending alert. Turning it on calls `requestPermissionOnce()` if the permission was never asked.

### 6. Copy

- Title: `<Site name> storage is full`
- Body: `Sell your cargo to keep mining.`

Tapping the notification just opens the app; the existing resume path shows the offline-return sheet.

## Platform setup

- `pubspec.yaml`: `flutter_local_notifications` and `timezone` (scheduling takes a `TZDateTime`; the service schedules in `tz.UTC`, so no device time-zone lookup is needed).
- Android: core library desugaring in `android/app/build.gradle.kts`, `POST_NOTIFICATIONS` and the plugin's scheduled-notification receiver in `AndroidManifest.xml`, all per the plugin README for the pinned version. The Android small icon is the existing `@mipmap/ic_launcher`, so no new art.
- iOS: permission is requested through the plugin; no `Info.plist` key is needed for local notifications.

## Testing

- **Fill time:** nothing producing → null; a single rigged site → `now + (capacity - cargo) / rate`; the earliest of several sites across two planets wins; a full site is skipped; a locked planet's rigs are ignored; the result matches `MiningSiteCardView.timeToFull` for the same site.
- **Service (fake platform):** default enabled; schedule replaces the previous alert; disabled → schedule is a no-op and `setEnabled(false)` cancels; `requestPermissionOnce` asks once across two service instances (preference persisted).
- **Shell (fake service):** pause schedules for the earliest site with the right name and time; resume cancels; pause with nothing producing cancels; initialization cancels; the first commissioning requests permission once.
- **Settings:** the switch appears with an injected mobile platform flag, toggles the preference, and fits at 360×640.
- **Gates:** the full repository gates, including `flutter build apk --debug` and `flutter build ios --simulator --debug`, which prove the native setup compiles. A manual check on a phone (background the app, wait for the alert) is worth doing for feel but is not a merge gate.

## Risks

- **Native setup drift.** Plugin setup steps change between major versions. Follow the README for the pinned version, and let the apk and iOS builds catch mistakes.
- **Inexact timing.** Android may batch the alert. Acceptable for a two-hour window; exact alarms are not worth the extra permission.
- **Web tests.** The real platform is never constructed under `flutter test`; the shell takes the service as an optional parameter like `audioManager`, and the default constructs the no-op on web.

## Assets

None. Uses the app icon and the platform's default sound.
