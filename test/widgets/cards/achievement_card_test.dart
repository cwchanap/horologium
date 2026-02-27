import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/achievements/achievement.dart';
import 'package:horologium/widgets/cards/achievement_card.dart';

void main() {
  group('AchievementCard', () {
    testWidgets('shows locked state with lock icon', (tester) async {
      final achievement = Achievement(
        id: 'ach_test',
        name: 'Test Achievement',
        description: 'A test achievement',
        type: AchievementType.buildingCount,
        targetAmount: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AchievementCard(achievement: achievement)),
        ),
      );

      expect(find.text('Test Achievement'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('shows unlocked state with check icon', (tester) async {
      final achievement = Achievement(
        id: 'ach_test',
        name: 'Test Achievement',
        description: 'A test achievement',
        type: AchievementType.buildingCount,
        targetAmount: 10,
        isUnlocked: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AchievementCard(achievement: achievement)),
        ),
      );

      expect(find.text('Test Achievement'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows progress when not unlocked', (tester) async {
      final achievement = Achievement(
        id: 'ach_test',
        name: 'Test Achievement',
        description: 'A test achievement',
        type: AchievementType.buildingCount,
        targetAmount: 10,
      );
      achievement.currentAmount = 5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AchievementCard(achievement: achievement)),
        ),
      );

      expect(find.text('5 / 10'), findsOneWidget);
    });

    testWidgets('shows description on tap', (tester) async {
      final achievement = Achievement(
        id: 'ach_test',
        name: 'Test Achievement',
        description: 'A test achievement description',
        type: AchievementType.buildingCount,
        targetAmount: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AchievementCard(achievement: achievement)),
        ),
      );

      await tester.tap(find.text('Test Achievement'));
      await tester.pumpAndSettle();

      expect(find.text('A test achievement description'), findsOneWidget);
    });
  });
}
