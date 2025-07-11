# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Horologium is a Flutter-based mobile game with a space exploration theme. The project uses the Flame game engine for 2D game functionality and targets both Android and iOS platforms.

## Development Commands

- **Install dependencies**: `flutter pub get`
- **Run the application**: `flutter run`
- **Run tests**: `flutter test`
- **Build for Android**: `flutter build apk`
- **Build for iOS**: `flutter build ios`
- **Analyze code**: `flutter analyze`

## Code Architecture

### Core Structure
- `lib/main.dart` - Application entry point with MaterialApp setup and dark space theme
- `lib/scenes/main_menu.dart` - Animated main menu with starfield background and UI navigation
- `lib/scenes/game_scene.dart` - Flame game scene with grid rendering and camera zoom functionality

### Key Design Patterns
- **Scene-based architecture**: The app uses distinct scenes (main menu, game) for different states
- **Animation-heavy UI**: Multiple AnimationControllers for staggered animations (title, buttons, particles)
- **Custom painters**: StarfieldPainter for procedural background generation
- **Flame integration**: Game scenes use Flame's component system with CameraComponent and PositionComponent

### Game Features
- Pinch-to-zoom camera controls (1.0x to 4.0x zoom range)
- Grid-based game world rendering
- Animated starfield background with twinkling stars
- Floating particle effects

### Theme and Styling
- Dark space theme with cyan accent colors
- Custom text shadows and glowing effects
- Orbitron font family for futuristic appearance
- Gradient backgrounds and transparency effects

## Testing
- Widget tests are located in `test/widget_test.dart`
- Use `flutter test` to run all tests

## Platform Support
- Android: Uses Kotlin for platform-specific code
- iOS: Uses Swift for platform-specific code
- Both platforms configured with standard Flutter project structure