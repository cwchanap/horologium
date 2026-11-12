import 'dart:ui_web' as ui_web;

/// Chrome widget tests bootstrap the engine in `flutterTester` mode, which
/// forces every text family to the built-in test font and ignores FontLoader.
/// Keep the other test-environment protections but allow real bundled fonts.
void allowProductionFontsInWebTests() {
  ui_web.TestEnvironment.setUp(
    const ui_web.TestEnvironment(
      ignorePlatformMessages: true,
      forceTestFonts: false,
      disableFontFallbacks: true,
      keepSemanticsDisabledOnUpdate: true,
      defaultToTestUrlStrategy: true,
    ),
  );
}

/// Restores the engine's default web test environment after a suite that
/// needed real fonts.
void restoreWebTestFontEnvironment() {
  ui_web.TestEnvironment.setUp(const ui_web.TestEnvironment.flutterTester());
}
