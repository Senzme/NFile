<div align="center">

# 🗂️ NFile — Premium Media Hub & File Manager

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Build & Release APK](https://github.com/Senzme/NFile/actions/workflows/build.yml/badge.svg)](https://github.com/Senzme/NFile/actions/workflows/build.yml)

**A next-generation, ultra-fast, aesthetic File Manager and Media Hub for Android, featuring hardware-accelerated media players, audio visualizers, and code/document editing.**

</div>

---

## ✨ Overview

**NFile** redefines Android file management by combining lightning-fast native indexing with a breathtaking, glassmorphic UI. Moving beyond a conventional file explorer, NFile acts as an all-in-one immersive media hub—allowing you to play high-res videos, enjoy music with live visualizers, inspect documents, and manage your storage flawlessly without ever leaving the app.

---

## 🚀 Key Features

### 💎 Next-Gen Aesthetics & UI/UX
* **Glassmorphic & Metallic UI:** Beautiful frosted glass overlays, custom depth shadows, and rich AMOLED dark themes.
* **Exclusive Iconography:** Bespoke icon sets tailored for every file type and system folder.
* **Bouncy & Fluid Physics:** Cupertino-style spring physics, silky-smooth transitions, and tactile micro-animations.

### 🎵 Advanced Modular Audio Player
* **Live Waveform Visualization:** Real-time animated frequency waveforms reflecting audio amplitudes.
* **Immersive Particle Visualizer:** Floating, dynamic background particle effects synced to the playback state.
* **Spinning Vinyl Artwork:** High-fidelity album art rendering with smooth rotational physics during playback.
* **Interactive Queue Sheet:** Seamlessly manage upcoming tracks, toggle repeat/shuffle modes, and jump across queues.
* **Persistent Playback Memory:** Remembers your exact track position and settings across sessions.

### 🎬 High-Performance Video Player
* **Hardware Acceleration:** Powered by `media_kit` for buttery-smooth 4K/60fps MKV, MP4, and WebM decoding.
* **Advanced Gesture Controls:** Interactive vertical sliders on screen edges for instant Volume and Brightness adjustments. Swipe horizontally for precise seeking.
* **Floating Controls Overlay:** Sleek, auto-hiding OSD with quick speed toggles, aspect-ratio switching, and seek indicators showing exact time deltas.

### 📄 Built-in Document & Text Suite
* **Multi-Format Support:** Instantly open, view, and edit `.txt`, `.md`, `.json`, `.xml`, and source code files.
* **Syntax & Formatting:** Clean line numbering, adjustable typography scaling, and distraction-free reading modes.
* **In-App Editing:** Modify configuration files or take quick notes directly inside the storage explorer.

### 🖼️ High-Fidelity Image Viewer
* **Pinch-to-Zoom:** Fluid multi-touch scaling and smooth pan navigation.
* **Instant Gallery Swipe:** Seamlessly transition between hundreds of photos without lag.

### ⚡ Lightning-Fast Media Indexing & Operations
* **Native Android MediaStore Integration:** Bypasses slow recursive folder scanning. Audio, Images, Videos, and Documents appear instantly upon launch.
* **Robust File Operations:** Batch selection, instant cut/copy/paste, renaming, deletion, and directory creation.
* **Storage Analytics:** Real-time visual storage breakdown showing used capacity and remaining free space.

---

## 📸 Screenshots

| Home & Storage | Media Indexing | Audio Visualizer | Advanced Player |
|:---:|:---:|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/bf0782e6-9c6e-46e5-a93f-aaebb01b3d71" width="220"> | <img src="https://github.com/user-attachments/assets/66b864ed-2598-477c-bdb4-d045a71e93b9" width="220"> | <img src="https://github.com/user-attachments/assets/7ffbe12f-f045-4d22-9b0f-9cf6f5dd5416" width="220"> | <img src="https://github.com/user-attachments/assets/ca1e78e0-8e68-4985-bc9c-39e763b8ed74" width="220"> |

---

## 🛠️ Architecture & Tech Stack

```yaml
Core Framework: Flutter (Dart)
Media Engine: media_kit & video_player
Audio Indexing: on_audio_query
Gallery Indexing: photo_manager
State Management: provider
Permissions: permission_handler
Document & Image Viewing: photo_view, open_filex
CI/CD Pipeline: GitHub Actions (Automated Release APK Generation)
```

---

## 📦 Automated Releases & Downloads

Every push to the `main` branch automatically triggers our GitHub Actions workflow, compiling a fully optimized, release-grade Android APK.

📥 **[Download the Latest APK from the Releases Page](https://github.com/Senzme/NFile/releases/latest)**

---

## 🔐 Permissions & Privacy

To deliver its robust capabilities, NFile requests the following standard permissions:
* `MANAGE_EXTERNAL_STORAGE`: Essential for full-device file manipulation and organization.
* `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_AUDIO`: Required for ultra-fast, zero-lag media category indexing.

*NFile operates 100% locally on your device. Your data and media never leave your phone.*

---

## 💻 Building Locally

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/Senzme/NFile.git
   cd NFile
   ```
2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```
3. **Compile & Run:**
   ```bash
   flutter run --release
   ```

---

<div align="center">

**Built with ❤️ for Android** • [MIT License](LICENSE)

</div>
