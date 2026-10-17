# <img src="images/icon.png" width="48" height="48" style="vertical-align:middle"> MDWriter

<p align="center">
  <img src="MDWriter/Assets.xcassets/AppIcon.appiconset/mac_1024x1024@1x.png" alt="MDWriter Icon" width="128" />
</p>

<p align="center">
  <b>A professional, native, and local-first Markdown writing desk for macOS.</b><br/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0+-000000.svg?style=flat-square&logo=apple" alt="Platform macOS" />
  <img src="https://img.shields.io/badge/Language-Swift%206.0-F05138.svg?style=flat-square&logo=swift" alt="Language Swift" />
  <img src="https://img.shields.io/badge/Architecture-Universal-blue.svg?style=flat-square" alt="Universal Binary" />
  <img src="https://img.shields.io/badge/License-MPL%202.0-green.svg?style=flat-square" alt="License MPL" />
</p>

---
[中文版](./README_ZH.md)

MDWriter is a modern, elegant, and powerful Markdown writing desk for macOS, built purely with SwiftUI, SwiftData, and TextKit 2. Inspired by professional tools like Ulysses and Obsidian, it delivers a quiet, distraction-free environment paired with deep local-first AI intelligence, bidirectional linking, on-device vision OCR, external folder mounting, and rich publishing workflows.

---

## ✨ What's New in v4.0

### ⚡️ Inline AI Assistant & Visual Diff Review (`⌘K`)
* **Floating Command Bar**: Press `⌘K` anywhere in the editor to summon an Apple-native translucent command bar. Supports 8 preset actions (Polish, Shorten, Expand, Fix Grammar, Translate, Professional, Casual, Continue) or freeform natural language instructions.
* **Selection Floating Pill**: Select text to reveal a fluid floating action capsule for instant translation, shortening, and rewriting.
* **Visual Red-Green Diff Review**: Review AI proposed edits with unified line-by-line diff cards. Inspect character and word count deltas, switch between unified and split views, and accept (`⏎`), reject (`Esc`), or retry (`⌘R`) with automatic pre-edit deduplicated safety snapshots.

### 🔍 Local RAG & [[WikiLinks]] Bidirectional Knowledge
* **Local Semantic Vector Search (Local RAG)**: Powered by Apple's on-device `NaturalLanguage` framework (640-dim Chinese, 512-dim English sentence embeddings). Chunks notes into paragraph-level vectors with in-memory caching and hybrid keyword fusion—zero cloud dependencies.
* **Autonomous Knowledge Tool Calling**: AI assistant can call `semantic_search_library` to locate relevant knowledge slices across your entire library and generate clickable deep links (`mdwriter://note/<id>`).
* **`[[WikiLinks]]` & Backlinks Inspector**: Full Obsidian-style internal links. Type `[[Note Title]]` to navigate or create notes on the fly. The right dashboard features a dedicated Links tab showing all incoming backlinks with contextual excerpts.

### 👁️ On-Device Vision OCR & Ghost Text Autocomplete
* **Apple Vision Multimodal OCR**: Offline millisecond-grade text recognition for images and PDFs using Apple Vision (`VNRecognizeTextRequest`). Built-in `ocr_image_content` tool allows AI to extract and structure graphics into Markdown tables and outlines.
* **Proactive Ghost Text Predictions**: Typing pause of 1.2s triggers lightweight local predictive completions displayed in a subtle bottom capsule. Press `Tab ⇥` to instantly accept suggestions.

### 📂 External Folders Direct Mount & Menu Bar Quick Entry
* **External Local Folders Mounting**: Mount arbitrary directories from your disk using Security-Scoped Bookmarks. Enjoy two-way synchronization: external disk changes update MDWriter, and editor changes write back atomically to `.md` files on disk.
* **Menu Bar Quick Entry (`⌥⇧N`)**: Capture fleeting thoughts, memos, or meeting notes with a lightweight popover in the macOS menu bar. Hit `⌘⏎` to save directly to your Inbox.
* **CoreSpotlight Global Search**: Full-text and keyword indexed into macOS Spotlight. Search from anywhere in the OS and jump directly into notes via deep URLs.
* **macOS App Intents & Shortcuts**: Native Siri and Shortcuts integration with `CreateNoteIntent`, `SearchNotesIntent`, and `AppendToNoteIntent`.

### 🧮 LaTeX Math, Mermaid Diagrams & Combined Book Mode
* **Native KaTeX & Mermaid Rendering**: Inline and display math (`$...$`, `$$...$$`) and Mermaid flowcharts/diagrams render seamlessly in previews, PDF exports, and image cards.
* **Multi-Document Book Mode**: Combine multiple independent sheets or entire folders into a unified manuscript with automatic table of contents and chapter breaks.
* **Social Image Card Export**: Generate aesthetic, typography-rich social sharing card graphics in one click.

---

## 🛠 Core Features

### 🧠 Local-First AI & Local LLM Integration
* **Universal Local LLM Engines**: Connect to Ollama, LM Studio, oMLX, llama.cpp, MLX, Jan, or custom OpenAI-compatible endpoints with 100% data privacy.
* **AI Chat Panel (`⇧⌘L`)**: Dedicated right sidebar panel with persistent SwiftData chat histories, model switching, and real-time streaming thinking foldables (`<think>`).
* **29 Built-in Tool Calling Suite**: AI can manipulate editor text, manage notes and folders, inspect outlines, search snapshots, perform semantic RAG lookups, and run OCR.
* **Model Context Protocol (MCP)**: Native MCP Host powered by `mcp-swift-sdk @ 0.12.1`. Connect local filesystem, web fetchers, Puppeteer, and custom stdio tools.
* **Privacy-First Web Search**: DuckDuckGo (zero API key), SearXNG, Brave, Tavily, Exa, Google, and Bing search with source citation cards.

### ✍️ Professional Ulysses-Style Editor
* **Typography First**: Carefully tuned optical sizing, leading, and paragraph spacing optimized for Latin and CJK typography.
* **8 Curated Themes**: Pure, Solarized Light/Dark, GitHub, Dracula, Nord, Monokai, and Night Owl.
* **Typewriter Mode**: Keeps your active line vertically centered in the viewport.
* **MarkX Engine**: High-performance TextKit 2 native inline Markdown styling without WebView overhead.

### 📚 Library & Organization
* **SwiftData Database Architecture**: Reliable SQLite backend with lightning-fast search and relationships.
* **Three-Column Navigation**: Fluidly switch between Library, Note List, and the Editor.
* **Tags System**: Real-time tag counting and instant tag filtering.
* **Document Pinning & Templates**: Pin critical sheets to the top and scaffold new notes from built-in templates.
* **Safe Snapshots & Backups**: Automated deduplicated version snapshots, AES-256 encrypted `.mdwbk` full library backups, and Dropbox E2EE synchronization.

---

## 🚀 Installation

### Download Prebuilt App
Download the latest **Universal Binary** (Apple Silicon & Intel) from the [Releases](https://github.com/SteveShi/MDWriter/releases) page.

### Homebrew Cask
```bash
brew tap SteveShi/tap
brew install --cask mdwriter
```

### Build from Source
**Requirements:** macOS 14.0+, Xcode 16.0+, [Tuist](https://tuist.io/).

```bash
git clone https://github.com/SteveShi/MDWriter.git
cd MDWriter
tuist generate --no-open
xcodebuild -workspace MDWriter.xcworkspace -scheme MDWriter -configuration Debug -destination 'platform=macOS' build
```

---

## 📦 Tech Stack

- **SwiftUI & SwiftData**: Native macOS UI hierarchy and modern persistence.
- **MDEditorKit**: TextKit 2 based in-place Markdown editing component.
- **Apple NaturalLanguage & Vision**: On-device sentence embedding vector RAG and offline OCR.
- **Apple AppIntents & CoreSpotlight**: System-level Shortcuts actions and Spotlight search indexing.
- **mcp-swift-sdk**: Model Context Protocol client implementation.
- **Sparkle 2**: Frictionless in-app update delivery with bilingual release notes.

---

## 📄 License

MDWriter is released under the **Mozilla Public License 2.0 (MPL-2.0)**.
