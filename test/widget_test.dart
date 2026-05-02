// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/main.dart' as app;

void main() {
  testWidgets('Main menu displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const app.HorologiumApp());

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
    final widget = tester.widget<ElevatedButton>(
      find.ancestor(of: startButton, matching: find.byType(ElevatedButton)),
    );
    expect(widget.onPressed, isNotNull);
  });

  testWidgets('main installs global error handlers', (
    WidgetTester tester,
  ) async {
    final previousFlutterErrorHandler = FlutterError.onError;
    final previousPlatformErrorHandler = ui.PlatformDispatcher.instance.onError;
    final previousDebugPrint = debugPrint;
    final printedMessages = <String>[];

    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        printedMessages.add(message);
      }
    };

    try {
      app.main();
      await tester.pump();

      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('flutter handler test'),
          stack: StackTrace.current,
        ),
      );
      final handled = ui.PlatformDispatcher.instance.onError!(
        StateError('platform handler test'),
        StackTrace.current,
      );

      expect(handled, isFalse);
      expect(
        printedMessages.any(
          (message) => message.contains('FlutterError: Bad state'),
        ),
        isTrue,
      );
      expect(
        printedMessages.any(
          (message) => message.contains('PlatformDispatcher error: Bad state'),
        ),
        isTrue,
      );
    } finally {
      FlutterError.onError = previousFlutterErrorHandler;
      ui.PlatformDispatcher.instance.onError = previousPlatformErrorHandler;
      debugPrint = previousDebugPrint;
    }
  });
}
