import 'package:audioplayers/audioplayers.dart';

abstract class BackgroundMusicPlayer {
  Future<void> setReleaseMode(ReleaseMode mode);
  Future<void> setVolume(double volume);
  Future<void> playAsset(String path);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class AudioPlayerBackgroundMusicPlayer implements BackgroundMusicPlayer {
  AudioPlayerBackgroundMusicPlayer([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playAsset(String path) => _player.play(AssetSource(path));

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> setReleaseMode(ReleaseMode mode) => _player.setReleaseMode(mode);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> stop() => _player.stop();
}
