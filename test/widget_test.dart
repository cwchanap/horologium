// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/main.dart';

void main() {
  testWidgets('Main menu displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HorologiumApp());

    // pumpAndSettle will time out because of the repeating star animation,
    // so we pump for a few seconds to let the other animations finish.
    await tester.pump(const Duration(seconds: 3));

    // Verify that our main menu elements are present.
    expect(find.text('HOROLOGIUM'), findsOneWidget);
    expect(find.text('STELLAR EXPLORER'), findsOneWidget);
    expect(find.text('START EXPEDITION'), findsOneWidget);
    expect(find.text('STELLAR MAP'), findsOneWidget);
    expect(find.text('RESEARCH LAB'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);

    // Test that the buttons are tappable
    final startButton = find.text('START EXPEDITION');
    expect(startButton, findsOneWidget);

    // Just verify the button exists and is tappable (without actually navigating)
    final widget = tester.widget<ElevatedButton>(find.ancestor(
      of: startButton,
      matching: find.byType(ElevatedButton),
    ));
    expect(widget.onPressed, isNotNull);
  });
}

