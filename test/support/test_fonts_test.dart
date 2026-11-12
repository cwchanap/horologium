@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

/// Host-only verification for the font fixture used by Chrome widget tests.
/// The `test/fonts` symlink keeps the fixture byte-identical to the production
/// assets without duplicating the font bytes.
void main() {
  test('font fixture covers pubspec and matches bundled bytes', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^\s*-\s+asset:\s*(assets/fonts/\S+)\s*$',
      multiLine: true,
    ).allMatches(pubspec).map((match) => match.group(1)!).toSet();

    expect(declared, isNotEmpty);
    expect(
      productionFontAssets.toSet(),
      declared,
      reason: 'the test loader must cover every declared font asset',
    );
    expect(
      FileSystemEntity.isLinkSync('test/fonts'),
      isTrue,
      reason: 'test/fonts must be a symlink to assets/fonts',
    );

    for (final asset in declared) {
      final fixture = File('test/fonts/${asset.split('/').last}');
      expect(
        fixture.existsSync(),
        isTrue,
        reason: '${fixture.path} must resolve to $asset',
      );
      expect(
        listEquals(fixture.readAsBytesSync(), File(asset).readAsBytesSync()),
        isTrue,
        reason: '${fixture.path} differs from $asset',
      );
    }
  });

  test('a missing font asset fails with its path', () async {
    await expectLater(
      loadFontFamily('Missing Orbitron', const [
        'assets/fonts/not-present.ttf',
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('assets/fonts/not-present.ttf'),
        ),
      ),
    );
  });
}
