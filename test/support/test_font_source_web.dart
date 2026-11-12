import 'dart:ui_web' as ui_web;

import 'package:flutter/services.dart' show ByteData;

final ui_web.AssetManager _fonts = ui_web.AssetManager(assetsDir: '/fonts');

/// Loads a production font through the test server's `test/fonts` symlink.
Future<ByteData?> loadTestFontBytes(String assetPath) {
  return _fonts.load(assetPath.split('/').last);
}
