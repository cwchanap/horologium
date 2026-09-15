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
      soundEffectPlayer: FakeBackgroundMusicPlayer(),
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
    // Rects are asserted through the key: 3.32 merges the labeled semantics
    // node sheet-wide, so its rect is version-dependent while the tab layout
    // is not. The label itself is still asserted for a11y coverage.
    expect(find.bySemanticsLabel('Close Settings'), findsOneWidget);
    final close = find.byKey(const Key('mining-sheet-close-tab'));
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
      soundEffectPlayer: FakeBackgroundMusicPlayer(),
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

  testWidgets('sound effects mute independently and save the preference', (
    tester,
  ) async {
    final effects = FakeBackgroundMusicPlayer();
    final manager = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(manager.dispose);
    await manager.loadPrefs();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MiningSettingsSheet(audioManager: manager)),
      ),
    );
    final toggle = find.byKey(const Key('mining-sound-switch'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(manager.soundEnabled, isFalse);
    expect(manager.musicEnabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('audio.soundEnabled'), isFalse);
    await tester.tap(toggle);
    await tester.pump();
    expect(manager.soundEnabled, isTrue);
    expect(manager.musicEnabled, isFalse);
    expect(effects.playedAssets, ['audio/tap.wav']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing a volume drag plays the tap cue', (tester) async {
    SharedPreferences.setMockInitialValues({
      'audio.musicEnabled': true,
      'audio.musicVolume': 0.5,
    });
    final effects = FakeBackgroundMusicPlayer();
    final manager = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(manager.dispose);
    await manager.loadPrefs();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MiningSettingsSheet(audioManager: manager)),
      ),
    );
    final slider = find.byKey(const Key('mining-volume-slider'));
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(40, 0));
    await tester.pump();
    expect(manager.musicVolume, greaterThan(0.5));
    expect(effects.playedAssets, ['audio/tap.wav']);
    expect(tester.takeException(), isNull);
  });
}
