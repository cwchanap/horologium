import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

/// The animated mining sites: every [MiningSiteId] with a non-null
/// `MiningVisuals.depositFramesFor`. Tests iterate this list instead of
/// re-filtering the enum, so a newly animated site picks up shared coverage.
final animatedMiningSiteIds = MiningSiteId.values
    .where((id) => MiningVisuals.depositFramesFor(id) != null)
    .toList(growable: false);

/// The static-layer fixture site. It must stay un-animated: if it gains a
/// frame family, pick another static site for the static-layer tests.
const staticMiningSiteId = MiningSiteId.graniteCrater;

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
