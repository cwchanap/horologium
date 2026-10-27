import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/game/storage_alerts.dart';
import 'package:horologium/mining/presentation/mining_settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_background_music_player.dart';

/// Storage-alert fake mirroring the style of test/game/storage_alerts_test.dart.
class _FakeStorageAlertPlatform implements StorageAlertPlatform {
  _FakeStorageAlertPlatform({this.grants = true});
  bool grants;
  int requestPermissionCount = 0;
  int cancelAllCount = 0;

  @override
  Future<bool> requestPermission() async {
    requestPermissionCount++;
    return grants;
  }

  @override
  Future<void> scheduleAt({
    required String title,
    required String body,
    required DateTime atUtc,
  }) async {}

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
  }
}

/// Builds a service with no platform so `supported` is false. The test
/// default target platform is Android, so support is overridden during
/// construction only.
StorageAlerts unsupportedAlerts() {
  final prior = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  final alerts = StorageAlerts();
  debugDefaultTargetPlatformOverride = prior;
  return alerts;
}

AudioManager _audioManager() => AudioManager(
  backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
  soundEffectPlayer: FakeBackgroundMusicPlayer(),
);

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
    final manager = _audioManager();
    addTearDown(manager.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => MiningSettingsSheet(
                  audioManager: manager,
                  storageAlerts: unsupportedAlerts(),
                ),
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

    final manager = _audioManager();
    addTearDown(manager.dispose);
    await manager.loadPrefs();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiningSettingsSheet(
            audioManager: manager,
            storageAlerts: unsupportedAlerts(),
          ),
        ),
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
        home: Scaffold(
          body: MiningSettingsSheet(
            audioManager: manager,
            storageAlerts: unsupportedAlerts(),
          ),
        ),
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
        home: Scaffold(
          body: MiningSettingsSheet(
            audioManager: manager,
            storageAlerts: unsupportedAlerts(),
          ),
        ),
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

  group('storage alerts', () {
    Future<void> pumpSheet(WidgetTester tester, StorageAlerts alerts) async {
      final manager = _audioManager();
      addTearDown(manager.dispose);
      await manager.loadPrefs();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiningSettingsSheet(
              audioManager: manager,
              storageAlerts: alerts,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder toggle() => find.byKey(const Key('mining-storage-alerts-switch'));

    testWidgets('notifications group is hidden when unsupported', (
      tester,
    ) async {
      await pumpSheet(tester, unsupportedAlerts());

      expect(
        find.byKey(const Key('settings-notifications-group')),
        findsNothing,
      );
      expect(toggle(), findsNothing);
      expect(find.byKey(const Key('settings-audio-group')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switch shows for a supported platform and defaults on', (
      tester,
    ) async {
      final alerts = StorageAlerts(platform: _FakeStorageAlertPlatform());
      await alerts.loadPrefs();
      await pumpSheet(tester, alerts);

      expect(
        find.byKey(const Key('settings-notifications-group')),
        findsOneWidget,
      );
      expect(tester.widget<SwitchListTile>(toggle()).value, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning off cancels and persists', (tester) async {
      final platform = _FakeStorageAlertPlatform();
      final alerts = StorageAlerts(platform: platform);
      await alerts.loadPrefs();
      await pumpSheet(tester, alerts);

      await tester.ensureVisible(toggle());
      await tester.tap(toggle());
      await tester.pump();
      await tester.binding.idle();

      expect(alerts.enabled, isFalse);
      expect(platform.cancelAllCount, 1);
      expect(platform.requestPermissionCount, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notifications.storageFullEnabled'), isFalse);
      expect(tester.widget<SwitchListTile>(toggle()).value, isFalse);
    });

    testWidgets('turning on asks again after an earlier denial', (
      tester,
    ) async {
      final platform = _FakeStorageAlertPlatform(grants: false);
      final alerts = StorageAlerts(platform: platform);
      await alerts.loadPrefs();
      // The once-ever automatic attempt was already made and denied.
      await alerts.requestPermissionOnce();
      expect(platform.requestPermissionCount, 1);
      await pumpSheet(tester, alerts);

      // Off never prompts; on asks the platform again despite the recorded
      // earlier denial.
      await tester.ensureVisible(toggle());
      await tester.tap(toggle());
      await tester.pump();
      await tester.binding.idle();
      expect(platform.requestPermissionCount, 1);

      platform.grants = true;
      await tester.ensureVisible(toggle());
      await tester.tap(toggle());
      await tester.pump();
      await tester.binding.idle();
      expect(platform.requestPermissionCount, 2);
      expect(alerts.enabled, isTrue);
      expect(
        find.text('Notifications are off for Horologium in system settings.'),
        findsNothing,
      );
    });

    testWidgets('a denied explicit request shows the system-settings message', (
      tester,
    ) async {
      final platform = _FakeStorageAlertPlatform(grants: false);
      final alerts = StorageAlerts(platform: platform);
      await alerts.loadPrefs();
      await pumpSheet(tester, alerts);

      await tester.ensureVisible(toggle());
      await tester.tap(toggle()); // off: cancels without prompting
      await tester.pump();
      await tester.binding.idle();
      expect(platform.requestPermissionCount, 0);

      await tester.ensureVisible(toggle());
      await tester.tap(toggle()); // on: denied by the platform
      await tester.pump();
      await tester.binding.idle();
      await tester.pump(const Duration(milliseconds: 300));

      expect(platform.requestPermissionCount, 1);
      final sheet = find.byKey(const Key('mining-settings-sheet'));
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(
            'Notifications are off for Horologium in system settings.',
          ),
        ),
        findsOneWidget,
      );

      // Toggling back off clears the inline feedback.
      await tester.ensureVisible(toggle());
      await tester.tap(toggle());
      await tester.pump();
      await tester.binding.idle();
      expect(
        find.text('Notifications are off for Horologium in system settings.'),
        findsNothing,
      );
    });

    testWidgets(
      'denied feedback stays inside the sheet through the real modal route',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(402, 874);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final platform = _FakeStorageAlertPlatform(grants: false);
        final alerts = StorageAlerts(platform: platform);
        await alerts.loadPrefs();
        final manager = _audioManager();
        addTearDown(manager.dispose);
        await manager.loadPrefs();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => MiningSettingsSheet(
                      audioManager: manager,
                      storageAlerts: alerts,
                    ),
                  ),
                  child: const Text('Open settings'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(toggle());
        await tester.tap(toggle()); // off: cancels without prompting
        await tester.pump();
        await tester.binding.idle();
        expect(platform.requestPermissionCount, 0);

        await tester.ensureVisible(toggle());
        await tester.tap(toggle()); // on: denied by the platform
        await tester.pump();
        await tester.binding.idle();
        await tester.pump(const Duration(milliseconds: 300));

        expect(platform.requestPermissionCount, 1);
        final sheet = find.byKey(const Key('mining-settings-sheet'));
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(
            of: sheet,
            matching: find.text(
              'Notifications are off for Horologium in system settings.',
            ),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('notifications group fits the 360x640 sheet without overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final alerts = StorageAlerts(platform: _FakeStorageAlertPlatform());
      await alerts.loadPrefs();
      await pumpSheet(tester, alerts);

      expect(
        find.byKey(const Key('settings-notifications-group')),
        findsOneWidget,
      );
      await tester.ensureVisible(toggle());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
