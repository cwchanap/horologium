import 'dart:io';

import 'package:flutter/services.dart' show ByteData;

/// Reads a production font from the workspace on the VM.
Future<ByteData?> loadTestFontBytes(String assetPath) async {
  final file = File(assetPath);
  if (!file.existsSync()) return null;
  return ByteData.sublistView(await file.readAsBytes());
}
