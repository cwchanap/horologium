# Horologium Copilot compatibility guidance

Horologium is a Flutter/Flame casual stellar mining idle game.

- Use `lib/mining` as the gameplay vertical slice and preserve its
  `MainMenu` -> `MiningScreen` ownership boundary.
- Keep gameplay mutations behind `MiningController` and deterministic economy
  logic in `MiningSimulation`.
- Preserve the strict, unversioned `horologium.mining.save` document unless a
  shipped compatibility need explicitly requires a contract change.
- Keep the current `ResourceType` identities and asset-backed presentation;
  retain development fallbacks where the renderer provides them.
- Do not reintroduce retired city domains or speculative frameworks.
- Run focused tests plus `flutter analyze --fatal-infos`, Dart formatting, and
  the relevant Flutter tests/builds for every change.

Detailed architecture and workflow guidance lives in `../CLAUDE.md`.
