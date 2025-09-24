import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/widgets/game/game_controls.dart';
import 'package:horologium/game/main_game.dart';

void main() {
  group('GameControls Widget Tests', () {
    late MainGame mockGame;
    bool escapePressed = false;

    setUp(() {
      mockGame = MainGame();
      escapePressed = false;
    });

    testWidgets('renders child widget correctly', (WidgetTester tester) async {
      const testChild = Text('Test Child');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameControls(
              game: mockGame,
              child: testChild,
              onEscapePressed: () => escapePressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('has KeyboardListener and MouseRegion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameControls(
              game: mockGame,
              child: const Text('Test'),
              onEscapePressed: () => escapePressed = true,
            ),
          ),
        ),
      );

      expect(find.byType(KeyboardListener), findsOneWidget);
      expect(find.byType(MouseRegion), findsAtLeastNWidgets(1));
    });

    testWidgets('calls onEscapePressed when Escape key is pressed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameControls(
              game: mockGame,
              child: const Text('Test'),
              onEscapePressed: () => escapePressed = true,
            ),
          ),
        ),
      );

      // Simulate Escape key press
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(escapePressed, isTrue);
    });

    testWidgets('does not call onEscapePressed for other keys', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameControls(
              game: mockGame,
              child: const Text('Test'),
              onEscapePressed: () => escapePressed = true,
            ),
          ),
        ),
      );

      // Simulate other key presses
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(escapePressed, isFalse);
    });

    testWidgets('works without onEscapePressed callback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameControls(
              game: mockGame,
              child: const Text('Test'),
              // No onEscapePressed callback
            ),
          ),
        ),
      );

      // Should not throw when Escape is pressed
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Test passes if no exception is thrown
    });

    testWidgets('handles mouse hover events', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameControls(
              game: mockGame,
              child: const SizedBox(width: 200, height: 200),
              onEscapePressed: () => escapePressed = true,
            ),
          ),
        ),
      );

      // Simulate mouse hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(100, 100));
      await gesture.moveTo(const Offset(150, 150));
      await tester.pump();

      // Test passes if no exception is thrown during hover
    });

    testWidgets('KeyboardListener has correct focus setup', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameControls(
              game: mockGame,
              child: const Text('Test'),
              onEscapePressed: () => escapePressed = true,
            ),
          ),
        ),
      );

      final keyboardListener = tester.widget<KeyboardListener>(
        find.byType(KeyboardListener),
      );
      expect(keyboardListener.autofocus, isTrue);
      expect(keyboardListener.focusNode, isNotNull);
    });
  });
}
