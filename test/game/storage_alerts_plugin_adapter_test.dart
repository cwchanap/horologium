@TestOn('!browser')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/storage_alerts.dart';
import 'package:timezone/timezone.dart' as tz;

/// Channel-mock tests for [PluginStorageAlertPlatform] against the pinned
/// flutter_local_notifications 22.3.3 method-channel contract:
/// channel `dexterous.com/flutter/local_notifications` with the methods
/// `initialize`, `requestNotificationsPermission` (Android),
/// `requestPermissions` (iOS), `zonedSchedule`, and `cancelAll`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  Object? Function(MethodCall call)? responder;

  setUp(() {
    calls.clear();
    responder = null;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return responder?.call(call);
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Android requestPermission passes the OS grant through', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    responder = (_) => true;
    final platform = PluginStorageAlertPlatform();

    expect(await platform.requestPermission(), isTrue);
    expect(
      [for (final call in calls) call.method],
      ['initialize', 'requestNotificationsPermission'],
    );
    // Lazy initialization requests nothing but the monochrome drawable:
    // a colored launcher icon renders as a white square on Android 5+.
    expect(calls[0].arguments, <String, Object>{
      'defaultIcon': '@drawable/ic_notification',
    });
  });

  test(
    'a failed initialization is not cached; the next call retries',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      var attempts = 0;
      responder = (call) {
        if (call.method == 'initialize') {
          attempts++;
          if (attempts == 1) {
            throw PlatformException(code: 'init-failed');
          }
        }
        return true;
      };
      final platform = PluginStorageAlertPlatform();

      await expectLater(platform.requestPermission(), throwsA(anything));
      expect(await platform.requestPermission(), isTrue);
      expect(
        [for (final call in calls) call.method],
        ['initialize', 'initialize', 'requestNotificationsPermission'],
      );
    },
  );

  test('Android requestPermission reports false when the platform resolution '
      'yields no implementation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // A non-Android registration makes the Android resolution return null.
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final platform = PluginStorageAlertPlatform();

    expect(await platform.requestPermission(), isFalse);
    // Initialization itself never reached the channel either.
    expect(calls, isEmpty);
  });

  test('requestPermission is false on unsupported platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final platform = PluginStorageAlertPlatform();

    expect(await platform.requestPermission(), isFalse);
    // Unsupported platforms fall through initialization without a call.
    expect(calls, isEmpty);
  });

  test('iOS requestPermission asks for alert, badge, and sound', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    responder = (_) => true;
    final platform = PluginStorageAlertPlatform();

    expect(await platform.requestPermission(), isTrue);
    expect(
      [for (final call in calls) call.method],
      ['initialize', 'requestPermissions'],
    );
    final request = calls[1].arguments as Map<Object?, Object?>;
    expect(request['alert'], isTrue);
    expect(request['badge'], isTrue);
    expect(request['sound'], isTrue);
    final init = calls[0].arguments as Map<Object?, Object?>;
    // The OS prompt is only ever shown through requestPermission.
    expect(init['requestAlertPermission'], isFalse);
    expect(init['requestBadgePermission'], isFalse);
    expect(init['requestSoundPermission'], isFalse);
  });

  test('iOS requestPermission maps a null platform answer to false', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final platform = PluginStorageAlertPlatform();

    expect(await platform.requestPermission(), isFalse);
  });

  test('scheduleAt posts the fixed alert id on the pinned channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    // Android's initialize is a non-nullable Future<bool>; zonedSchedule and
    // cancelAll ignore the answer.
    responder = (_) => true;
    final platform = PluginStorageAlertPlatform();
    const fillTime = '2099-01-01T12:30:00.000Z';

    await platform.scheduleAt(
      title: 'Landing Basin on Homeworld is full',
      body: 'Sell its cargo to keep mining.',
      atUtc: DateTime.utc(2099, 1, 1, 12, 30),
    );

    expect(
      [for (final call in calls) call.method],
      ['initialize', 'zonedSchedule'],
    );
    final schedule = calls[1].arguments as Map<Object?, Object?>;
    expect(schedule['id'], 178);
    expect(schedule['title'], 'Landing Basin on Homeworld is full');
    expect(schedule['body'], 'Sell its cargo to keep mining.');
    expect(schedule['timeZoneName'], tz.UTC.name);
    expect(schedule['scheduledDateTimeISO8601'], fillTime);
    final specifics = schedule['platformSpecifics'] as Map<Object?, Object?>;
    expect(specifics['channelId'], 'horologium.storageFull');
    expect(specifics['channelName'], 'Storage full');
    expect(
      specifics['channelDescription'],
      'Tells you when a mine site storage fills while you are away.',
    );
    expect(specifics['icon'], '@drawable/ic_notification');
    expect(specifics['scheduleMode'], 'inexactAllowWhileIdle');
  });

  test(
    'scheduleAt clamps a just-past fill time to fire almost immediately',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      responder = (_) => true;
      final platform = PluginStorageAlertPlatform();
      // A checkpoint-anchored projection can land a few milliseconds in the
      // past by the time the call lands; dropping it would silence the only
      // alert even when other sites fill later.
      final past = DateTime.now().toUtc().subtract(const Duration(seconds: 3));

      await platform.scheduleAt(
        title: 'Landing Basin on Homeworld is full',
        body: 'Sell its cargo to keep mining.',
        atUtc: past,
      );

      expect(
        [for (final call in calls) call.method],
        ['initialize', 'zonedSchedule'],
      );
      final schedule = calls[1].arguments as Map<Object?, Object?>;
      final scheduled = DateTime.parse(
        schedule['scheduledDateTimeISO8601'] as String,
      );
      expect(scheduled.isAfter(DateTime.now().toUtc()), isTrue);
      expect(
        scheduled.difference(DateTime.now().toUtc()) <
            const Duration(seconds: 10),
        isTrue,
      );
    },
  );

  test('cancelAll clears the pending alert on the plugin channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final platform = PluginStorageAlertPlatform();

    await platform.cancelAll();

    expect([for (final call in calls) call.method], ['cancelAll']);
  });
}
