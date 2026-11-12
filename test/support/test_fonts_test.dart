@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

Set<String> _declaredFontAssets() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  return RegExp(
    r'^\s*-\s+asset:\s*(assets/fonts/\S+)\s*$',
    multiLine: true,
  ).allMatches(pubspec).map((match) => match.group(1)!).toSet();
}

Map<String, List<int>> _bundledBytes(Set<String> declared) => {
  for (final asset in declared) asset: File(asset).readAsBytesSync(),
};

Map<String, List<int>> _fixtureBytes() => {
  for (final entity in Directory('test/fonts').listSync())
    if (entity is File && entity.path.endsWith('.ttf'))
      entity.uri.pathSegments.last: entity.readAsBytesSync(),
};

/// Checks that the test fixture covers exactly the declared assets and every
/// fixture byte matches the bundled production font.
void _expectFixtureParity({
  required Set<String> declared,
  required Map<String, List<int>> bundled,
  required Map<String, List<int>> fixture,
}) {
  final declaredNames = declared.map((asset) => asset.split('/').last).toSet();
  expect(
    fixture.keys.toSet(),
    declaredNames,
    reason: 'test/fonts must cover exactly the declared font assets',
  );
  for (final asset in declared) {
    final name = asset.split('/').last;
    expect(bundled[asset], isNotNull, reason: '$asset is not bundled');
    expect(
      fixture[name],
      orderedEquals(bundled[asset]!),
      reason: 'test/fonts/$name differs from $asset',
    );
  }
}

/// Host-only verification for the font fixture used by Chrome widget tests.
/// `test/fonts` holds regular byte-identical copies, so a symlink-disabled
/// checkout still runs the VM suite.
void main() {
  test('font fixture covers pubspec and matches bundled bytes', () {
    final declared = _declaredFontAssets();
    expect(declared, isNotEmpty);
    expect(
      productionFontAssets.toSet(),
      declared,
      reason: 'the test loader must cover every declared font asset',
    );
    expect(
      FileSystemEntity.isLinkSync('test/fonts'),
      isFalse,
      reason: 'test/fonts must be a regular directory, not a symlink',
    );
    expect(
      Directory('test/fonts').existsSync(),
      isTrue,
      reason: 'test/fonts must exist as a regular directory',
    );

    _expectFixtureParity(
      declared: declared,
      bundled: _bundledBytes(declared),
      fixture: _fixtureBytes(),
    );

    for (final notice in const ['OFL.txt', 'IBMPlexMono-OFL.txt']) {
      expect(
        File('test/fonts/$notice').readAsStringSync(),
        File('assets/fonts/$notice').readAsStringSync(),
        reason: 'test/fonts/$notice must match the bundled OFL notice',
      );
    }
  });

  test('stale fixture bytes are rejected', () {
    final declared = _declaredFontAssets();
    final bundled = _bundledBytes(declared);
    final fixture = _fixtureBytes();
    final name = declared.map((asset) => asset.split('/').last).first;
    final stale = [...fixture[name]!];
    stale[0] = stale[0] ^ 0xff;

    expect(
      () => _expectFixtureParity(
        declared: declared,
        bundled: bundled,
        fixture: {...fixture, name: stale},
      ),
      throwsA(isA<TestFailure>()),
    );
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
