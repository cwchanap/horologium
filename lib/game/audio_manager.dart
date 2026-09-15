import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_music_player.dart';

enum GameSound {
  mining,
  tap,
  rig,
  merge,
  sale,
  upgrade,
  travel,
  cargoFull,
  milestone,
  reject;

  int get priority => switch (this) {
    mining => 0,
    tap => 1,
    milestone => 3,
    _ => 2,
  };
}

class AudioManager {
  AudioManager({
    BackgroundMusicPlayer? backgroundMusicPlayer,
    BackgroundMusicPlayer? soundEffectPlayer,
  }) : _bgm = backgroundMusicPlayer,
       _sfx = soundEffectPlayer;

  BackgroundMusicPlayer? _bgm;
  BackgroundMusicPlayer? _sfx;
  Future<void>? _sfxQueue;
  bool _sfxContextConfigured = false;
  int _sfxGeneration = 0;
  GameSound? _activeSound;
  StreamSubscription<void>? _sfxCompletion;
  bool _soundEnabled = true;
  bool _bgmStarted = false;
  bool _bgmInitializing = false;
  bool _musicEnabled = true;
  double _musicVolume = 0.5;
  AppLifecycleState? _lifecycleState;
  bool _disposed = false;

  bool get bgmStarted => _bgmStarted;
  bool get musicEnabled => _musicEnabled;
  double get musicVolume => _musicVolume;
  bool get soundEnabled => _soundEnabled;

  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('audio.musicEnabled');
      final volume = prefs.getDouble('audio.musicVolume');
      if (enabled != null) _musicEnabled = enabled;
      if (volume != null) _musicVolume = volume.clamp(0.0, 1.0);
      _soundEnabled = prefs.getBool('audio.soundEnabled') ?? true;
    } catch (e) {
      debugPrint('Failed to load audio prefs: $e');
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('audio.musicEnabled', _musicEnabled);
      await prefs.setDouble('audio.musicVolume', _musicVolume);
      await prefs.setBool('audio.soundEnabled', _soundEnabled);
    } catch (e) {
      debugPrint('Failed to save audio prefs: $e');
    }
  }

  BackgroundMusicPlayer get _backgroundMusicPlayer =>
      _bgm ??= AudioPlayerBackgroundMusicPlayer();

  Future<bool> _initAudio() async {
    // Capture the player once so a dispose() between awaits cannot cause the
    // _backgroundMusicPlayer getter to lazily create a second, unowned player
    // after the first has been disposed.
    final player = _backgroundMusicPlayer;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_musicVolume);
      await player.playAsset('audio/orbital_foundry.mp3');
      // Reapply the latest volume after playAsset completes. A slider move
      // during the awaited play call updates _musicVolume but cannot reach
      // the player until _bgmStarted flips, which happens only after this
      // returns. Without this, the player keeps the pre-startup volume.
      await player.setVolume(_musicVolume);
      debugPrint('BGM started (volume=$_musicVolume).');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize/play BGM: $e');
      return false;
    }
  }

  Future<void> maybeStartBgm() async {
    if (_bgmStarted ||
        !_musicEnabled ||
        _bgmInitializing ||
        _disposed ||
        _lifecycleBlocksPlayback) {
      return;
    }
    _bgmInitializing = true;

    try {
      final success = await _initAudio();
      // A dispose() during the awaited startup must not mark this manager
      // started or operate on a recreated player.
      if (_disposed) return;
      if (success && _musicEnabled) {
        _bgmStarted = true;
        if (_lifecycleBlocksPlayback) {
          _pauseForLifecycle();
        }
      } else if (success) {
        try {
          await _bgm?.stop();
        } catch (e) {
          debugPrint('Failed to stop BGM after disable during init: $e');
        }
      }
    } finally {
      _bgmInitializing = false;
    }
  }

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    unawaited(_savePrefs());
    if (!_bgmStarted && value) {
      await maybeStartBgm();
    } else if (_bgmStarted && !value) {
      try {
        await _bgm?.pause();
        debugPrint('BGM paused by user.');
      } catch (e) {
        debugPrint('Failed to pause BGM: $e');
      }
    } else if (_bgmStarted && value && !_lifecycleBlocksPlayback) {
      try {
        await _bgm?.resume();
        debugPrint('BGM resumed by user.');
      } catch (e) {
        debugPrint('Failed to resume BGM: $e');
      }
    }
  }

  void setMusicVolume(double value) {
    _musicVolume = value.clamp(0.0, 1.0);
    unawaited(_savePrefs());
    if (_bgmStarted) {
      final volumeFuture = _bgm?.setVolume(_musicVolume);
      if (volumeFuture != null) {
        unawaited(
          volumeFuture
              .then((_) {
                debugPrint('BGM volume changed to $_musicVolume.');
              })
              .catchError((Object e) {
                debugPrint('Failed to change BGM volume: $e');
              }),
        );
      }
    }
  }

  Future<void> setSoundEnabled(bool value) async {
    if (_disposed) return;
    _soundEnabled = value;
    unawaited(_savePrefs());
    if (!value) await _stopSounds();
  }

  Future<void> playSound(GameSound sound) {
    if (_disposed ||
        !_soundEnabled ||
        _lifecycleBlocksPlayback ||
        sound.priority < (_activeSound?.priority ?? -1)) {
      return Future<void>.value();
    }
    _activeSound = sound;
    final generation = ++_sfxGeneration;
    return _queueSound(() async {
      if (generation != _sfxGeneration) return;
      // ponytail: one voice; add a pool only if simultaneous action cues are needed.
      final player = _sfx ??= AudioPlayerBackgroundMusicPlayer();
      try {
        if (!_sfxContextConfigured) {
          // The effect player must not take audio focus: the default
          // AndroidAudioFocus.gain request would steal focus and silence BGM.
          await player.setAudioContext(
            AudioContextConfig(
              focus: AudioContextConfigFocus.mixWithOthers,
            ).build(),
          );
          if (generation != _sfxGeneration) return;
          _sfxContextConfigured = true;
        }
        _cancelSoundCompletion();
        await player.stop();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(0.7);
        if (generation != _sfxGeneration) return;
        _sfxCompletion = player.onComplete.listen(
          (_) {
            if (generation == _sfxGeneration) _activeSound = null;
          },
          onError: (Object error) {
            if (generation == _sfxGeneration) _activeSound = null;
            debugPrint('Sound playback failed: $error');
          },
        );
        await player.playAsset('audio/${sound.name}.wav');
      } catch (_) {
        if (generation == _sfxGeneration) _activeSound = null;
        rethrow;
      }
    });
  }

  Future<void> _queueSound(Future<void> Function() operation) {
    late final Future<void> command;
    command = (_sfxQueue ?? Future<void>.value())
        .then((_) => operation())
        .catchError((Object e) => debugPrint('Sound effect failed: $e'))
        .whenComplete(() {
          if (identical(_sfxQueue, command)) _sfxQueue = null;
        });
    return _sfxQueue = command;
  }

  void _cancelSoundCompletion() {
    // Cancelling the event subscription stops delivery synchronously. Player
    // teardown remains ordered through the command queue below.
    unawaited(
      _sfxCompletion?.cancel().catchError((Object e) {
        debugPrint('Sound completion cleanup failed: $e');
      }),
    );
    _sfxCompletion = null;
  }

  Future<void> _stopSounds() {
    _sfxGeneration++;
    _activeSound = null;
    return _queueSound(() async {
      _cancelSoundCompletion();
      await _sfx?.stop();
    });
  }

  void handleLifecycleChange(AppLifecycleState state) {
    if (_disposed) return;
    _lifecycleState = state;
    if (_lifecycleBlocksPlayback) unawaited(_stopSounds());
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (_bgmStarted) _pauseForLifecycle();
        break;
      case AppLifecycleState.resumed:
        if (_bgmStarted && _musicEnabled) {
          final resumeFuture = _bgm?.resume();
          if (resumeFuture != null) {
            unawaited(
              resumeFuture
                  .then((_) {
                    debugPrint('BGM resumed due to lifecycle.');
                  })
                  .catchError((Object e) {
                    debugPrint('Failed to resume BGM due to lifecycle: $e');
                  }),
            );
          }
        }
        break;
      case AppLifecycleState.detached:
        if (!_bgmStarted) return;
        final stopFuture = _bgm?.stop();
        if (stopFuture != null) {
          unawaited(
            stopFuture
                .then((_) {
                  debugPrint('BGM stopped due to lifecycle detach.');
                })
                .catchError((Object e) {
                  debugPrint('Failed to stop BGM due to lifecycle detach: $e');
                }),
          );
        }
        break;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sfxGeneration++;
    _activeSound = null;
    final soundDisposal = _queueSound(() async {
      _cancelSoundCompletion();
      final player = _sfx;
      _sfx = null;
      try {
        await player?.stop();
      } finally {
        await player?.dispose();
      }
    });
    final bgm = _bgm;
    final started = _bgmStarted;

    try {
      if (bgm != null && started) {
        await bgm.stop();
      }
      if (bgm != null) {
        await bgm.dispose();
      }
    } catch (e) {
      debugPrint('BGM dispose error: $e');
    } finally {
      _bgm = null;
      _bgmStarted = false;
      _bgmInitializing = false;
      _lifecycleState = null;
      _disposed = true;
    }
    await soundDisposal;
  }

  bool get _lifecycleBlocksPlayback =>
      _lifecycleState == AppLifecycleState.paused ||
      _lifecycleState == AppLifecycleState.inactive ||
      _lifecycleState == AppLifecycleState.hidden ||
      _lifecycleState == AppLifecycleState.detached;

  void _pauseForLifecycle() {
    final pauseFuture = _bgm?.pause();
    if (pauseFuture != null) {
      unawaited(
        pauseFuture
            .then((_) {
              debugPrint('BGM paused due to lifecycle.');
            })
            .catchError((Object e) {
              debugPrint('Failed to pause BGM due to lifecycle: $e');
            }),
      );
    }
  }
}
