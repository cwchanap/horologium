# Repository Guidelines

## Project Structure & Module Organization
- `lib/` hosts gameplay logic; `lib/game/` covers Flame components, while `lib/main.dart` and `lib/main_menu.dart` keep the Flutter shell.
- `assets/images/` and `assets/audio/` store sprites, terrain atlases, and music referenced via the `Assets` helper.
- `test/` contains widget and scene tests; mirror new modules with matching `*_test.dart` files.
- `docs/` tracks feature briefs (terrain, parallax, etc.)—update when mechanics change.
- `scripts/` includes utility tooling; prefer adding maintenance tasks here instead of ad-hoc commands.

## Build, Test, and Development Commands
- `flutter pub get` fetches and locks dependencies; run after editing `pubspec.yaml`.
- `flutter run` launches the game; use `-d chrome` for a quick web pass or omit for native targets.
- `flutter test` executes unit, widget, and integration suites with mocked preferences.
- `flutter analyze` enforces static analysis defined in `analysis_options.yaml`.
- `flutter build apk` and `flutter build ios` generate release binaries for QA drops.

## Coding Style & Naming Conventions
- Follow Flutter defaults: 2-space indentation, trailing commas for multi-line literals, and `lowerCamelCase` for members.
- Keep Flame components in dedicated files named `<Feature>Component` to ease discovery.
- Run `dart format lib test` before committing; CI enforces these rules.
- Centralize constants in the relevant manager or `Assets` class rather than scattering magic values.

## Testing Guidelines
- Add tests beside features using the Flutter test package; name files `<feature>_test.dart` and groups with clear scenario labels.
- Use `SharedPreferences.setMockInitialValues` to seed resource or building state.
- Prefer deterministic timers by overriding Flame tickers or injecting clocks for verification.
- Ensure new resource or building logic updates both success and failure branches in tests.

## Commit & Pull Request Guidelines
- Adopt Conventional Commits (`feat:`, `fix:`, `chore:`, `ci:`) as in the git history.
- Keep commits focused: gameplay change, UI tweak, and tooling updates should land separately.
- Pull requests need a concise summary, testing notes (`flutter test`, manual device checks), and any relevant screenshots or screen recordings.
- Link issues or TODO references, and call out migrations that require data wipes or saved-game resets.

## Architecture Notes
- MainGame communicates with Flutter widgets through callbacks; when adding interactions, wire them in `MainGameWidget` and document the flow.
- SharedPreferences persists core state—update key constants in one place and provide migration steps if formats shift.
