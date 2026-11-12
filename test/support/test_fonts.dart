import 'package:flutter/services.dart' show ByteData, FontLoader;

import 'test_font_bytes_web.dart'
    if (dart.library.io) 'test_font_bytes_io.dart';
import 'test_font_environment_web.dart'
    if (dart.library.io) 'test_font_environment_io.dart';

/// Loads the exact font assets declared in `pubspec.yaml` for widget tests on
/// every platform. The VM implementation reads the workspace files; Chrome
/// tests cannot read `dart:io` files or app assets, so the web implementation
/// embeds the same bytes and lets the engine use real fonts instead of the
/// forced test font.
Future<void> loadProductionTestFonts() async {
  allowProductionFontsInWebTests();
  await _load('Orbitron', const ['assets/fonts/Orbitron-Variable.ttf']);
  await _load('IBM Plex Mono', const [
    'assets/fonts/IBMPlexMono-400.ttf',
    'assets/fonts/IBMPlexMono-500.ttf',
    'assets/fonts/IBMPlexMono-600.ttf',
  ]);
}

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var loaded = false;
  for (final path in paths) {
    final bytes = await loadFontAsset(path);
    if (bytes == null) continue;
    loaded = true;
    loader.addFont(Future<ByteData>.value(bytes));
  }
  if (loaded) await loader.load();
}

/// Restores the default web test environment after a suite that needed real
/// fonts. No-op on the VM.
void restoreProductionFontsInWebTests() => restoreWebTestFontEnvironment();
