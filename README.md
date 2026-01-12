# MDWriter

<p align="center">
  <img src="MDWriter/Assets.xcassets/AppIcon.appiconset/icon_1024x1024@2x.png" alt="MDWriter Icon" width="128" />
</p>

<p align="center">
  <b>A professional, native Markdown editor for macOS, inspired by Ulysses.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0+-000000.svg?style=flat-square&logo=apple" alt="Platform macOS" />
  <img src="https://img.shields.io/badge/Language-Swift-F05138.svg?style=flat-square&logo=swift" alt="Language Swift" />
  <img src="https://img.shields.io/badge/Architecture-Universal-blue.svg?style=flat-square" alt="Universal Binary" />
  <img src="https://img.shields.io/badge/License-MPL%202.0-green.svg?style=flat-square" alt="License MPL" />
</p>

---

## 📖 Introduction

**MDWriter** is a native Markdown editor designed for focused writing and efficient organization on macOS. Version 1.1 introduces a complete UI overhaul inspired by high-end writing tools like Ulysses, featuring an immersive three-column library and a professional typography engine.

## ✨ Features (v1.1)

### ✍️ Immersive Writing Experience
*   **Immersive UI**: Hidden system title bar allows your content to flow to the very top of the window.
*   **Native Performance**: Powered by a custom `NSTextView` wrapper for buttery smooth typing and precise control.
*   **Custom Typography**: Precise control over fonts (System UI, System Serif, Monospaced), line height, paragraph spacing, and content width.
*   **Dashboard**: Real-time word count, character count, and estimated reading time in a beautiful floating capsule.

### 📚 Powerful Organization
*   **Three-Column Library**: Effortlessly manage your library (Folders → Document List → Editor) in a single unified view.
*   **Rich Previews**: The document list shows titles, 2-line content summaries, and modification dates.
*   **Instant Sync**: All changes are saved automatically as you type.

### 🛠 Professional Tools
*   **Live Preview**: Toggleable side-by-side Markdown rendering with syntax highlighting.
*   **Right-side Outline**: Navigate complex documents easily with a toggleable structure panel on the right.
*   **Image Support**: Seamlessly insert local images into your Markdown documents.

### 📤 Export & Sharing
*   **Styled PDF**: Export beautifully rendered PDFs optimized for A4 paper.
*   **Word (RTF)**: Export rich text compatible with Microsoft Word.
*   **Markdown**: Share or backup raw `.md` files.

### 🌍 Localization
*   Full support for **English** and **Simplified Chinese (简体中文)**.

## 📸 Screenshots

*(Add your beautiful screenshots here)*

## 🚀 Installation

### Download
Download the latest **Universal Binary** (supports both Apple Silicon and Intel) from the [Releases](https://github.com/lpgneg19/MDWriter/releases) page.

### Build from Source
**Requirements:**
*   macOS 14.0+
*   Xcode 15.0+

1.  Clone the repository:
    ```bash
    git clone https://github.com/lpgneg19/MDWriter.git
    cd MDWriter
    ```
2.  Open `MDWriter.xcodeproj` in Xcode.
3.  Build and Run (`Cmd + R`).

## 📦 Dependencies

*   [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui): Elegant Markdown rendering.
*   [Ink](https://github.com/JohnSundell/Ink): Markdown to HTML conversion for high-quality exports.
*   [AppUpdater](https://github.com/s1ntoneli/AppUpdater): Automatic update checking via GitHub.

## 📄 License

Distributed under the Mozilla Public License 2.0. See `LICENSE` for more information.

---
Built with ❤️ using SwiftUI & AppKit.