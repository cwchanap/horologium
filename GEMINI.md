# Horologium

## Overview

Horologium is a Flutter-based mobile application that appears to be a game with a space theme, suggested by the title "Horologium - Space Explorer" and the use of the Flame game engine. The project is structured as a standard Flutter application with Android and iOS targets.

## Tech Stack

- **Language:** Dart
- **Framework:** Flutter
- **Game Engine:** Flame
- **Platform:** Android, iOS

## Key Dependencies

- `flutter`: The core Flutter framework.
- `flame`: A 2D game engine for Flutter.
- `cupertino_icons`: For iOS-style icons.
- `shared_preferences`: For storing simple data.

## Project Structure

```
.
├── android
├── assets
│   └── images
│       └── building
├── build
├── lib
│   ├── constants
│   ├── game
│   │   ├── building
│   │   ├── managers
│   │   ├── resources
│   │   └── services
│   ├── pages
│   └── widgets
│       ├── cards
│       └── game
├── scripts
├── test
│   └── widgets
│       └── game
└── web
```

- `lib/main.dart`: The entry point of the application. It sets up the `MaterialApp` and defines the overall theme.
- `lib/main_menu.dart`: The main menu of the game.
- `lib/game/`: Contains the core game logic.
  - `lib/game/building/`: Defines the building logic.
  - `lib/game/grid.dart`: Defines the grid system for the game.
  - `lib/game/resources/`: Manages game resources.
  - `lib/game/scene.dart`: Manages the game scene.
- `android/`: Android-specific project files.
- `ios/`: iOS-specific project files.
- `test/`: Contains the widget tests.
- `assets/`: Contains all the images and other assets for the game.
- `scripts/`: Contains helper scripts for the project.

## Getting Started

To run the application, you will need to have Flutter installed.

1. **Clone the repository.**
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run the application:**
   ```bash
   flutter run
   ```

## Build and Test

- **Build:**
  ```bash
  flutter build <platform>
  ```
  (e.g., `flutter build apk`, `flutter build ios`)

- **Test:**
  ```bash
  flutter test
  ```

## Dependencies

- `cupertino_icons: ^1.0.8`
- `flame: ^1.30.0`
- `shared_preferences: ^2.5.3`

## Scripts

- `scripts/resize_buildings.py`: A Python script to resize building images.
