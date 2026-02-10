import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game/main_game.dart';

class TerrainDebugSheet {
  static Future<void> show(BuildContext context, MainGame game) async {
    if (!game.hasLoaded) return;
    final initialTerrainDebug = game.terrain?.showDebug ?? false;
    final initialGridDebug = game.grid.showDebug;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withAlpha((255 * 0.95).round()),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        bool terrainDebug = initialTerrainDebug;
        bool gridDebug = initialGridDebug;
        bool showCenters = game.terrain?.showPatchCentersDebug ?? false;
        bool showEdges = game.terrain?.showEdgeZonesDebug ?? false;
        final gen = game.terrain!.generator;
        int patchSizeBase = gen.patchSizeBase;
        int patchJitter = gen.patchJitter;
        double primaryWeight = gen.primaryWeight;
        double warpAmplitude = gen.warpAmplitude;
        double warpFrequency = gen.warpFrequency;
        double edgeWidth = gen.edgeWidth;
        double edgeGamma = gen.edgeGamma;

        Future<void> saveTogglePrefs() async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('terrain.debug', terrainDebug);
          await prefs.setBool('terrain.showCenters', showCenters);
          await prefs.setBool('terrain.showEdges', showEdges);
          await prefs.setBool('grid.debug', gridDebug);
        }

        Future<void> saveParamPrefs() async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('terrain.patchSizeBase', patchSizeBase);
          await prefs.setInt('terrain.patchJitter', patchJitter);
          await prefs.setDouble('terrain.primaryWeight', primaryWeight);
          await prefs.setDouble('terrain.warpAmplitude', warpAmplitude);
          await prefs.setDouble('terrain.warpFrequency', warpFrequency);
          await prefs.setDouble('terrain.edgeWidth', edgeWidth);
          await prefs.setDouble('terrain.edgeGamma', edgeGamma);
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Developer Tools',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Terrain debug overlays',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: terrainDebug,
                      onChanged: (v) {
                        setSheetState(() => terrainDebug = v);
                        game.terrain?.setDebugOverlays(v);
                        saveTogglePrefs();
                      },
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Show patch centers',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: showCenters,
                      onChanged: (v) {
                        setSheetState(() => showCenters = v);
                        game.terrain?.setPatchDebugOverlays(showCenters: v);
                        saveTogglePrefs();
                      },
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Show edge zones',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: showEdges,
                      onChanged: (v) {
                        setSheetState(() => showEdges = v);
                        game.terrain?.setPatchDebugOverlays(showEdges: v);
                        saveTogglePrefs();
                      },
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Grid debug overlays',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: gridDebug,
                      onChanged: (v) {
                        setSheetState(() => gridDebug = v);
                        game.grid.showDebug = v;
                        saveTogglePrefs();
                      },
                    ),
                    const Divider(color: Colors.white24),
                    const Text(
                      'Presets',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              patchSizeBase = 12;
                              patchJitter = 1;
                              primaryWeight = 0.90;
                              warpAmplitude = 1.0;
                              warpFrequency = 0.12;
                              edgeWidth = 1.1;
                              edgeGamma = 1.4;
                            });
                          },
                          child: const Text('Plains'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              patchSizeBase = 8;
                              patchJitter = 2;
                              primaryWeight = 0.80;
                              warpAmplitude = 2.0;
                              warpFrequency = 0.22;
                              edgeWidth = 1.4;
                              edgeGamma = 1.8;
                            });
                          },
                          child: const Text('Rugged'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              patchSizeBase = 10;
                              patchJitter = 2;
                              primaryWeight = 0.75;
                              warpAmplitude = 1.6;
                              warpFrequency = 0.18;
                              edgeWidth = 1.6;
                              edgeGamma = 1.6;
                            });
                          },
                          child: const Text('Coastal'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Terrain parameters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderRow(
                      label: 'Patch Size',
                      valueText: '$patchSizeBase',
                      child: Slider(
                        value: patchSizeBase.toDouble(),
                        min: 5,
                        max: 15,
                        divisions: 10,
                        label: '$patchSizeBase',
                        onChanged: (v) =>
                            setSheetState(() => patchSizeBase = v.round()),
                      ),
                    ),
                    _buildSliderRow(
                      label: 'Patch Jitter',
                      valueText: '$patchJitter',
                      child: Slider(
                        value: patchJitter.toDouble(),
                        min: 0,
                        max: 4,
                        divisions: 4,
                        label: '$patchJitter',
                        onChanged: (v) =>
                            setSheetState(() => patchJitter = v.round()),
                      ),
                    ),
                    _buildSliderRow(
                      label: 'Primary Weight',
                      valueText: primaryWeight.toStringAsFixed(2),
                      child: Slider(
                        value: primaryWeight,
                        min: 0.6,
                        max: 1.0,
                        divisions: 20,
                        label: primaryWeight.toStringAsFixed(2),
                        onChanged: (v) =>
                            setSheetState(() => primaryWeight = v),
                      ),
                    ),
                    _buildSliderRow(
                      label: 'Warp Amplitude',
                      valueText: warpAmplitude.toStringAsFixed(2),
                      child: Slider(
                        value: warpAmplitude,
                        min: 0.0,
                        max: 3.0,
                        divisions: 30,
                        label: warpAmplitude.toStringAsFixed(2),
                        onChanged: (v) =>
                            setSheetState(() => warpAmplitude = v),
                      ),
                    ),
                    _buildSliderRow(
                      label: 'Warp Frequency',
                      valueText: warpFrequency.toStringAsFixed(2),
                      child: Slider(
                        value: warpFrequency,
                        min: 0.05,
                        max: 0.4,
                        divisions: 35,
                        label: warpFrequency.toStringAsFixed(2),
                        onChanged: (v) =>
                            setSheetState(() => warpFrequency = v),
                      ),
                    ),
                    _buildSliderRow(
                      label: 'Edge Width',
                      valueText: edgeWidth.toStringAsFixed(2),
                      child: Slider(
                        value: edgeWidth,
                        min: 0.5,
                        max: 2.5,
                        divisions: 20,
                        label: edgeWidth.toStringAsFixed(2),
                        onChanged: (v) => setSheetState(() => edgeWidth = v),
                      ),
                    ),
                    _buildSliderRow(
                      label: 'Edge Gamma',
                      valueText: edgeGamma.toStringAsFixed(2),
                      child: Slider(
                        value: edgeGamma,
                        min: 1.0,
                        max: 2.5,
                        divisions: 15,
                        label: edgeGamma.toStringAsFixed(2),
                        onChanged: (v) => setSheetState(() => edgeGamma = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await game.terrain?.updateTerrainParams(
                              patchSizeBase: patchSizeBase,
                              patchJitter: patchJitter,
                              primaryWeight: primaryWeight,
                              warpAmplitude: warpAmplitude,
                              warpFrequency: warpFrequency,
                              edgeWidth: edgeWidth,
                              edgeGamma: edgeGamma,
                            );
                            saveParamPrefs();
                          },
                          icon: const Icon(Icons.tune),
                          label: const Text('Apply Params'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => game.terrain?.shuffleSeed(),
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Shuffle Seed'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildSliderRow({
    required String label,
    required String valueText,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text(valueText, style: const TextStyle(color: Colors.white54)),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
