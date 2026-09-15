import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/background_music_player.dart';

// An AudioPlayer whose completion events are driven by a static broadcast
// controller. The controller must be static: AudioPlayer's constructor
// subscribes to onPlayerComplete before subclass field initializers run.
class _ControlledAudioPlayer extends AudioPlayer {
  static final completions = StreamController<void>.broadcast();

  @override
  Stream<void> get onPlayerComplete => completions.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('onComplete forwards the wrapped player completion stream', () async {
    final inner = _ControlledAudioPlayer();
    // Without the plugin channel, AudioPlayer's async creation fails; absorb
    // the completer error so it is not reported as unhandled.
    inner.creatingCompleter.future.ignore();
    addTearDown(_ControlledAudioPlayer.completions.close);
    final player = AudioPlayerBackgroundMusicPlayer(inner);

    var completions = 0;
    final subscription = player.onComplete.listen((_) => completions++);
    _ControlledAudioPlayer.completions.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(completions, 1);
    await subscription.cancel();
  });
}
