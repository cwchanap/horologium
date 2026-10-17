import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

// Resolve a finite deposit frame family in real async before the layer mounts,
// so its _precacheFrames Future.wait completes from cache hits and
// _framesReady becomes true via actual precache completion (the deferral
// budget drops a stalled impact, it does not fire it). A bare host gives
// precacheImage a Directionality context; the global image cache persists
// across the subsequent pumpWidget that mounts the layer.
Future<void> warmDepositFrames(
  WidgetTester tester,
  MiningDepositFrames frames,
) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final path in frames.all) {
      await precacheImage(AssetImage(path), context);
    }
  });
  await tester.pump();
}
