import 'dart:async';
import 'package:flutter/material.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
import 'package:horologium/mining/presentation/mining_sheet_frame.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';

class MiningSettingsSheet extends StatefulWidget {
  const MiningSettingsSheet({super.key, required this.audioManager});
  final AudioManager audioManager;
  @override
  State<MiningSettingsSheet> createState() => _MiningSettingsSheetState();
}

class _MiningSettingsSheetState extends State<MiningSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final audio = widget.audioManager;
    return MiningSheetFrame(
      key: const Key('mining-settings-sheet'),
      title: 'Settings',
      portraitHeight: MediaQuery.sizeOf(context).height * 482 / 874,
      portraitTabOnRight: true,
      icon: const Icon(Icons.tune, color: MiningTheme.highlight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _group(
            'settings-audio-group',
            accent: true,
            children: [
              _section(Icons.music_note, 'AUDIO'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Music',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Cavern ambience',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    key: const Key('mining-music-state'),
                    label: 'Music',
                    toggled: audio.musicEnabled,
                    child: TextButton(
                      key: const Key('mining-music-switch'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(84, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        backgroundColor: MiningTheme.highlight.withAlpha(20),
                        side: BorderSide(
                          color: audio.musicEnabled
                              ? MiningTheme.highlight
                              : Colors.white38,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () {
                        unawaited(audio.setMusicEnabled(!audio.musicEnabled));
                        setState(() {});
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            audio.musicEnabled ? 'ON' : 'OFF',
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 9,
                              color: MiningTheme.highlight,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ExcludeSemantics(
                            child: SizedBox(
                              width: 32,
                              height: 36,
                              child: MiningHex(
                                fill: audio.musicEnabled
                                    ? MiningTheme.highlight
                                    : Colors.white38,
                                border: Colors.transparent,
                                child: const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Volume',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${(audio.musicVolume * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      color: MiningTheme.accent,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const _HexSliderThumb(),
                  trackHeight: 4,
                  activeTrackColor: MiningTheme.accent,
                  thumbColor: MiningTheme.highlight,
                ),
                child: Slider(
                  key: const Key('mining-volume-slider'),
                  value: audio.musicVolume,
                  divisions: 20,
                  label: '${(audio.musicVolume * 100).round()}%',
                  onChanged: audio.musicEnabled
                      ? (value) {
                          audio.setMusicVolume(value);
                          setState(() {});
                        }
                      : null,
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('0'), Text('20 steps'), Text('100')],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _group(
            'settings-accessibility-group',
            children: [
              _section(Icons.accessibility_new, 'ACCESSIBILITY'),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reduced motion',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Work loops and merge bursts hold still',
                          style: TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: MiningTheme.accent.withAlpha(30),
                      border: Border.all(
                        color: MiningTheme.accent.withAlpha(115),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SYSTEM',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 10,
                        color: MiningTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _group(
    String key, {
    bool accent = false,
    required List<Widget> children,
  }) => Container(
    key: Key(key),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    decoration: BoxDecoration(
      color: accent
          ? MiningTheme.accent.withAlpha(15)
          : Colors.white.withAlpha(9),
      border: Border.all(
        color: accent
            ? MiningTheme.accent.withAlpha(61)
            : Colors.white.withAlpha(33),
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _section(IconData icon, String label) => Row(
    children: [
      Icon(icon, color: MiningTheme.accent, size: 20),
      const SizedBox(width: 10),
      Text(
        label,
        style: const TextStyle(
          fontFamily: 'Orbitron',
          color: Colors.white70,
          fontSize: 12,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _HexSliderThumb extends SliderComponentShape {
  const _HexSliderThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(30, 34);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas.drawPath(
      miningHexPath(const Size(30, 34)).shift(center - const Offset(15, 17)),
      Paint()
        ..color = Color.lerp(
          sliderTheme.disabledThumbColor,
          sliderTheme.thumbColor,
          enableAnimation.value,
        )!,
    );
  }
}
