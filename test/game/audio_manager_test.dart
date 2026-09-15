import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/audio_manager.dart';
import '../support/fake_background_music_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AudioManager.loadPrefs', () {
    test('reads enabled flag and clamps volume', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'audio.musicEnabled': false,
        'audio.musicVolume': 1.5,
        'audio.soundEnabled': false,
      });
      final manager = AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      );

      await manager.loadPrefs();

      expect(manager.musicEnabled, isFalse);
      expect(manager.musicVolume, 1.0);
      expect(manager.soundEnabled, isFalse);
    });
  });

  group('AudioManager sound effects', () {
    test(
      'plays one-shot assets independently of music and persists mute',
      () async {
        final player = FakeBackgroundMusicPlayer();
        final manager = AudioManager(soundEffectPlayer: player);
        addTearDown(manager.dispose);
        await manager.setMusicEnabled(false);
        for (final sound in GameSound.values) {
          await manager.playSound(sound);
        }
        expect(player.playedAssets, [
          for (final sound in GameSound.values) 'audio/${sound.name}.wav',
        ]);
        expect(player.releaseMode, ReleaseMode.stop);
        expect(player.volumeCalls.last, 0.7);
        await manager.setSoundEnabled(false);
        await manager.playSound(GameSound.merge);
        expect(player.playedAssets, hasLength(GameSound.values.length));
        await Future<void>.delayed(Duration.zero);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('audio.soundEnabled'), isFalse);
        expect(prefs.getBool('audio.musicEnabled'), isFalse);
      },
    );

    test(
      'configures the effect player to mix so cues never steal BGM focus',
      () async {
        final bgm = FakeBackgroundMusicPlayer();
        final effects = FakeBackgroundMusicPlayer();
        final manager = AudioManager(
          backgroundMusicPlayer: bgm,
          soundEffectPlayer: effects,
        );
        addTearDown(manager.dispose);
        await manager.maybeStartBgm();

        await manager.playSound(GameSound.tap);
        await manager.playSound(GameSound.merge);

        expect(effects.audioContextCalls, hasLength(1));
        final context = effects.audioContextCalls.single;
        expect(context.android.audioFocus, AndroidAudioFocus.none);
        expect(
          context.iOS.options,
          isNot(contains(AVAudioSessionOptions.mixWithOthers)),
        );
        expect(bgm.audioContextCalls, isEmpty);
      },
    );

    test('rapid input drops stale cues instead of queuing a burst', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(soundEffectPlayer: player);
      addTearDown(manager.dispose);
      final tap = manager.playSound(GameSound.tap);
      final merge = manager.playSound(GameSound.merge);
      await Future.wait([tap, merge]);
      expect(player.playedAssets, ['audio/merge.wav']);
    });

    test(
      'taps and mining cannot cancel pending or playing action cues',
      () async {
        final player = FakeBackgroundMusicPlayer(autoComplete: false);
        final manager = AudioManager(soundEffectPlayer: player);
        addTearDown(manager.dispose);
        final upgrade = manager.playSound(GameSound.upgrade);
        await manager.playSound(GameSound.tap);
        await upgrade;
        final stops = player.stopCalls;
        await manager.playSound(GameSound.tap);
        await manager.playSound(GameSound.mining);
        expect(player.playedAssets, ['audio/upgrade.wav']);
        expect(player.stopCalls, stops);

        player.complete();
        await manager.playSound(GameSound.mining);
        await manager.playSound(GameSound.milestone);
        await manager.playSound(GameSound.rig);
        expect(player.playedAssets, [
          'audio/upgrade.wav',
          'audio/mining.wav',
          'audio/milestone.wav',
        ]);
        await manager.setSoundEnabled(false);
        await manager.setSoundEnabled(true);
        await manager.playSound(GameSound.tap);
        expect(player.playedAssets.last, 'audio/tap.wav');
      },
    );

    test('lifecycle stops effects without replaying them on resume', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(soundEffectPlayer: player);
      addTearDown(manager.dispose);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        await manager.playSound(GameSound.rig);
        final count = player.playedAssets.length;
        manager.handleLifecycleChange(state);
        await manager.playSound(GameSound.sale);
        await Future<void>.delayed(Duration.zero);
        expect(player.playedAssets, hasLength(count));
        manager.handleLifecycleChange(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(player.playedAssets, hasLength(count));
      }
      expect(player.resumeCalls, 0);
      expect(player.stopCalls, 8);
    });

    test(
      'mute during startup cancels queued cues and stops the late play',
      () async {
        final player = FakeBackgroundMusicPlayer(
          playCompleter: Completer<void>(),
        );
        final manager = AudioManager(soundEffectPlayer: player);
        addTearDown(manager.dispose);
        final play = manager.playSound(GameSound.merge);
        await Future<void>.delayed(Duration.zero);
        final queued = manager.playSound(GameSound.sale);
        final mute = manager.setSoundEnabled(false);
        player.playCompleter!.complete();
        await Future.wait([play, queued, mute]);
        expect(player.playedAssets, ['audio/merge.wav']);
        expect(player.stopCalls, 2);
      },
    );

    test(
      'dispose drains in-flight playback before releasing its player',
      () async {
        final player = FakeBackgroundMusicPlayer(
          playCompleter: Completer<void>(),
        );
        final manager = AudioManager(soundEffectPlayer: player);
        final play = manager.playSound(GameSound.merge);
        await Future<void>.delayed(Duration.zero);
        final disposal = manager.dispose();
        await manager.playSound(GameSound.sale);
        expect(player.disposeCalls, 0);
        player.playCompleter!.complete();
        await Future.wait([play, disposal]);
        expect(player.playedAssets, ['audio/merge.wav']);
        expect(player.stopCalls, 2);
        expect(player.disposeCalls, 1);
      },
    );

    test(
      'player failures do not poison later effects or skip disposal',
      () async {
        final player = FakeBackgroundMusicPlayer(
          setVolumeError: StateError('failed'),
        );
        final manager = AudioManager(soundEffectPlayer: player);
        await manager.playSound(GameSound.milestone);
        player.setVolumeError = null;
        await manager.playSound(GameSound.tap);
        expect(player.playedAssets, ['audio/tap.wav']);
        player.stopError = StateError('failed');
        await manager.dispose();
        expect(player.disposeCalls, 1);
      },
    );

    test('an errored completion stream releases the active cue', () async {
      final player = FakeBackgroundMusicPlayer(autoComplete: false);
      final manager = AudioManager(soundEffectPlayer: player);
      addTearDown(manager.dispose);
      await manager.playSound(GameSound.milestone);
      player.completeWithError(StateError('decoder exploded'));
      // The error clears the active sound, so a lower-priority cue plays.
      await manager.playSound(GameSound.tap);
      expect(player.playedAssets, ['audio/milestone.wav', 'audio/tap.wav']);
    });

    test(
      'a failed completion unsubscribe is logged and playback continues',
      () async {
        final player = _CancelFailingCompletionPlayer();
        final manager = AudioManager(soundEffectPlayer: player);
        addTearDown(manager.dispose);
        final prints = <String>[];
        final previousPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) => prints.add(message ?? '');
        addTearDown(() => debugPrint = previousPrint);

        await manager.playSound(GameSound.tap);
        await manager.setSoundEnabled(false);
        await manager.setSoundEnabled(true);
        await manager.playSound(GameSound.merge);

        expect(player.playedAssets, ['audio/tap.wav', 'audio/merge.wav']);
        expect(player.stopCalls, greaterThan(0));
        expect(prints, contains(startsWith('Sound completion cleanup failed')));
      },
    );
  });

  group('AudioManager.maybeStartBgm', () {
    test('starts bgm with loop mode, clamped volume, and asset path', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);

      manager.setMusicVolume(0.8);
      await manager.maybeStartBgm();

      expect(manager.bgmStarted, isTrue);
      expect(player.releaseMode, ReleaseMode.loop);
      expect(player.volumeCalls, contains(0.8));
      expect(player.playedAssets, <String>['audio/orbital_foundry.mp3']);
    });

    test('skips when music is disabled', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);

      await manager.setMusicEnabled(false);
      await manager.maybeStartBgm();

      expect(manager.bgmStarted, isFalse);
      expect(player.playedAssets, isEmpty);
    });

    test('skips while start is already in progress', () async {
      final playCompleter = Completer<void>();
      final player = FakeBackgroundMusicPlayer(playCompleter: playCompleter);
      final manager = AudioManager(backgroundMusicPlayer: player);

      final firstStart = manager.maybeStartBgm();
      await Future<void>.delayed(Duration.zero);
      await manager.maybeStartBgm();
      playCompleter.complete();
      await firstStart;

      expect(player.playedAssets, <String>['audio/orbital_foundry.mp3']);
      expect(manager.bgmStarted, isTrue);
    });

    test(
      'does not mark bgm started when music is disabled mid-start',
      () async {
        final playCompleter = Completer<void>();
        final player = FakeBackgroundMusicPlayer(playCompleter: playCompleter);
        final manager = AudioManager(backgroundMusicPlayer: player);

        final firstStart = manager.maybeStartBgm();
        await Future<void>.delayed(Duration.zero);
        await manager.setMusicEnabled(false);
        playCompleter.complete();
        await firstStart;

        expect(manager.musicEnabled, isFalse);
        expect(manager.bgmStarted, isFalse);
        expect(player.playedAssets, <String>['audio/orbital_foundry.mp3']);
        expect(player.stopCalls, 1);
      },
    );

    test('skips once bgm has already started', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);

      await manager.maybeStartBgm();
      await manager.maybeStartBgm();

      expect(player.playedAssets, <String>['audio/orbital_foundry.mp3']);
    });

    test(
      'applies volume changes made while playAsset is still starting',
      () async {
        // Regression: _initAudio applies the current volume before awaiting
        // playAsset, and setMusicVolume only pushes to the player once
        // _bgmStarted is true. A slider move during that await must still
        // reach the player once startup completes.
        final playCompleter = Completer<void>();
        final player = FakeBackgroundMusicPlayer(playCompleter: playCompleter);
        final manager = AudioManager(backgroundMusicPlayer: player);

        final start = manager.maybeStartBgm();
        // Let _initAudio run up to the awaited playAsset call.
        await Future<void>.delayed(Duration.zero);

        manager.setMusicVolume(0.8);

        expect(
          manager.bgmStarted,
          isFalse,
          reason: 'BGM startup should still be in flight.',
        );

        playCompleter.complete();
        await start;

        expect(manager.bgmStarted, isTrue);
        expect(manager.musicVolume, 0.8);
        expect(
          player.volumeCalls,
          contains(0.8),
          reason: 'Volume change during startup must reach the player.',
        );
        expect(player.volumeCalls.last, 0.8);
      },
    );

    test(
      'pauses immediately when lifecycle pauses during initialization',
      () async {
        final playCompleter = Completer<void>();
        final player = FakeBackgroundMusicPlayer(playCompleter: playCompleter);
        final manager = AudioManager(backgroundMusicPlayer: player);

        final start = manager.maybeStartBgm();
        await Future<void>.delayed(Duration.zero);
        manager.handleLifecycleChange(AppLifecycleState.paused);

        expect(player.pauseCalls, 0);

        playCompleter.complete();
        await start;

        expect(manager.bgmStarted, isTrue);
        expect(player.pauseCalls, 1);

        manager.handleLifecycleChange(AppLifecycleState.resumed);

        expect(player.resumeCalls, 1);
      },
    );
  });

  group('AudioManager music controls', () {
    test('enabling music starts bgm when it has not started yet', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);

      await manager.setMusicEnabled(false);
      await manager.setMusicEnabled(true);

      expect(manager.musicEnabled, isTrue);
      expect(manager.bgmStarted, isTrue);
      expect(player.playedAssets, <String>['audio/orbital_foundry.mp3']);
    });

    test('disabling music pauses active bgm and saves prefs', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);
      final prefs = await SharedPreferences.getInstance();
      await manager.maybeStartBgm();

      await manager.setMusicEnabled(false);

      expect(player.pauseCalls, 1);
      expect(prefs.getBool('audio.musicEnabled'), isFalse);
    });

    test('re-enabling music resumes active bgm', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);
      await manager.maybeStartBgm();
      await manager.setMusicEnabled(false);

      await manager.setMusicEnabled(true);

      expect(player.resumeCalls, 1);
    });

    test(
      'setMusicVolume clamps, persists, and updates active player',
      () async {
        final player = FakeBackgroundMusicPlayer();
        final manager = AudioManager(backgroundMusicPlayer: player);
        final prefs = await SharedPreferences.getInstance();
        await manager.maybeStartBgm();

        manager.setMusicVolume(2.0);

        expect(manager.musicVolume, 1.0);
        expect(player.volumeCalls.last, 1.0);
        await Future<void>.delayed(Duration.zero);
        expect(prefs.getDouble('audio.musicVolume'), 1.0);
      },
    );

    test('setMusicVolume handles async player errors', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);
      await manager.maybeStartBgm();
      player.setVolumeError = StateError('setVolume failed');

      manager.setMusicVolume(0.25);
      await Future<void>.delayed(Duration.zero);

      expect(manager.musicVolume, 0.25);
      expect(player.volumeCalls.last, 0.25);
    });
  });

  group('AudioManager lifecycle and disposal', () {
    test('pauses, resumes, and stops for lifecycle changes', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);
      await manager.maybeStartBgm();

      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.inactive);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      manager.handleLifecycleChange(AppLifecycleState.detached);

      expect(player.pauseCalls, 2);
      expect(player.resumeCalls, 1);
      expect(player.stopCalls, 1);
    });

    test(
      'does not resume on lifecycle resumed when music is disabled',
      () async {
        final player = FakeBackgroundMusicPlayer();
        final manager = AudioManager(backgroundMusicPlayer: player);
        await manager.maybeStartBgm();
        await manager.setMusicEnabled(false);

        manager.handleLifecycleChange(AppLifecycleState.resumed);

        expect(player.resumeCalls, 0);
      },
    );

    test(
      'handleLifecycleChange catches async player command failures',
      () async {
        final player = FakeBackgroundMusicPlayer();
        final manager = AudioManager(backgroundMusicPlayer: player);
        await manager.maybeStartBgm();
        player.pauseError = StateError('pause failed');
        player.resumeError = StateError('resume failed');
        player.stopError = StateError('stop failed');

        manager.handleLifecycleChange(AppLifecycleState.paused);
        manager.handleLifecycleChange(AppLifecycleState.resumed);
        manager.handleLifecycleChange(AppLifecycleState.detached);
        await Future<void>.delayed(Duration.zero);

        expect(player.pauseCalls, 1);
        expect(player.resumeCalls, 1);
        expect(player.stopCalls, 1);
      },
    );

    test('dispose stops started bgm and disposes the player', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);
      await manager.maybeStartBgm();

      await Future<void>.sync(() => manager.dispose());

      expect(player.stopCalls, 1);
      expect(player.disposeCalls, 1);
    });

    test('dispose during pending playAsset does not recreate the player or '
        'mark started', () async {
      // Regression: _initAudio() awaited playAsset() across multiple
      // _backgroundMusicPlayer getter calls. A dispose() between awaits
      // nulled _bgm, so the post-await getter lazily created a second,
      // unowned player, and maybeStartBgm() then marked the disposed
      // manager started.
      final playCompleter = Completer<void>();
      final player = FakeBackgroundMusicPlayer(playCompleter: playCompleter);
      final manager = AudioManager(backgroundMusicPlayer: player);

      final start = manager.maybeStartBgm();
      // Let _initAudio run up to the awaited playAsset call.
      await Future<void>.delayed(Duration.zero);

      await manager.dispose();
      expect(player.disposeCalls, 1);

      playCompleter.complete();
      await start;

      expect(
        manager.bgmStarted,
        isFalse,
        reason: 'A disposed manager must not be marked started.',
      );
    });

    test('dispose waits for stop before disposing the player', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);
      await manager.maybeStartBgm();
      player.stopCompleter = Completer<void>();

      var disposeCompleted = false;
      final disposeFuture = Future<void>.sync(() => manager.dispose()).then((
        _,
      ) {
        disposeCompleted = true;
      });

      await Future<void>.delayed(Duration.zero);

      expect(player.stopCalls, 1);
      expect(player.disposeCalls, 0);
      expect(disposeCompleted, isFalse);

      player.stopCompleter!.complete();
      await disposeFuture;

      expect(player.disposeCalls, 1);
    });
  });
}

// A completion stream whose subscription cancel fails. Each access returns a
// fresh single-subscription controller so the manager can re-listen after the
// failed cancel.
class _CancelFailingCompletionPlayer extends FakeBackgroundMusicPlayer {
  @override
  Stream<void> get onComplete => StreamController<void>(
    onCancel: () => Future<void>.error(StateError('cancel failed')),
  ).stream;
}
