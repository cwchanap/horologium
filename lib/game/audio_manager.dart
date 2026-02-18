import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioManager {
  AudioPlayer? _bgm;
  bool _bgmStarted = false;
  bool _bgmInitializing = false;
  bool _musicEnabled = true;
  double _musicVolume = 0.5;

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

  Future<bool> _initAudio() async {
    try {
      _bgm ??= AudioPlayer();
      await _bgm!.setReleaseMode(ReleaseMode.loop);
      await _bgm!.setVolume(_musicVolume);
      await _bgm!.play(AssetSource('audio/background.mp3'));
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
      if (success) {
        _bgmStarted = true;
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
        _bgm?.pause();
        debugPrint('BGM paused by user.');
      } catch (e) {
        debugPrint('Failed to pause BGM: $e');
      }
    } else if (_bgmStarted && value) {
      try {
        _bgm?.resume();
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
      try {
        _bgm?.setVolume(_musicVolume);
        debugPrint('BGM volume changed to $_musicVolume.');
      } catch (e) {
        debugPrint('Failed to change BGM volume: $e');
      }
    }
  }

  void handleLifecycleChange(AppLifecycleState state) {
    try {
      if (!_bgmStarted) return;
      switch (state) {
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
          _bgm?.pause();
          debugPrint('BGM paused due to lifecycle.');
          break;
        case AppLifecycleState.resumed:
          if (_musicEnabled) {
            _bgm?.resume();
            debugPrint('BGM resumed due to lifecycle.');
          }
          break;
        case AppLifecycleState.detached:
          _bgm?.stop();
          debugPrint('BGM stopped due to lifecycle detach.');
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('BGM lifecycle handling error: $e');
    }
  }

  void dispose() {
    if (_bgm != null) {
      try {
        if (_bgmStarted) {
          _bgm?.stop();
        }
        _bgm?.dispose();
      } catch (e) {
        debugPrint('BGM dispose error: $e');
      }
      _bgm = null;
    }
  }
}
