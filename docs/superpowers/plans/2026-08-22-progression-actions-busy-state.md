# Progression Actions Busy-State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent stale Technology or Stellar Map interactions from queueing a second progression mutation while persistence is pending.

**Architecture:** Keep `MiningController` as the mutation owner and expose its existing synchronous `isBusy` state through `MiningScreen`. Guard sheet callbacks at `_runSheetAction()`, refresh immediately after starting an accepted mutation, and disable only the progression chrome buttons while busy.

**Tech Stack:** Dart, Flutter, flutter_test

## Global Constraints

- Keep Settings enabled while mining progression persistence is pending.
- Do not change controller queue semantics or persistence contracts.
- Keep sector tabs' current behavior unchanged.
- Use the existing `DelayedMiningSaveRepository` test double.

---

### Task 1: Prevent Duplicate Progression Actions

**Files:**
- Modify: `test/mining/presentation/mining_screen_test.dart:4-15,1208-1238`
- Modify: `lib/mining/presentation/mining_screen.dart:333-422,473-520`

**Interfaces:**
- Consumes: `MiningController.isBusy`, `TechnologySheet.onPurchase`, and `DelayedMiningSaveRepository.saveStarted`/`allowSave`.
- Produces: `_runSheetAction(Future<MiningActionResult> Function(), {required String successMessage})` that ignores callbacks while busy and progression `IconButton` widgets whose `onPressed` is null while busy.

- [ ] **Step 1: Write the failing widget regression test**

Add the Technology sheet import:

```dart
import 'package:horologium/mining/presentation/technology_sheet.dart';
```

Add this test after `a technology purchase flows through the controller`:

```dart
  testWidgets(
    'disables progression entry points and ignores stale sheet actions while saving',
    (tester) async {
      final repository = DelayedMiningSaveRepository();
      await MiningSaveRepository(
        content: MiningContentRegistry.stellarMining(),
      ).save(_techPurchaseSave());
      await pumpMiningScreen(
        tester,
        _viewports.first,
        repository: repository,
        disableAnimations: true,
      );

      await tester.tap(find.byKey(const Key('mining-technology-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final staleOnPurchase = tester
          .widget<TechnologySheet>(find.byType(TechnologySheet))
          .onPurchase;

      await tester.tap(
        find.byKey(const Key('mining-technology-buy-extraction')),
      );
      await repository.saveStarted.future;
      await tester.pump();

      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('mining-technology-button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('mining-stellar-map-button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('mining-settings-button')))
            .onPressed,
        isNotNull,
      );

      staleOnPurchase(TechnologyTrack.extraction);
      repository.allowSave.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final handles =
          tester.state(find.byType(MiningScreen)) as MiningScreenHandles;
      expect(handles.controller.state.technology.extraction, 1);
      expect(handles.controller.state.cash, 700);
      expect(tester.takeException(), isNull);
    },
  );
```

- [ ] **Step 2: Run the regression test and verify the expected failure**

Run:

```sh
flutter test test/mining/presentation/mining_screen_test.dart --plain-name 'disables progression entry points and ignores stale sheet actions while saving'
```

Expected: FAIL because the Technology button callback is not null while the delayed save is pending. Without the assertions, invoking `staleOnPurchase` would queue the level 2 purchase.

- [ ] **Step 3: Implement the minimal busy-state protection**

In `_runSheetAction()`, reject duplicate callbacks, retain the operation future, and refresh before awaiting it:

```dart
  Future<void> _runSheetAction(
    Future<MiningActionResult> Function() operation, {
    required String successMessage,
  }) async {
    if (!_initialized || _controller.isBusy) return;
    final pendingOperation = operation();
    _refreshPresentation();
    try {
      final result = await pendingOperation;
      if (!mounted) return;
      _refreshPresentation();
      if (result.isSuccess) {
        unawaited(HapticFeedback.lightImpact());
        _showResult(successMessage);
      } else {
        _showResult(result.message ?? 'Action failed.');
      }
    } catch (_) {
      if (!mounted) return;
      _refreshPresentation();
      _showResult('Action failed.');
    }
  }
```

Make `_chromeIconButton` accept a nullable callback:

```dart
  Widget _chromeIconButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
```

Pass null for the Technology and Stellar Map callbacks while busy, leaving Settings unchanged:

```dart
              _chromeIconButton(
                key: const Key('mining-technology-button'),
                tooltip: 'Technology',
                icon: Icons.science,
                onPressed: _controller.isBusy ? null : _openTechnology,
              ),
              const SizedBox(width: 8),
              _chromeIconButton(
                key: const Key('mining-stellar-map-button'),
                tooltip: 'Stellar Map',
                icon: Icons.map_outlined,
                onPressed: _controller.isBusy ? null : _openStellarMap,
              ),
```

- [ ] **Step 4: Run the focused regression test and full presentation suite**

Run:

```sh
flutter test test/mining/presentation/mining_screen_test.dart --plain-name 'disables progression entry points and ignores stale sheet actions while saving'
flutter test test/mining/presentation/mining_screen_test.dart
```

Expected: both commands PASS with no exceptions or warnings.

- [ ] **Step 5: Format, analyze, and inspect the final diff**

Run:

```sh
dart format lib/mining/presentation/mining_screen.dart test/mining/presentation/mining_screen_test.dart
dart format --output=none --set-exit-if-changed lib/mining/presentation/mining_screen.dart test/mining/presentation/mining_screen_test.dart
flutter analyze --fatal-infos
git diff --check
git diff -- lib/mining/presentation/mining_screen.dart test/mining/presentation/mining_screen_test.dart
```

Expected: formatting check exits 0, analyzer reports no issues, `git diff --check` exits 0, and the diff contains only the regression test and busy-state protection described above.
