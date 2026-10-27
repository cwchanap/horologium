import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Platform boundary for storage-full local notifications.
///
/// There is exactly one configured alert: the adapter owns a single fixed
/// notification id/channel and every schedule replaces the previous pending
/// request. No id parameter is exposed.
abstract interface class StorageAlertPlatform {
  /// Asks the OS for notification permission; true when granted.
  Future<bool> requestPermission();

  /// Replaces the single pending alert with one firing at [atUtc].
  Future<void> scheduleAt({
    required String title,
    required String body,
    required DateTime atUtc,
  });

  /// Removes the pending alert and any posted storage alert.
  Future<void> cancelAll();
}

/// Real Android/iOS adapter over `flutter_local_notifications`.
///
/// Initialization is lazy and permission-free: the Darwin settings request
/// nothing, so the OS prompt is only ever shown through [requestPermission].
class PluginStorageAlertPlatform implements StorageAlertPlatform {
  static const int _alertId = 178;
  static const String _channelId = 'horologium.storageFull';
  static const String _channelName = 'Storage full';
  static const String _channelDescription =
      'Tells you when a mine site storage fills while you are away.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<bool?>? _initialization;

  Future<bool?> _ensureInitialized() {
    return _initialization ??= _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await _ensureInitialized();
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false,
      TargetPlatform.iOS =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false,
      _ => false,
    };
  }

  @override
  Future<void> scheduleAt({
    required String title,
    required String body,
    required DateTime atUtc,
  }) async {
    await _ensureInitialized();
    // The channel carries no custom sound; Android falls back to the default
    // notification sound and iOS keeps the default presentSound behavior.
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      id: _alertId,
      title: title,
      body: body,
      // UTC is built into the timezone package; no named-zone database is
      // loaded and the plugin stores the absolute instant.
      scheduledDate: tz.TZDateTime.from(atUtc, tz.UTC),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

StorageAlertPlatform? _defaultPlatform() {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS => PluginStorageAlertPlatform(),
    _ => null,
  };
}

/// Shell-owned service for the storage-full notification.
///
/// Mirrors the [AudioManager] pattern: independent SharedPreferences keys and
/// one serialized Future chain for platform operations, so a cancel can never
/// overtake an in-flight initialization/schedule.
class StorageAlerts {
  StorageAlerts({StorageAlertPlatform? platform})
    : _platform = platform ?? _defaultPlatform();

  static const String _enabledKey = 'notifications.storageFullEnabled';
  static const String _permissionAskedKey = 'notifications.permissionAsked';

  final StorageAlertPlatform? _platform;
  bool _enabled = true;
  bool _permissionAsked = false;
  Future<void>? _opQueue;

  /// Whether the current platform can show notifications at all.
  bool get supported => _platform != null;

  /// Whether the player wants storage-full alerts; true until turned off.
  bool get enabled => _enabled;

  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? true;
      _permissionAsked = prefs.getBool(_permissionAskedKey) ?? false;
    } catch (e) {
      debugPrint('Failed to load storage alert prefs: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    unawaited(_savePrefs());
    if (!value) await cancel();
  }

  /// First-commission automatic prompt, guarded by enabled and supported.
  /// Asks at most once ever; the attempt is recorded even when denied.
  Future<void> requestPermissionOnce() async {
    if (_platform == null || !_enabled || _permissionAsked) return;
    await requestPermission();
  }

  /// Explicit permission request (Settings turning alerts on). Always asks
  /// the platform again; false means denied or unsupported.
  Future<bool> requestPermission() async {
    final platform = _platform;
    if (platform == null) return false;
    _permissionAsked = true;
    unawaited(_savePrefs());
    try {
      return await platform.requestPermission();
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
      return false;
    }
  }

  /// Schedules the single storage-full alert, replacing any previous one.
  Future<void> schedule({
    required String siteName,
    required String planetName,
    required DateTime atUtc,
  }) {
    final platform = _platform;
    if (platform == null || !_enabled) return Future<void>.value();
    return _enqueue(
      () => platform.scheduleAt(
        title: '$siteName on $planetName is full',
        body: 'Sell its cargo to keep mining.',
        atUtc: atUtc,
      ),
    );
  }

  /// Cancels the pending alert; stale-alert cleanup and app resume use this.
  Future<void> cancel() {
    final platform = _platform;
    if (platform == null) return Future<void>.value();
    return _enqueue(platform.cancelAll);
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, _enabled);
      await prefs.setBool(_permissionAskedKey, _permissionAsked);
    } catch (e) {
      debugPrint('Failed to save storage alert prefs: $e');
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    late final Future<void> command;
    command = (_opQueue ?? Future<void>.value())
        .then((_) => operation())
        .catchError((Object e) => debugPrint('Storage alert failed: $e'))
        .whenComplete(() {
          if (identical(_opQueue, command)) _opQueue = null;
        });
    return _opQueue = command;
  }
}
