import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/storage_alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../support/fake_storage_alert_platform.dart';

/// Platform fake whose permission request always fails, covering the
/// service-level catch that turns platform errors into a denied answer.
class _ThrowingStorageAlertPlatform implements StorageAlertPlatform {
  @override
  Future<bool> requestPermission() async => throw Exception('platform error');

  @override
  Future<void> scheduleAt({
    required String title,
    required String body,
    required DateTime atUtc,
  }) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('StorageAlerts defaults', () {
    test(
      'enabled defaults to true and supported follows the platform',
      () async {
        final platform = FakeStorageAlertPlatform();
        final alerts = StorageAlerts(platform: platform);

        expect(alerts.supported, isTrue);
        expect(alerts.enabled, isTrue);

        await alerts.loadPrefs();

        expect(alerts.enabled, isTrue);
        expect(platform.requestPermissionCount, 0);
      },
    );

    test('loadPrefs reads persisted values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'notifications.storageFullEnabled': false,
        'notifications.permissionAsked': true,
      });
      final platform = FakeStorageAlertPlatform();
      final alerts = StorageAlerts(platform: platform);

      await alerts.loadPrefs();

      expect(alerts.enabled, isFalse);
      expect(platform.requestPermissionCount, 0);
    });

    test('setEnabled persists the preference', () async {
      final alerts = StorageAlerts(platform: FakeStorageAlertPlatform());

      await alerts.setEnabled(false);
      await flush();
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notifications.storageFullEnabled'), isFalse);
      expect(alerts.enabled, isFalse);

      await alerts.setEnabled(true);
      await flush();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notifications.storageFullEnabled'), isTrue);
      expect(alerts.enabled, isTrue);
    });
  });

  group('StorageAlerts.requestPermissionOnce', () {
    test('does not request when disabled before the auto prompt', () async {
      final platform = FakeStorageAlertPlatform();
      final alerts = StorageAlerts(platform: platform)..loadPrefs();

      await alerts.setEnabled(false);
      await alerts.requestPermissionOnce();

      expect(platform.requestPermissionCount, 0);
    });

    test(
      'asks exactly once across service recreation even when denied',
      () async {
        final denied = FakeStorageAlertPlatform(grants: false);
        final first = StorageAlerts(platform: denied);
        await first.loadPrefs();

        await first.requestPermissionOnce();

        expect(denied.requestPermissionCount, 1);
        // A denied prompt flips the preference off: claiming enabled while
        // the OS refuses delivery would lie to the player.
        expect(first.enabled, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('notifications.permissionAsked'), isTrue);

        final fresh = FakeStorageAlertPlatform();
        final second = StorageAlerts(platform: fresh);
        await second.loadPrefs();
        await second.requestPermissionOnce();

        // No prompt on the recreated service: the recorded attempt suffices.
        expect(fresh.requestPermissionCount, 0);
      },
    );
  });

  group('StorageAlerts.requestPermission', () {
    test(
      'explicit re-request after denial asks again and reports false',
      () async {
        final platform = FakeStorageAlertPlatform(grants: false);
        final alerts = StorageAlerts(platform: platform);
        await alerts.loadPrefs();

        await alerts.requestPermissionOnce();
        final granted = await alerts.requestPermission();

        expect(granted, isFalse);
        expect(platform.requestPermissionCount, 2);
      },
    );

    test('returns true when granted', () async {
      final platform = FakeStorageAlertPlatform(grants: true);
      final alerts = StorageAlerts(platform: platform);

      final granted = await alerts.requestPermission();

      expect(granted, isTrue);
      expect(platform.requestPermissionCount, 1);
    });

    test('a denial turns the preference off, persists, and cancels', () async {
      final platform = FakeStorageAlertPlatform(grants: false);
      final alerts = StorageAlerts(platform: platform);
      await alerts.loadPrefs();

      final granted = await alerts.requestPermission();
      await flush();

      expect(granted, isFalse);
      expect(alerts.enabled, isFalse);
      expect(platform.cancelAllCount, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notifications.storageFullEnabled'), isFalse);
      expect(prefs.getBool('notifications.permissionAsked'), isTrue);
    });

    test('permission requests are serialized behind the op queue', () async {
      final platform = FakeStorageAlertPlatform()
        ..permissionGate = Completer<void>();
      final alerts = StorageAlerts(platform: platform);
      await alerts.loadPrefs();

      final first = alerts.requestPermission();
      final second = alerts.requestPermission();
      await flush();
      // The second request cannot overlap the first: a concurrent pair on
      // Android throws and would be misreported as a denial.
      expect(platform.requestPermissionCount, 1);

      platform.permissionGate!.complete();
      await flush();
      await first;
      await second;
      await flush();
      expect(platform.requestPermissionCount, 2);
    });
  });

  group('StorageAlerts schedule and cancel', () {
    test('cancel-on-disable clears the pending alert', () async {
      final platform = FakeStorageAlertPlatform();
      final alerts = StorageAlerts(platform: platform);
      await alerts.loadPrefs();

      await alerts.schedule(
        siteName: 'Landing Basin',
        planetName: 'Homeworld',
        atUtc: DateTime.utc(2026, 11, 1, 12, 30),
      );
      await alerts.setEnabled(false);

      expect(platform.scheduleCount, 1);
      expect(platform.cancelAllCount, 1);
    });

    test('does not schedule when disabled', () async {
      final platform = FakeStorageAlertPlatform();
      final alerts = StorageAlerts(platform: platform);
      await alerts.loadPrefs();
      await alerts.setEnabled(false);

      await alerts.schedule(
        siteName: 'Landing Basin',
        planetName: 'Homeworld',
        atUtc: DateTime.utc(2026, 11, 1, 12, 30),
      );

      expect(platform.scheduleCount, 0);
    });

    test('composes planet-aware title and body verbatim', () async {
      final platform = FakeStorageAlertPlatform();
      final alerts = StorageAlerts(platform: platform);
      final atUtc = DateTime.utc(2026, 11, 1, 12, 30);

      await alerts.schedule(
        siteName: 'Landing Basin',
        planetName: 'Lunar Frontier',
        atUtc: atUtc,
      );

      expect(
        platform.scheduledTitle,
        'Landing Basin on Lunar Frontier is full',
      );
      expect(platform.scheduledBody, 'Sell its cargo to keep mining.');
      expect(platform.scheduledAtUtc, atUtc);
    });

    test('each schedule replaces the single pending request', () async {
      final platform = FakeStorageAlertPlatform();
      final alerts = StorageAlerts(platform: platform);
      final firstFill = DateTime.utc(2026, 11, 1, 12, 30);
      final secondFill = DateTime.utc(2026, 11, 1, 15, 45);

      await alerts.schedule(
        siteName: 'Landing Basin',
        planetName: 'Homeworld',
        atUtc: firstFill,
      );
      await alerts.schedule(
        siteName: 'Frozen Basin',
        planetName: 'Mars Frontier',
        atUtc: secondFill,
      );

      expect(platform.scheduleCount, 2);
      expect(platform.scheduledTitle, 'Frozen Basin on Mars Frontier is full');
      expect(platform.scheduledAtUtc, secondFill);
    });

    test('cancel cannot overtake an in-flight schedule', () async {
      final platform = FakeStorageAlertPlatform()
        ..scheduleGate = Completer<void>();
      final alerts = StorageAlerts(platform: platform);
      await alerts.loadPrefs();

      final scheduled = alerts.schedule(
        siteName: 'Landing Basin',
        planetName: 'Homeworld',
        atUtc: DateTime.utc(2026, 11, 1, 12, 30),
      );
      await flush();
      expect(platform.scheduleCount, 1);

      final cancelled = alerts.cancel();
      await flush();
      expect(platform.cancelAllCount, 0);

      platform.scheduleGate!.complete();
      await scheduled;
      await flush();
      expect(platform.cancelAllCount, 1);
      await cancelled;
    });
  });

  group('StorageAlerts platform failures', () {
    test(
      'requestPermission survives a platform error and reports false',
      () async {
        final alerts = StorageAlerts(platform: _ThrowingStorageAlertPlatform());

        final granted = await alerts.requestPermission();
        await flush();

        expect(granted, isFalse);
        // The attempt is still recorded so the auto prompt never re-asks.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('notifications.permissionAsked'), isTrue);
      },
    );
  });

  group('StorageAlerts unsupported platform', () {
    test(
      'web and desktop platforms get no platform and no-op methods',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final alerts = StorageAlerts();

        expect(alerts.supported, isFalse);
        await alerts.loadPrefs();
        await alerts.setEnabled(false);
        await alerts.schedule(
          siteName: 'Landing Basin',
          planetName: 'Homeworld',
          atUtc: DateTime.utc(2026, 11, 1, 12, 30),
        );
        await alerts.cancel();
        await alerts.requestPermissionOnce();

        expect(await alerts.requestPermission(), isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('notifications.storageFullEnabled'), isFalse);
      },
    );
  });

  group('UTC scheduling', () {
    test('tz.UTC is built in and needs no zone database', () {
      final atUtc = DateTime.utc(2026, 11, 1, 12, 30, 15);

      final scheduled = tz.TZDateTime.from(atUtc, tz.UTC);

      expect(scheduled.location, same(tz.UTC));
      expect(scheduled.microsecondsSinceEpoch, atUtc.microsecondsSinceEpoch);
      expect(scheduled.isUtc, isTrue);
    });
  });
}
