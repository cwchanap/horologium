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
          .widget<SwitchListTile>(find.byKey(const Key('mining-music-switch')))
          .value,
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
    expect(tester.takeException(), isNull);
  });
}
