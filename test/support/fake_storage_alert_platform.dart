import 'dart:async';

import 'package:horologium/game/storage_alerts.dart';

/// Shared recording fake for [StorageAlertPlatform]: call counters, the last
/// scheduled payload, a mutable [grants] answer for denial paths, and
/// optional gates that hold a call open for ordering tests. A single
/// pending-request slot stands in for the adapter-owned fixed notification
/// id, so every schedule replaces the previous request. Pass the same
/// [eventLog] to several fakes to assert the order writes landed across
/// platform instances — the order the OS would see on the shared id.
class FakeStorageAlertPlatform implements StorageAlertPlatform {
  FakeStorageAlertPlatform({
    this.grants = true,
    List<String>? eventLog,
    String? name,
  }) : eventLog = eventLog ?? <String>[],
       _name = name ?? '';

  bool grants;

  /// Written as each platform call resolves, so a gated call records only
  /// when its write actually lands.
  final List<String> eventLog;
  final String _name;
  int requestPermissionCount = 0;
  int scheduleCount = 0;
  int cancelAllCount = 0;
  String? scheduledTitle;
  String? scheduledBody;
  DateTime? scheduledAtUtc;
  Completer<void>? permissionGate;
  Completer<void>? scheduleGate;
  Completer<void>? cancelGate;

  @override
  Future<bool> requestPermission() async {
    requestPermissionCount++;
    final gate = permissionGate;
    if (gate != null) await gate.future;
    return grants;
  }

  @override
  Future<void> scheduleAt({
    required String title,
    required String body,
    required DateTime atUtc,
  }) async {
    scheduleCount++;
    scheduledTitle = title;
    scheduledBody = body;
    scheduledAtUtc = atUtc;
    final gate = scheduleGate;
    if (gate != null) await gate.future;
    eventLog.add('$_name schedule');
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    final gate = cancelGate;
    if (gate != null) await gate.future;
    eventLog.add('$_name cancel');
  }
}
