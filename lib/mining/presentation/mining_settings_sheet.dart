import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horologium/game/audio_manager.dart';
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
    final audioManager = widget.audioManager;
    return SafeArea(
      child: Material(
        key: const Key('mining-settings-sheet'),
        color: MiningTheme.panel,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MiningTheme.accent.withAlpha(180),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.music_note, color: MiningTheme.secondaryText),
                  SizedBox(width: 8),
                  Text(
                    'Audio',
                    style: TextStyle(
                      color: MiningTheme.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('mining-music-switch'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Music',
                  style: TextStyle(color: MiningTheme.secondaryText),
                ),
                value: audioManager.musicEnabled,
                onChanged: (value) {
                  unawaited(audioManager.setMusicEnabled(value));
                  setState(() {});
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Volume',
                      style: TextStyle(color: MiningTheme.secondaryText),
                    ),
                    Text(
                      '${(audioManager.musicVolume * 100).round()}%',
                      style: const TextStyle(color: MiningTheme.mutedText),
                    ),
                  ],
                ),
              ),
              Slider(
                key: const Key('mining-volume-slider'),
                value: audioManager.musicVolume,
                min: 0,
                max: 1,
                divisions: 20,
                label: '${(audioManager.musicVolume * 100).round()}%',
                onChanged: audioManager.musicEnabled
                    ? (value) {
                        audioManager.setMusicVolume(value);
                        setState(() {});
                      }
                    : null,
              ),
              const Divider(color: Colors.white24, height: 20),
              const Text(
                'Accessibility',
                style: TextStyle(
                  color: MiningTheme.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reduced motion follows system setting',
                style: TextStyle(color: MiningTheme.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
