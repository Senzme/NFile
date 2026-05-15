# NFile

A beautiful, premium, and feature-rich File Manager application built with Flutter.

## Overview
NFile is designed to provide a highly aesthetic file management experience on Android. It features a stunning interface with an exclusive "Broken" icon pack, dynamic AMOLED-friendly dark mode, and a fluid user experience. 

With the latest update, NFile transitions from a simple file explorer to a comprehensive media hub with built-in high-performance players and viewers.

## Features
- **Premium UI/UX:** A textured and alpha-blended aesthetic that gives a modern, glassmorphic feel to your file browsing.
- **Native Media Indexing:** Lightning-fast gallery views for Images, Videos, and Audio using native device indexing. No more slow recursive scans.
- **Built-in Media Players:**
    - **High-Performance Video Player:** Powered by `media_kit` for smooth playback of high-resolution videos.
    - **Elegant Audio Player:** Clean playback interface with album art support and precise seeking.
    - **Pinch-to-Zoom Image Viewer:** View your memories in full detail with smooth gestures.
- **Built-in Text Editor:** View and edit `.txt`, `.md`, `.json`, and other code files directly within the app.
- **Advanced Sorting:** Filter your media by Newest, Oldest, or Date-wise to find what you need instantly.
- **Complete File Operations:** Easily copy, cut, paste, rename, and delete files or folders.
- **Quick Categories:** One-tap access to your indexed media libraries.
- **Storage Overview:** Visual representation of your device's internal storage usage.
- **Fluid UI:** iOS-style bouncy physics and smooth transitions throughout the app.

## Screenshots

| | | | |
|:---:|:---:|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/bf0782e6-9c6e-46e5-a93f-aaebb01b3d71" width="200"> | <img src="https://github.com/user-attachments/assets/66b864ed-2598-477c-bdb4-d045a71e93b9" width="200"> | <img src="https://github.com/user-attachments/assets/7ffbe12f-f045-4d22-9b0f-9cf6f5dd5416" width="200"> | <img src="https://github.com/user-attachments/assets/ca1e78e0-8e68-4985-bc9c-39e763b8ed74" width="200"> |


## Permissions
The application requires the following permissions for full functionality:
- `MANAGE_EXTERNAL_STORAGE`: For seamless file operations across the entire device.
- `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`: For high-speed native media indexing.

## Building and Running
1. Clone this repository.
2. Run `flutter pub get` to install dependencies.
3. Run `flutter run` on an Android device (API 21+ required).

## Technologies Used
- **Flutter & Dart**
- **State Management:** `provider`
- **Media Engine:** `media_kit` (Video & Audio playback)
- **Indexing:** `photo_manager` & `on_audio_query`
- **Permissions:** `permission_handler`
- **Viewers:** `photo_view` & `open_filex`

## License
MIT License
