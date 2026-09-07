import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/mining/presentation/mining_settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_background_music_player.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'audio.musicEnabled': false,
      'audio.musicVolume': 0.75,
    });
  });

  testWidgets('portrait panel and right tab match the mock and dismiss', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final manager = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
    );
    addTearDown(manager.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => MiningSettingsSheet(audioManager: manager),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('mining-sheet-panel'))).top,
      392,
    );
    final close = find.bySemanticsLabel('Close Settings');
    expect(tester.getRect(close).left, 320);
    expect(tester.getRect(close).top, 362);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mining-settings-sheet')), findsNothing);
  });

  testWidgets('renders the injected AudioManager preferences and targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final manager = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
    );
    await manager.loadPrefs();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MiningSettingsSheet(audioManager: manager)),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('mining-music-state')))
          .properties
          .toggled,
      isFalse,
    );
    expect(
      tester
          .widget<Slider>(find.byKey(const Key('mining-volume-slider')))
          .value,
      0.75,
    );
    expect(
      tester.getSize(find.byKey(const Key('mining-music-switch'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('mining-volume-slider'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      find.byKey(const Key('settings-accessibility-group')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('mining-music-switch')));
    await tester.pump();
    expect(manager.musicEnabled, isTrue);
    expect(
      tester
          .widget<Slider>(find.byKey(const Key('mining-volume-slider')))
          .onChanged,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
