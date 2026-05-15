# NFile 🚀

A beautiful, premium, and feature-rich File Manager application built with Flutter.

[![GitHub Repo](https://img.shields.io/badge/GitHub-NFile-blue?style=for-the-badge&logo=github)](https://github.com/Senzme/NFile.git)

## 🎨 Overview
NFile is designed to provide a highly aesthetic file management experience on Android. It features a stunning interface with an exclusive "Broken" icon pack, dynamic AMOLED-friendly dark mode, and a fluid user experience.

## ✨ Features

### 📂 File Management
- **Premium UI/UX:** A textured and alpha-blended aesthetic that gives a modern, glassmorphic feel to your file browsing.
- **Complete File Operations:** Easily copy, cut, paste, rename, and delete files or folders.
- **Deep Directory Navigation:** Browse internal storage and deeply nested folders with ease.
- **Storage Overview:** Visual representation of your device's internal storage usage.

### 🎥 Media & Viewing
- **Native Media Indexing:** Blazing fast indexing of Images, Videos, and Audio files using native system providers—no more waiting for scans.
- **Built-in Media Players:** High-performance video and audio playback powered by the robust `media_kit` engine.
- **Integrated Image Viewer:** A premium, zoomable image viewing experience with high-resolution support.
- **Smart Sorting:** Advanced filtering for media categories—sort by Newest, Oldest, or Date-wise with a single tap.

### 📝 Productivity
- **Built-in Text Editor:** View and edit `.txt`, `.md`, `.json`, and `.xml` files directly within the application.
- **Document Handler:** Seamlessly open PDFs and Office documents (DOCX, XLSX, PPTX) using the device's native system handlers for maximum compatibility.

## 📸 Screenshots
*(Add your screenshots here)*

## 🛠️ Permissions
The application requires the following permissions for full functionality:
- `MANAGE_EXTERNAL_STORAGE` (Android 11+) / `READ_EXTERNAL_STORAGE` (Legacy)
- `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` (Android 13+)

## 🚀 Building and Running
1. Clone the repository:
   ```bash
   git clone https://github.com/Senzme/NFile.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

## 📦 Technologies Used
- **Flutter & Dart**
- **media_kit** (High-performance playback)
- **photo_manager** (Native media indexing)
- **on_audio_query** (Music database management)
- **provider** (State Management)
- **open_filex** (External document handling)

## 📜 License
MIT License

---
Developed with ❤️ by [Senzme](https://github.com/Senzme)
