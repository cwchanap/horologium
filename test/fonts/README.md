# Test font fixtures

These are byte-identical copies of the font files declared under
`assets/fonts` in `pubspec.yaml`. The Flutter web test server serves the
`test/` directory, so Chrome widget tests load these copies through
`ui_web.AssetManager(assetsDir: '/fonts')`; the VM tests read the production
assets directly.

`test/support/test_fonts_test.dart` fails the VM suite if any copy is missing,
stale, or not matched by the pubspec-declared font list. The `OFL.txt` files
are the licenses shipped with the Orbitron and IBM Plex Mono fonts.
