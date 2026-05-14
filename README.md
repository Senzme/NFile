# NFile

A beautiful, premium, and feature-rich File Manager application built with Flutter.

## Overview
NFile is designed to provide a highly aesthetic file management experience on Android. It features a stunning interface with an exclusive "Broken" icon pack, dynamic AMOLED-friendly dark mode, and a fluid user experience.

## Features
- **Premium UI/UX:** A textured and alpha-blended aesthetic that gives a modern, glassmorphic feel to your file browsing.
- **Complete File Operations:** Easily copy, cut, paste, rename, and delete files or folders.
- **Deep Directory Navigation:** Browse internal storage and deeply nested folders with ease.
- **Quick Categories:** One-tap access to your Images, Videos, Audio, and Documents.
- **Storage Overview:** Visual representation of your device's internal storage usage.
- **Custom Iconography:** Utilizing the unique `Broken` icon pack for a fresh look.
- **Fluid Pull-to-Refresh:** iOS-style `CupertinoSliverRefreshControl` integrated into a custom scroll view.

## Screenshots
*(Add your screenshots here)*

## Permissions
The application requires the `MANAGE_EXTERNAL_STORAGE` permission on modern Android versions (Android 11+) to perform seamless file operations across the entire device storage.

## Building and Running
1. Clone this repository.
2. Run `flutter pub get` to install dependencies.
3. Run `flutter run` on an Android device or emulator.

## Technologies Used
- Flutter & Dart
- `provider` (State Management)
- `permission_handler` (Storage Permissions)
- `open_filex` (File opening capabilities)
- `mime` (File type detection)
- `path` & `path_provider` (Directory parsing)

## License
MIT License
