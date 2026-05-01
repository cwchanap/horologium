import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'main_menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('PlatformDispatcher error: $error');
    debugPrint(stack.toString());
    return true;
  };

  runApp(const HorologiumApp());
}

class HorologiumApp extends StatelessWidget {
  const HorologiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horologium - Space Explorer',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        fontFamily: 'Orbitron',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.cyanAccent,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.cyanAccent,
                offset: Offset(0, 0),
              ),
            ],
          ),
          headlineMedium: TextStyle(
            fontSize: 18,
            color: Colors.white70,
            letterSpacing: 2.0,
          ),
        ),
      ),
      home: const MainMenu(),
      debugShowCheckedModeBanner: false,
    );
  }
}
