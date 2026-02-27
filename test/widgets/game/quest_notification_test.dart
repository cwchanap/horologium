import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/widgets/game/quest_notification.dart';

void main() {
  group('QuestNotification', () {
    testWidgets('shows quest completed message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QuestNotification(questName: 'Build Houses')),
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
  });
}
