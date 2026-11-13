import 'dart:ui_web' as ui_web;

import 'package:flutter/services.dart' show ByteData;

final ui_web.AssetManager _fonts = ui_web.AssetManager(assetsDir: '/fonts');

/// Loads a test-only production font copy served from `test/fonts`.
Future<ByteData?> loadTestFontBytes(String assetPath) {
  return _fonts.load(assetPath.split('/').last);
}
