import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:horologium/game/background_music_player.dart';

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
