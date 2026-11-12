import 'dart:io';

import 'package:flutter/services.dart' show ByteData;

/// Reads the pubspec font asset from the workspace on the VM.
Future<ByteData?> loadFontAsset(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  return ByteData.sublistView(await file.readAsBytes());
}
