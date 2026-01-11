# MDWriter

<p align="center">
  <img src="MDWriter/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="MDWriter Icon" width="128" />
</p>

<p align="center">
  <b>An elegant, native Markdown editor for macOS, inspired by Ulysses.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS-000000.svg?style=flat-square&logo=apple" alt="Platform macOS" />
  <img src="https://img.shields.io/badge/Language-Swift-F05138.svg?style=flat-square&logo=swift" alt="Language Swift" />
  <img src="https://img.shields.io/badge/License-MPL-blue.svg?style=flat-square" alt="License MPL" />
</p>

---

## 📖 Introduction

**MDWriter** is a document-based Markdown editor built specifically for macOS. It combines the modern declarative UI of **SwiftUI** with the powerful text handling capabilities of **AppKit (NSTextView)** to provide a distraction-free writing experience.

Designed with a focus on typography and aesthetics, MDWriter offers a "paper-like" writing environment similar to high-end writing tools like Ulysses, but fully open-source.

## ✨ Features

### ✍️ Professional Writing Experience
*   **Native Performance**: Powered by a custom `NSTextView` wrapper for buttery smooth typing and precise cursor control.
*   **Distraction-Free**: Minimalist interface with a centered writing column.
*   **Custom Typography**: precise control over fonts (System, Serif, Mono), line height, paragraph spacing, and content width.
*   **Themes**: Light, Dark, and System modes with carefully tuned "Paper" background colors.

### 📚 Structure & Organization
*   **Auto Outline**: Sidebar automatically generates a table of contents based on your headers (`#`).
*   **Document-Based**: Native macOS file handling (Versions, Auto-save, Rename, Move).

### 🛠 Powerful Tools
*   **Live Preview**: Toggleable side-by-side Markdown preview with syntax highlighting (powered by `MarkdownUI`).
*   **Statistics**: Real-time word count, character count, and estimated reading time.
*   **Image Support**: Drag and drop or insert local images directly into your document.

### 📤 Export & Sharing
*   **PDF**: Export beautifully rendered PDFs with styled layouts.
*   **Word (RTF)**: Export rich text for compatibility with Microsoft Word.
*   **Markdown**: Share raw `.md` files.

### 🌍 Localization
*   **English** & **Simplified Chinese (简体中文)** support out of the box.

## 📸 Screenshots

*(Add your screenshots here)*

## 🚀 Installation

### Download
Check the [Releases](https://github.com/steve/MDWriter/releases) page for the latest compiled binary.

### Build from Source

**Requirements:**
*   macOS 14.0+
*   Xcode 15.0+

1.  Clone the repository:
    ```bash
    git clone https://github.com/steve/MDWriter.git
    cd MDWriter
    ```
2.  Open `MDWriter.xcodeproj` in Xcode.
3.  Wait for Swift Package Manager to resolve dependencies.
4.  Press `Cmd + R` to run.

## 📦 Dependencies

*   [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui): For rendering the beautiful Markdown preview.
*   [AppUpdater](https://github.com/s1ntoneli/AppUpdater): For automatic updates via GitHub Releases.

## 🤝 Contributing

Contributions are welcome! Feel free to submit a Pull Request.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---
Built with ❤️ using SwiftUI & AppKit.
