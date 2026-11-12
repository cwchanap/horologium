import 'package:flutter/services.dart' show ByteData, FontLoader;

import 'test_font_environment_web.dart'
    if (dart.library.io) 'test_font_environment_io.dart';
import 'test_font_source_web.dart'
    if (dart.library.io) 'test_font_source_io.dart';

/// Every font family and asset declared in `pubspec.yaml`. Widget tests load
/// all of them through the VM files or the Chrome `test/fonts` symlink.
const Map<String, List<String>> productionFontFamilies = {
  'Orbitron': ['assets/fonts/Orbitron-Variable.ttf'],
  'IBM Plex Mono': [
    'assets/fonts/IBMPlexMono-400.ttf',
    'assets/fonts/IBMPlexMono-500.ttf',
    'assets/fonts/IBMPlexMono-600.ttf',
  ],
};

Iterable<String> get productionFontAssets =>
    productionFontFamilies.values.expand((paths) => paths);

/// Loads the exact font assets declared in `pubspec.yaml` for widget tests on
/// every platform. Chrome tests cannot read `dart:io` files or app assets, so
/// the web source fetches the same bytes through the `test/fonts` symlink,
/// which the web test server serves directly.
Future<void> loadProductionTestFonts() async {
  allowProductionFontsInWebTests();
  for (final entry in productionFontFamilies.entries) {
    await loadFontFamily(entry.key, entry.value);
  }
}

/// Loads [family] from [assetPaths], requiring every asset to be present.
Future<void> loadFontFamily(String family, List<String> assetPaths) async {
  final loader = FontLoader(family);
  for (final assetPath in assetPaths) {
    final bytes = await _requireFont(assetPath);
    loader.addFont(Future<ByteData>.value(bytes));
  }
  await loader.load();
}

Future<ByteData> _requireFont(String assetPath) async {
  ByteData? bytes;
  try {
    bytes = await loadTestFontBytes(assetPath);
  } catch (error) {
    throw StateError('Missing production test font asset: $assetPath ($error)');
  }
  if (bytes == null) {
    throw StateError('Missing production test font asset: $assetPath');
  }
  return bytes;
}

/// Restores the default web test environment after a suite that needed real
/// fonts. No-op on the VM.
void restoreProductionFontsInWebTests() => restoreWebTestFontEnvironment();
