import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_music_player.dart';

class AudioManager {
  AudioManager({BackgroundMusicPlayer? backgroundMusicPlayer})
    : _bgm = backgroundMusicPlayer;

  BackgroundMusicPlayer? _bgm;
  bool _bgmStarted = false;
  bool _bgmInitializing = false;
  bool _musicEnabled = true;
  double _musicVolume = 0.5;
  AppLifecycleState? _lifecycleState;

  bool get bgmStarted => _bgmStarted;
  bool get musicEnabled => _musicEnabled;
  double get musicVolume => _musicVolume;

  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('audio.musicEnabled');
      final volume = prefs.getDouble('audio.musicVolume');
      if (enabled != null) _musicEnabled = enabled;
      if (volume != null) _musicVolume = volume.clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Failed to load audio prefs: $e');
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('audio.musicEnabled', _musicEnabled);
      await prefs.setDouble('audio.musicVolume', _musicVolume);
    } catch (e) {
      debugPrint('Failed to save audio prefs: $e');
    }
  }

  BackgroundMusicPlayer get _backgroundMusicPlayer =>
      _bgm ??= AudioPlayerBackgroundMusicPlayer();

  Future<bool> _initAudio() async {
    try {
      await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _backgroundMusicPlayer.setVolume(_musicVolume);
      await _backgroundMusicPlayer.playAsset('audio/background.mp3');
      debugPrint('BGM started (volume=$_musicVolume).');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize/play BGM: $e');
      return false;
    }
  }

  Future<void> maybeStartBgm() async {
    if (_bgmStarted || !_musicEnabled || _bgmInitializing) return;
    _bgmInitializing = true;

    try {
      final success = await _initAudio();
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

  void handleLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _lifecycleState = state;
        if (_bgmStarted) _pauseForLifecycle();
        break;
      case AppLifecycleState.resumed:
        _lifecycleState = state;
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
      default:
        break;
    }
  }

  Future<void> dispose() async {
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
    }
  }

  bool get _lifecycleBlocksPlayback =>
      _lifecycleState == AppLifecycleState.paused ||
      _lifecycleState == AppLifecycleState.inactive;

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
