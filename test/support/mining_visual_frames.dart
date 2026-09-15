import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

// Resolve the finite gold frame set in real async before the layer mounts,
// so its _precacheFrames Future.wait completes from cache hits and
// _framesReady becomes true via actual precache completion (the deferral
// budget drops a stalled impact, it does not fire it). A bare host gives
// precacheImage a Directionality context; the global image cache persists
// across the subsequent pumpWidget that mounts the layer.
Future<void> warmGoldFrames(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final path in [
      for (var stage = 1; stage <= 4; stage++)
        MiningVisuals.goldNodeStageAsset(stage),
      for (var frame = 1; frame <= 4; frame++)
        MiningVisuals.goldNodeIdleAsset(frame),
      for (var frame = 1; frame <= 3; frame++)
        MiningVisuals.goldNodeHitAsset(frame),
      for (var frame = 1; frame <= 4; frame++)
        MiningVisuals.goldNodeExhaustAsset(frame),
    ]) {
      await precacheImage(AssetImage(path), context);
    }
  });
  await tester.pump();
}
