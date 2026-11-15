/// The VM widget test binding already renders with the loaded FontLoader
/// families, so there is no web-specific environment override.
void allowProductionFontsInWebTests() {}

/// No-op on the VM: `FontCollection::LoadFontFromList` cannot unload fonts
/// within an isolate, so VM font-loading tests must isolate at the file level.
void restoreWebTestFontEnvironment() {}
