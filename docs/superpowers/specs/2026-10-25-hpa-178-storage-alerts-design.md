# HPA-178 — Storage-full local notification: design

- Status: Proposed; revised after PR #49 reviews (2026-10-26)
- Linear: https://linear.app/cwchanap/issue/HPA-178/mining-retention-notify-the-player-when-site-storage-fills-while-away
- Prior planning PR (closed, not merged): https://github.com/cwchanap/horologium/pull/43
- Delivery: this draft PR is the **single implementation PR** for HPA-178. Implementation follows review on this same branch.

## Player outcome

When the first producing site's storage fills while the app is away, a **single local notification** tells the player which planet needs selling. Tapping opens the normal app and its existing offline-return flow. No additional retention subsystem.

## Reuse boundaries

- `MiningShell` owns lifecycle, the injected controller clock, first-commission action success, and Settings navigation; do not introduce another clock field.
- `MiningController.checkpoint()` already queues/awaits mutations, accrues and saves; `MiningSimulation` remains authoritative. No new persistence path.
- `SiteMetrics.of` computes rate, capacity and operational state; `MiningSiteCardView.timeToFull` already displays the duration.
- `MiningSave.lastAccruedAtUtc` is the projection's time anchor **after checkpoint**; `MiningContentRegistry.planetForSite` gives the planet of the selected site.
- `AudioManager` provides a small shell-owned preference/serialized-operation pattern; `MiningSettingsSheet` already has a switch style.

Do not change the controller, simulation, save/repository, content, or any gameplay mutation boundary.

## 1. One shared fill-time calculation

In `lib/mining/site_deck_view.dart`, move the existing microsecond-ceiling formula to `SiteMetrics.timeToFull(double cargo)`, returning null unless the site is operational, rate is positive and storage is not yet full. `MiningSiteCardView.timeToFull` delegates to this method using its existing displayed fields. `nextStorageFull` uses the exact same method; don't copy the arithmetic or add a redundant separate parity test.

```dart
({MiningSiteId site, DateTime atUtc})? nextStorageFull(
  MiningContentRegistry content,
  MiningSave state,
);
```

Iterate `content.planets.entries` as `MiningSimulation.accrue` does, skipping locked planets. Traverse each planet's authored sites, skipping locked, uncommissioned, unrigged, already-full or nonproducing sites. Use `SiteMetrics.of` and `SiteMetrics.timeToFull(progress.storedAmount)`. Select the earliest `state.lastAccruedAtUtc.toUtc().add(duration)`; strict `<` comparison retains authored-order ties. Use only the **post-checkpoint state** in the shell; an out-of-date snapshot may otherwise produce a past alert time.

Because rate/capacity are constant between gameplay mutations and offline production is linear and clamped, accrual advances `lastAccruedAtUtc` and cargo together; the predicted full instant is stable. Sites normally fill well inside the 24-hour accrual cap. Successful mutations are queued before checkpoint so the calculation picks up an in-flight sale without new state.

## 2. Shell-owned service, one adapter

`lib/game/storage_alerts.dart`:

```dart
abstract interface class StorageAlertPlatform {
  Future<bool> requestPermission();
  Future<void> scheduleAt({
    required String title,
    required String body,
    required DateTime atUtc,
  });
  Future<void> cancelAll();
}

class StorageAlerts {
  StorageAlerts({StorageAlertPlatform? platform});
  bool get supported;
  bool get enabled;
  Future<void> loadPrefs();
  Future<void> setEnabled(bool value);
  Future<void> requestPermissionOnce();
  Future<bool> requestPermission();
  Future<void> schedule({
    required String siteName,
    required String planetName,
    required DateTime atUtc,
  });
  Future<void> cancel();
}
```

- One **adapter-owned** fixed notification ID and Android channel. A second schedule replaces the same pending alert. No id parameter on the abstraction: there is only one configured value.
- `StorageAlertPlatform?` is null on web/desktop, real on Android/iOS, and fake in tests. `supported => _platform != null`; unsupported service methods return harmlessly. No no-op adapter subclass or visibility flag.
- Two independent preferences: `notifications.storageFullEnabled` (default true) and `notifications.permissionAsked`. Neither goes in the mining save. `setEnabled(false)` persists and cancels queued/pending alerts.
- `requestPermissionOnce()` is **guarded by enabled and supported**. It asks once ever on the first successful commissioning and records the attempt even if declined. Disabled-before-commission never prompts. The explicit Settings-on action calls `requestPermission()` regardless of `permissionAsked`; an OS denial returns false and displays feedback. No automatic re-prompt.
- Serialize platform scheduling/cancellation through a single chained Future (the small existing AudioManager queue pattern), so a resumed-app cancellation cannot overtake an in-flight schedule. No separate scheduler or retries.
- Lazy plugin initialization must not ask permission. Use `flutter_local_notifications` with `AndroidScheduleMode.inexactAllowWhileIdle`, `tz.TZDateTime.from(atUtc, tz.UTC)`, and the default sound; no exact-alarm permission or device timezone discovery. `tz.UTC` is a built-in location; confirm the selected dependency/plugin version accepts UTC scheduling without loading a named-zone database before omitting `initializeTimeZones()`. If not, initialize only what is required.
- Title `<Site> on <Planet> is full`; body `Sell its cargo to keep mining.` Tapping follows normal app launch, not custom deep links. The planet is necessary because selling empties only the active planet.

## 3. Shell lifecycle with no extra state

Today `MiningShell._checkpoint()` is a fire-and-forget `void` wrapper while `MiningController.checkpoint()` already returns a Future. Change the wrapper to `Future<void>`, preserving best-effort error handling; call `unawaited(_checkpoint(accrue: false))` on dispose.

- On `inactive`/`paused`, stop refresh as today; invoke `_checkpoint().whenComplete(_scheduleStorageAlert)`. The callback reads the latest `_controller.state` **after the queued checkpoint**, then schedules or cancels from `nextStorageFull`. There is no second accrual.
- Before scheduling, require mounted/initialized and a **current background lifecycle state**, not `resumed`; check `WidgetsBinding.instance.lifecycleState` after the await. This is enough for the normal slow-checkpoint/resume race and avoids storing a duplicate lifecycle token. `inactive`→`paused` may yield duplicate attempts, but both replace the same fixed ID with the same predicted fill time.
- On `resumed`, cancel through the serialized service queue and retain the existing `_resumeMining()`/offline-return behavior.
- After initialization, cancel stale alerts. **Do not cancel on dispose**: a background-scheduled alert should survive termination.
- Reuse the already-computed `commissioned` transition in `_runSheetAction` for the first-commission permission request. `StorageAlerts.requestPermissionOnce()` handles the enabled guard. No permission prompt at launch or after failed deploy.

Keep lifecycle sequencing inside a small private shell method; do not add another service/state owner.

## 4. Settings and native setup

- Add one `NOTIFICATIONS` section and `Storage full alerts` switch (`Key('mining-storage-alerts-switch')`) to `MiningSettingsSheet` with the existing styling. Render only if `storageAlerts.supported`, which injected fake-platform tests can exercise. The 360×640 portrait sheet must remain scrollable and overflow-free.
- Turning alerts off persists and cancels. Turning them on persists enabled and calls explicit `requestPermission()` even if the automatic attempt was previously declined. If false, show: `Notifications are off for Horologium in system settings.` Keep no new permission-management UI.
- Select compatible `flutter_local_notifications` and direct `timezone` dependency versions, commit `pubspec.lock`, and configure native platforms **in the same implementation step** as adding the plugin. Current AGP is 8.11.1 and app module Java/Kotlin is 11; follow the pinned plugin's requirements for Java 17/desugaring/`desugar_jdk_libs` and compileSdk.
- Android manifest: notification permission and scheduled-notification receiver; no exact-alarm permission. Use existing launcher icon only if the pinned plugin accepts it as the small icon; fix with an existing compatible drawable if not. No new art.
- iOS: explicit permission via the plugin, no push capabilities or special deep link.

## Acceptance

1. Projection: none, one, multiple planets, locked/full/idle/no-rig exclusions, authored tie, and existing Site Deck fill-time tests still passing using the shared method. No dedicated duplicate parity test needed.
2. Service fake: default/persisted prefs, no automatic permission when disabled, once-ever automatic attempt, explicit Settings request after denial, one fixed-ID replacement, serialized schedule/cancel order, unsupported null-platform behavior, and planet-aware copy.
3. Shell: first successful commission requests only when enabled; pause schedules, no-producer pause cancels, init/resume cancel; slow checkpoint→resume gives no late schedule; inactive→paused has one effective pending alert; an in-flight sale changes the projection; dispose does not cancel.
4. Settings: service-driven support visibility, denied-permission message, off cancels, 360×640 layout.
5. Task 2 native builds pass before lifecycle/Settings work: Android APK/web builds; iOS simulator on the existing macOS CI runner. Then all repository test, analysis and build gates.

## Non-goals and limits

No server/push/Firebase, repeated/multiple notifications, exact alarms, background Dart timers, new game state, currency or persistence, migrations, UI permission wizard, custom art/SFX, or further tickets/PRs for technical layers. Android inexact scheduling or OS permission/battery restrictions can delay/suppress delivery; optional real-phone smoke test is not a merge gate.
