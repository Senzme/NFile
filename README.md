# NFile

<div align="center">
  <h3>A Premium, Ultra-Fast & Enterprise-Grade Android File Manager & Universal Media Hub</h3>
  <p>Built with Flutter & Dart for the ultimate fluid experience.</p>
</div>

---

## 🌟 Overview
**NFile** is engineered to redefine file management on Android with state-of-the-art glassmorphic aesthetics, fluid iOS-style bouncy physics, and lightning-fast native media indexing. 

Far beyond a traditional file explorer, NFile acts as an all-in-one universal media powerhouse—capable of handling complex split-APK bundles, creating encrypted multi-volume archives, rendering offline Microsoft Office documents, and serving as a native system viewer for external apps like WhatsApp and Gmail.

---

## 🔥 Key Features

### 🎨 Premium Adaptive Aesthetics & Customization
- **Obsidian Slate to Sky Blue Gradients**: A stunning AMOLED-friendly dark theme featuring deep textured gradients (`#1E293B` to `#0F172A`) with glowing Sky Blue accents.
- **High-Contrast Light Mode**: Curated deep, crisp color tokens (Deep Emerald Teal `#00796B` for Archives, Forest Green `#2E7D32` for Downloads, Deep Golden Amber `#F57C00` for APKs) ensuring pristine contrast against soft 15% opacity pastel background circles.
- **Interactive Shortcut Customizer**: A real-time modal bottom sheet equipped with hold-to-drag `ReorderableListView` and animated Switch toggles. Pin, unpin, and re-order your Home Screen category shortcuts with instant persistence.
- **Flawless Typography & Icons**: Exclusive "Broken" icon pack integration with zero text clipping or pixel overflows across all screen sizes.

---

### 📦 Universal Package Installer & Split-Bundle Engine (`ApkInstallerService`)
- **Direct Standalone APK Install**: Integrated `REQUEST_INSTALL_PACKAGES` permission allowing seamless installation of standard `.apk` files directly through Android 11+ Package Installer.
- **Multi-Split Package Extraction (`.xapk`, `.apks`, `.apkm`, `.aab`)**: Tapping a split package bundle opens an elegant background extraction dialog. NFile automatically unzips the split APKs into cache, scans for `.obb` expansion files and deploys them to `/Android/obb/`, and instantly launches the installer for the base package in a single one-tap flow.

---

### 🗜️ Enterprise-Grade Archive Engine (`ArchiveService` & `ArchiveViewerScreen`)
- **Multi-Format Compression**: Create `.zip`, `.tar`, `.tar.gz`, and `.tar.bz2` archives instantly with configurable compression levels (0 to 9).
- **Advanced ZIP Capabilities**: Secure archives with robust password encryption or split massive files into multi-volume chunks (`.001`, `.002`).
- **Virtual Archive Explorer**: Tap any archive to navigate inside it like a virtual folder. Preview internal files instantly without full extraction.
- **Internal Multi-Selection & Modification**: Select multiple files or folders inside an archive to perform direct deletions, copy, or cut-out extractions.
- **Built-In File Picker (`+ Add File`)**: Navigate internal storage directly within NFile to inject new files and recursive folders into existing archives.

---

### 📖 Universal Offline Document & Media Viewer (`DocumentViewerScreen`)
- **High-Fidelity PDF Engine**: Native rendering via `syncfusion_flutter_pdfviewer` with text search and fluid page navigation.
- **Microsoft Word (`.doc`, `.docx`)**: Extracts OpenXML formatting and presents clean text on a simulated virtual white paper UI.
- **Microsoft Excel (`.xls`, `.xlsx`)**: Parses multi-sheet BIFF8 and OpenXML workbooks into interactive multi-tab spreadsheet tables.
- **Microsoft PowerPoint (`.ppt`, `.pptx`)**: Extracts slide-by-slide text and structure for clean offline review.
- **Built-in Code & Text Editor**: Fully interactive viewer and syntax editor for `.py`, `.js`, `.dart`, `.json`, `.md`, `.txt`, `.yaml`, and more.
- **High-Performance Audio & Video Players**: Hardware-accelerated playback powered by `media_kit` with album art extraction and precise timeline scrubbing.
- **Pinch-to-Zoom Image Viewer**: Pristine full-resolution gallery viewer with smooth gesture support.

---

### 🔗 System Integration & External Interception (`ReceiveSharingIntent`)
- **Native "Open With" Target**: Registers Android `VIEW` intent filters for PDFs, images, audio, video, archives, and Office docs. Tap any file in WhatsApp, Gmail, Telegram, or Files by Google to instantly view it inside NFile!
- **System Share Menu**: Direct file receiver for `SEND` and `SEND_MULTIPLE` intents allowing users to share media from anywhere directly into NFile.
- **Global Routing Engine**: Powered by a robust `GlobalKey<NavigatorState>` guaranteeing valid routing context whether NFile is running in memory or cold-starting from an external tap.
- **Universal JVM 17 Toolchain Alignment**: Flawless Gradle build integration enforcing Java 17 and Kotlin 17 across all plugins for bulletproof APK assembly.

---

## 📸 Screenshots

| Home Screen (Dark) | Home Screen (Light) | Virtual Archive Explorer | Universal Offline Viewer |
|:---:|:---:|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/bf0782e6-9c6e-46e5-a93f-aaebb01b3d71" width="200"> | <img src="https://github.com/user-attachments/assets/66b864ed-2598-477c-bdb4-d045a71e93b9" width="200"> | <img src="https://github.com/user-attachments/assets/7ffbe12f-f045-4d22-9b0f-9cf6f5dd5416" width="200"> | <img src="https://github.com/user-attachments/assets/ca1e78e0-8e68-4985-bc9c-39e763b8ed74" width="200"> |

---

## 🛡️ Permissions
For optimal performance, NFile utilizes:
- `MANAGE_EXTERNAL_STORAGE`: For complete recursive storage management across device files.
- `REQUEST_INSTALL_PACKAGES`: For direct installation of standalone `.apk` and split package bundles.
- `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`: For instant native media library indexing.

---

## 🚀 Building & Running
1. Clone this repository:
   ```bash
   git clone https://github.com/Senzme/NFile.git
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run on an Android device (API 21+ required, Android 11+ recommended):
   ```bash
   flutter run
   ```

---

## 🛠️ Architecture & Technologies
- **Framework:** Flutter (Dart)
- **State Management:** `provider`
- **Media Engine:** `media_kit` (Video & Audio playback)
- **Indexing & Queries:** `photo_manager`, `on_audio_query`
- **External Interception:** `receive_sharing_intent`
- **Document Viewers:** `syncfusion_flutter_pdfviewer`, `docx_to_text`, `excel`, `archive`

---

## 📄 License
Released under the **MIT License**.
