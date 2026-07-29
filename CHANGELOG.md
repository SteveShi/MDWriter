# CHANGELOG

## [3.1.0] - 2026-07-29

### Added
- **AES-256 Encrypted Backup & Restore**: Secure library backup export and import (`.mdwbk`) encrypted with AES-256-GCM and 20,000-round PBKDF2 key derivation. Master encryption password stored safely in macOS Keychain.
- **Dropbox Cloud Sync with E2EE**: End-to-end encrypted synchronization supporting both native local Dropbox directories and Dropbox REST API token modes. All synced documents are encrypted locally before uploading.
- **CJK Italic Obliqueness**: Fixed CJK and Chinese character italic rendering in AppKit TextKit 2 editor by applying `.obliqueness: 0.2` character slant.
- **Full Markdown Syntax Alignment**: Standardized inline Markdown regex parsing for `*italic*`, `_italic_`, `**bold**`, `__bold__`, `***bolditalic***`, and `___bolditalic___`.
- **PDF & HTML Line Break Alignment**: Ensured editor line breaks are preserved in exported PDF, HTML, and RTF documents by converting soft line breaks to hard breaks and applying `white-space: pre-wrap` CSS formatting.
- **Backup & Sync Settings Pane**: Dedicated `BackupSyncSettingsView` tab in Settings window (`⌘,`) for managing encryption passwords, library backups, and Dropbox sync configurations.

---

### Chinese
### 新增
- **AES-256 全库加密备份与恢复**：支持全量文档库导出为 `.mdwbk` 加密快照，基于 AES-256-GCM 算法与 20,000 次 PBKDF2 哈希派生，主解密密码可保存于 macOS Keychain 钥匙串。
- **Dropbox 端到端加密 (E2EE) 云端同步**：全面支持本地 Dropbox 目录与 Dropbox REST API 令牌双同步模式，同步数据在本地即时加密后再行上传，保障数据绝对私密。
- **中文与 CJK 斜体渲染修复**：针对 macOS 系统中文字体缺乏原生斜体字形的问题，增加了 `.obliqueness: 0.2` 字符倾斜度渲染，完美修复 `*中文斜体*` 显示。
- **Markdown 语法全量对齐**：全面补齐并规范了 `*斜体*`、`_斜体_`、`**加粗**`、`__加粗__`、`***加粗斜体***`、`___加粗斜体___` 等多重 Markdown 强调语法。
- **PDF / HTML 换行精准对齐**：排除了软换行合并掉段落换行的问题，导出的 PDF、HTML 以及 RTF 文档与编辑器看到的换行排版 100% 保持一致。
- **“备份与同步”设置面板**：在设置窗口（`⌘,`）中新增专属设置页，一站式配置数据加解密、全库备份恢复以及 Dropbox 同步模式。

## [3.0.0] - 2026-07-29

### Added
- **Local LLM Engine Integration**: Full support for local OpenAI-compatible AI engines including Ollama, LM Studio, oMLX, llama.cpp, MLX, Jan, and custom endpoints with zero data cloud uploads.
- **AI Chat Panel**: Integrated right sidebar panel (`⇧⌘L`) with instant model switching, note-bound SwiftData message history, and rich Markdown response rendering.
- **Full Tool Calling Suite**: Built-in 18-tool execution engine allowing AI to manipulate active document selections, manage library notes, edit metadata, format Markdown tables/code, and configure MCP servers.
- **Model Context Protocol (MCP)**: Native MCP Host integration powered by `mcp-swift-sdk @ 0.12.1`. Supports stdio servers, visual preset templates (Filesystem, Fetch, Puppeteer, Brave, GitHub), native folder picking, and AI-driven server registration.
- **Multi-Engine Privacy Web Search**: Integrated DuckDuckGo (zero API key), SearXNG (self-hosted), Brave, Tavily, Exa, Google, and Bing web search with collapsible search source cards in chat.
- **Apple Intelligence Division**: Clear functional division reserving Apple Intelligence for lightweight on-device summaries, title generation, auto-tagging, and translation, while offloading complex creative tasks to local LLMs.

---

### Chinese
### 新增
- **本地大模型引擎接入**：全量支持 Ollama、LM Studio、oMLX、llama.cpp、MLX、Jan 及自定义端点等本地大模型引擎，执行本地优先策略，数据绝不上云。
- **AI 对话面板**：新增右侧独立 AI 对话面板（快捷键 `⇧⌘L`），支持实时模型选择、与笔记绑定持久化的 SwiftData 对话历史以及 Markdown 富文本渲染。
- **全量 Tool Calling 工具链**：内置 18 个操控工具，允许大模型直接接管编辑器选区操控、文稿库笔记管理、元数据设置、Markdown 表格与代码块格式化及 MCP 服务管理。
- **Model Context Protocol (MCP) 扩展支持**：基于 `mcp-swift-sdk @ 0.12.1` 实现原生 MCP 宿主，内置零门槛预设库（文件系统、网页抓取、Puppeteer、Brave 搜索、GitHub）、原生文件夹选择器，并支持大模型通过对话直接添加扩展。
- **多引擎隐私网络搜索**：支持 DuckDuckGo（内置免 Key）、SearXNG（自建实例）、Brave、Tavily、Exa、Google、Bing 等 7 大搜索引擎，对话框中提供可折叠搜索来源卡片。
- **Apple Intelligence 分工优化**：明确端侧分工，Apple Intelligence 专注于轻量级摘要、标题生成、标签提取与快速翻译，复杂创作与功能操控交由本地大模型。
