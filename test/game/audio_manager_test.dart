import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/game/background_music_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBackgroundMusicPlayer implements BackgroundMusicPlayer {
  FakeBackgroundMusicPlayer({
    this.playCompleter,
    this.stopCompleter,
    this.setVolumeError,
    this.pauseError,
    this.resumeError,
    this.stopError,
  });

  Completer<void>? playCompleter;
  Completer<void>? stopCompleter;
  Object? setVolumeError;
  Object? pauseError;
  Object? resumeError;
  Object? stopError;
  ReleaseMode? releaseMode;
  final List<double> volumeCalls = <double>[];
  final List<String> playedAssets = <String>[];
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    if (pauseError != null) {
      throw pauseError!;
    }
  }

  @override
  Future<void> playAsset(String path) async {
    playedAssets.add(path);
    if (playCompleter != null) {
      await playCompleter!.future;
    }
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    if (resumeError != null) {
      throw resumeError!;
    }
  }

  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {
    releaseMode = mode;
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeCalls.add(volume);
    if (setVolumeError != null) {
      throw setVolumeError!;
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (stopError != null) {
      throw stopError!;
    }
    if (stopCompleter != null) {
      await stopCompleter!.future;
    }
  }
}

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
      });
      final manager = AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      );

      await manager.loadPrefs();

      expect(manager.musicEnabled, isFalse);
      expect(manager.musicVolume, 1.0);
    });
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
      expect(player.playedAssets, <String>['audio/background.mp3']);
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

      expect(player.playedAssets, <String>['audio/background.mp3']);
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
        expect(player.playedAssets, <String>['audio/background.mp3']);
        expect(player.stopCalls, 1);
      },
    );

    test('skips once bgm has already started', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);

      await manager.maybeStartBgm();
      await manager.maybeStartBgm();

      expect(player.playedAssets, <String>['audio/background.mp3']);
    });
  });

  group('AudioManager music controls', () {
    test('enabling music starts bgm when it has not started yet', () async {
      final player = FakeBackgroundMusicPlayer();
      final manager = AudioManager(backgroundMusicPlayer: player);

      await manager.setMusicEnabled(false);
      await manager.setMusicEnabled(true);

      expect(manager.musicEnabled, isTrue);
      expect(manager.bgmStarted, isTrue);
      expect(player.playedAssets, <String>['audio/background.mp3']);
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
