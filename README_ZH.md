# <img src="images/icon.png" width="48" height="48" style="vertical-align:middle"> MDWriter (中文版)

[English](./README.md)

MDWriter 是一款专为 macOS 设计的现代、优雅且功能强大的 Markdown 编辑器，基于 SwiftUI 和 SwiftData 开发。灵感源自 Ulysses 等专业写作工具，它为你提供了一个专注的写作环境，同时具备强大的库管理和导出功能。

## 核心特性

- **专注写作体验**：简洁、无干扰的界面，支持打字机模式。
- **高级 Markdown 支持**：实时语法高亮和智能 Markdown 解析。
- **强大的库管理**：使用文件夹和嵌套分组组织笔记。基于 SwiftData，确保性能和可靠性。
- **文档大纲**：通过集成的导航大纲轻松穿梭于长文档之中。
- **实时统计**：实时掌握字符数、字数及预计阅读时间。
- **灵活导出**：支持将作品导出为 PDF、富文本 (RTF) 或标准 Markdown 格式。
- **个性化主题**：支持浅色和深色模式，并提供多种编辑器主题（如 Pure 等）。
- **排版控制**：可调节字体、行高、行宽和首行缩进，打造最舒适的写作环境。
- **快照与备份**：内置快照历史记录和完整的库备份/恢复功能（.mdwbk 文件），确保数据安全。
- **现代技术栈**：完全使用 SwiftUI、SwiftData 和最新的 macOS API 构建。

## 技术栈

MDWriter 使用了以下强大的开源库：
- **SwiftUI**：构建现代、原生的 macOS 用户界面。
- **SwiftData**：负责持久化存储和数据管理。
- **swift-markdown**：高性能 Markdown 解析。
- **Highlightr**：实现实时的代码和语法高亮。
- **Sparkle**：提供流畅的应用自动更新。
- **WhatsNewKit**：在版本更新后展示新功能。

## 快速上手

### 运行环境
- macOS 14.0 或更高版本
- Xcode 15.0 或更高版本

### 安装步骤
1. 克隆仓库：
   ```bash
   git clone https://github.com/yourusername/MDWriter.git
   ```
2. 在 Xcode 中打开 `MDWriter.xcodeproj`。
3. 编译并运行项目 (`Cmd + R`)。

## 开源协议

本项目采用 MIT 协议开源 - 详情请参阅 [LICENSE](LICENSE) 文件。
