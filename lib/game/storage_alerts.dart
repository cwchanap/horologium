import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:horologium/game/serial_task_queue.dart';
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
  // A colored launcher icon renders as a white square in the Android status
  // bar; the small icon must be a monochrome drawable.
  static const String _smallIcon = '@drawable/ic_notification';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<bool?>? _initialization;

  Future<bool?> _ensureInitialized() async {
    final pending = _initialization;
    if (pending != null) return pending;
    final attempt = _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialization = attempt;
    try {
      return await attempt;
    } catch (_) {
      // A failed initialize is not cached: the next platform call retries.
      if (identical(_initialization, attempt)) _initialization = null;
      rethrow;
    }
  }

  @override
  Future<bool> requestPermission() async {
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
    final scheduledDate = tz.TZDateTime.from(atUtc, tz.UTC);
    final now = tz.TZDateTime.now(tz.UTC);
    // zonedSchedule requires a future instant; a projection anchored at the
    // checkpoint write can land a few milliseconds in the past by the time
    // the call lands. A just-past fill means the site is already full, so
    // fire almost immediately instead of dropping the only alert.
    final effectiveDate = scheduledDate.isAfter(now)
        ? scheduledDate
        : now.add(const Duration(seconds: 1));
    // The channel carries no custom sound; Android falls back to the default
    // notification sound and iOS keeps the default presentSound behavior.
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        icon: _smallIcon,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      id: _alertId,
      title: title,
      body: body,
      // UTC is built into the timezone package; no named-zone database is
      // loaded and the plugin stores the absolute instant.
      scheduledDate: effectiveDate,
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
/// serialized Future chains for platform operations. Every instance shares
/// one write chain for the single OS notification id, so a reopened shell's
/// cancel can never be overtaken by a superseded shell's in-flight schedule.
class StorageAlerts {
  StorageAlerts({StorageAlertPlatform? platform})
    : _platform = platform ?? _defaultPlatform();

  static const String _enabledKey = 'notifications.storageFullEnabled';
  static const String _permissionAskedKey = 'notifications.permissionAsked';

  final StorageAlertPlatform? _platform;

  /// Instance chain for app-level calls. A write passes through here first
  /// so it still waits behind this shell's own pending OS permission
  /// prompt; a superseded prompt can only delay that shell's writes, never
  /// the shared write chain below.
  final _opQueue = SerialTaskQueue(
    (Object e) => debugPrint('Storage alert failed: $e'),
  );

  /// One write chain for the single OS notification id, shared by every
  /// instance. Each shell owns a [StorageAlerts] with its own [_opQueue],
  /// so without this a superseded shell's in-flight schedule lands after
  /// the reopened shell's cancel and re-arms the stale alert — or its
  /// in-flight cancel erases the newer shell's schedule.
  static final _writeQueue = SerialTaskQueue(
    (Object e) => debugPrint('Storage alert failed: $e'),
  );
  bool _enabled = true;
  bool _permissionAsked = false;

  /// Ownership lease evaluated when a queued write runs, not when it is
  /// enqueued. The installing shell sets this to its alert-ownership check
  /// so work queued behind a slow call — an OS permission prompt can
  /// outlive the shell — drops instead of writing the shared notification
  /// id after a newer shell claimed it. Permission requests are app-level
  /// rather than writes to that id, so they stay unguarded.
  bool Function()? ownsAlert;

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
  /// the platform again; false means denied or unsupported. A denial also
  /// flips the preference off: an ON switch that can never deliver would
  /// claim coverage the OS will never show.
  Future<bool> requestPermission() async {
    final platform = _platform;
    if (platform == null) return false;
    _permissionAsked = true;
    unawaited(_savePrefs());
    // Serialized with scheduling: overlapping OS requests throw on Android
    // and the second one would be misreported as a denial.
    final granted = await _opQueue.enqueue(() async {
      try {
        return await platform.requestPermission();
      } catch (e) {
        debugPrint('Failed to request notification permission: $e');
        return false;
      }
    });
    if (!granted) await setEnabled(false);
    return granted;
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

  /// Runs [operation] in queue order and swallows its error for the caller;
  /// each queue already logged it once. The instance hop keeps the write
  /// behind this shell's pending permission request; the shared hop then
  /// orders it behind every other shell's in-flight write, so the newest
  /// owner's writes always land last. Work that loses ownership while
  /// queued drops instead of writing the shared alert late.
  Future<void> _enqueue(Future<void> Function() operation) => _opQueue
      .enqueue(() async {
        if (!(ownsAlert?.call() ?? true)) return;
        await _writeQueue.enqueue(() async {
          if (!(ownsAlert?.call() ?? true)) return;
          await operation();
        });
      })
      .then<void>((_) {}, onError: (_) {});
}
