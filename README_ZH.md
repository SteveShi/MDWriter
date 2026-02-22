# <img src="images/icon.png" width="48" height="48" style="vertical-align:middle"> MDWriter

<p align="center">
  <img src="MDWriter/Assets.xcassets/AppIcon.appiconset/mac_1024x1024@1x.png" alt="MDWriter Icon" width="128" />
</p>

<p align="center">
  <b>一款专为 macOS 打造的专业、原生 Markdown 编辑器。</b><br/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/平台-macOS%2014.0+-000000.svg?style=flat-square&logo=apple" alt="Platform macOS" />
  <img src="https://img.shields.io/badge/语言-Swift-F05138.svg?style=flat-square&logo=swift" alt="Language Swift" />
  <img src="https://img.shields.io/badge/架构-Universal-blue.svg?style=flat-square" alt="Universal Binary" />
  <img src="https://img.shields.io/badge/协议-MPL%202.0-green.svg?style=flat-square" alt="License MPL" />
</p>

---
[English](./README.md)

MDWriter 是一款专为 macOS 设计的现代、优雅且功能强大的 Markdown 编辑器，基于 SwiftUI 和 SwiftData 开发。灵感源自 Ulysses 等专业写作工具，它为你提供了一个专注的写作环境，同时具备强大的库管理和导出功能。

MDWriter 采用 **SwiftUI** 和 **SwiftData** 构建，提供原生性能、流畅的动画以及稳健的数据库架构。

## ✨ 特性

### ✍️ 专业级编辑器
*   **排版至上**：精心调整的行高、段落间距和页边距，确保最佳阅读体验（针对英文及中日韩/CJK 文字进行了优化）。
*   **主题系统**：内置 8 款专业主题（Pure, Solarized, GitHub, Dracula, Nord, Monokai, Night Owl），适配各种创作环境。
*   **打字机模式**：使光标始终保持在屏幕中央，让你专注于当前正在编写的那一行。
*   **MarkX 引擎**：自定义的基于正则的高亮引擎，提供精准、高性能的语法高亮，无需 WebView 开销。
*   **无干扰设计**：隐藏标题栏及简洁的 UI，让你完全沉浸在创作内容中。

### 📚 库与组织管理
*   **SwiftData 集成**：使用 SQLite 的现代数据库驱动架构，确保极速搜索和可靠的数据完整性。
*   **三栏式布局**：在流畅的原生 macOS 界面中轻松穿梭于文件夹、文档列表和编辑器。
*   **拖拽操作**：直观的组织方式——在文件夹、废纸篓之间拖动笔记，或重新排列层级结构。
*   **智能列表**：内置收件箱（Inbox）和废纸篓（Trash）管理。

### 📜 版本与备份 (v1.7 新特性)
*   **快照历史**：手动保存文档“版本”，并能以纯视觉方式浏览。查看字数、创建时间，并一键恢复至之前的状态。
*   **完整库备份**：将整个数据库（文件夹、笔记、快照）导出为单个 `.mdwbk` 文件。
*   **一键恢复**：轻松将你的库迁移到新机器，或从意外数据丢失中恢复。

### 🤖 Apple Intelligence 集成 (v2.0 新特性)
> [!IMPORTANT]
> **运行要求**：需要 macOS 26.0 或更高版本，以及搭载 Apple Silicon (M 系列) 芯片的 Mac。需在系统设置中开启 Apple Intelligence。

*   **端侧 AI 助手**：基于 Apple Foundation Models 的隐私优先 AI 助手面板。
*   **写作工具**：一键进行润色、摘要、翻译和校对。
*   **智能元数据**：根据内容自动生成描述性标题和相关标签。
*   **隐私至上**：所有处理均在本地进行，数据绝不离开你的设备。

### 📤 导出与分享
*   **PDF 导出**：生成简洁、针对 A4 优化的 PDF，包含精美的页眉和页脚。
*   **Word (RTF)**：导出具有广泛兼容性的富文本文件。
*   **标准 Markdown**：你的数据属于你。随时导出原始的 `.md` 文件。

### 🌍 本地化
*   **原生英文支持**
*   **简体中文**：完全本地化的 UI，包括菜单、设置和工具提示。

## 🚀 安装

### 下载
从 [Releases](https://github.com/lpgneg19/MDWriter/releases) 页面下载最新的 **Universal Binary**（同时支持 Apple Silicon 和 Intel 芯片）。

### 从源码编译
**要求：**
*   macOS 14.0+
*   Xcode 15.0+

1.  克隆仓库：
    ```bash
    git clone https://github.com/lpgneg19/MDWriter.git
    cd MDWriter
    ```
2.  使用 XcodeGen 生成项目文件：
    ```bash
    xcodegen generate --spec project.yml
    ```
3.  在 Xcode 中打开 `MDWriter.xcodeproj`。
4.  确保 Swift Package 依赖解析成功。
5.  编译并运行 (`Cmd + R`)。


## 📦 技术栈

MDWriter 利用了几个强大的开源库：
- **SwiftUI**：构建现代、原生的 macOS 用户界面。
- **SwiftData**：负责持久化存储和数据管理。
- **swift-markdown**：高性能 Markdown 解析。
- **Highlightr**：实现实时的代码和语法高亮。
- **Sparkle**：提供流畅的应用自动更新。
- **WhatsNewKit**：在版本更新后展示新功能。

### 运行环境
- macOS 14.0 或更高版本
- Xcode 15.0 或更高版本

## 开源协议

本项目采用 Mozilla公共许可证第2.0版 - 详情请参阅 [LICENSE](LICENSE) 文件。
