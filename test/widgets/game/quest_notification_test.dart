import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/widgets/game/quest_notification.dart';

void main() {
  group('QuestNotification', () {
    testWidgets('shows quest completed message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuestNotification(
              questId: 'quest_1',
              questName: 'Build Houses',
            ),
          ),
        ),
      );

      expect(find.text('Quest Complete!'), findsOneWidget);
      expect(find.text('Build Houses'), findsOneWidget);
    });

    testWidgets('auto-dismisses after duration', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestNotification(
              questId: 'quest_1',
              questName: 'Build Houses',
              onDismissed: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Quest Complete!'), findsOneWidget);

      // Advance past the auto-dismiss duration (3 seconds)
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('restarts animation when questId changes', (tester) async {
      var dismissCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestNotification(
              questId: 'quest_1',
              questName: 'Build Houses',
              duration: const Duration(seconds: 5),
              onDismissed: () => dismissCount++,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Change questId with same name - should restart
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestNotification(
              questId: 'quest_2',
              questName: 'Build Houses',
              duration: const Duration(seconds: 5),
              onDismissed: () => dismissCount++,
            ),
          ),
        ),
      );

      // Should not dismiss yet since timer restarted
      await tester.pump(const Duration(seconds: 2));
      expect(dismissCount, equals(0));

      // After 5 more seconds, it should dismiss
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(dismissCount, equals(1));
    });

    testWidgets('restarts dismiss timer when duration changes', (tester) async {
      var dismissCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestNotification(
              questId: 'quest_1',
              questName: 'Build Houses',
              duration: const Duration(seconds: 5),
              onDismissed: () => dismissCount++,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestNotification(
              questId: 'quest_1',
              questName: 'Build Houses',
              duration: const Duration(milliseconds: 100),
              onDismissed: () => dismissCount++,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(dismissCount, equals(1));
    });

    testWidgets('does not crash when widget is disposed before timer fires', (
      tester,
    ) async {
      // Show notification
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuestNotification(
              questId: 'quest_1',
              questName: 'Build Houses',
            ),
          ),
        ),
      );

      // Remove widget before the dismiss timer fires (simulates parent removing it)
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      // Advance past the dismiss timer — should not throw
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'does not call onDismissed if widget removed during reverse animation',
      (tester) async {
        var callCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QuestNotification(
                questId: 'quest_1',
                questName: 'Test Quest',
                duration: const Duration(milliseconds: 50),
                onDismissed: () => callCount++,
              ),
            ),
          ),
        );

        // Advance frame-by-frame past the 50ms timer so it fires and starts
        // the 300ms reverse animation, but without completing that animation
        // (a single pump(55ms) would run all frames synchronously and complete it).
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        // ~64ms elapsed: timer has fired and reverse animation is in flight.

        // Remove the widget from the tree before the 300ms reverse animation completes.
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );

        // Complete all pending animations/futures.
        await tester.pumpAndSettle();

        // onDismissed should NOT have been called because the widget was disposed
        // before the reverse animation completed.
        expect(callCount, equals(0));
      },
    );
  });
}
