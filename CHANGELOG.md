# CHANGELOG

## [4.0.0] - 2026-10-18

### Added
- **Inline AI Assistant & Visual Diff Review (`⌘K`)**: Seamlessly invoke AI anywhere in the editor with a native floating command bar and selection pill. Supports 8 preset actions (Polish, Shorten, Expand, Fix Grammar, Translate, Professional, Casual, Continue) or custom prompts. Review changes with unified red-green line diffs, word delta counters, one-click accept (`⏎`), reject (`Esc`), retry (`⌘R`), and deduplicated safety snapshots.
- **Local RAG & Paragraph-Level Semantic Search**: Built-in vector embedding engine powered by Apple `NaturalLanguage`. Automatically chunks library notes and caches 640-dim (Chinese) and 512-dim (English) sentence vectors for lightning-fast offline semantic search, hybrid keyword fusion, and autonomous tool calling via `semantic_search_library`.
- **Bidirectional [[WikiLinks]] & Backlinks Panel**: Full Obsidian-style internal linking. Type `[[Note Title]]` to navigate or instantly create new notes. Dedicated Backlinks inspector tab in the right dashboard lists referring documents with contextual excerpts.
- **On-Device Vision OCR**: Offline high-precision text recognition for local images and PDFs using Apple Vision (`VNRecognizeTextRequest`). Includes a new `ocr_image_content` tool expanding the built-in tool suite to 29 tools.
- **Proactive Ghost Text Writing Predictions**: Lightweight inline auto-completion controller. After a 1.2s typing pause, predicts next sentences using local LLMs; press `Tab ⇥` to accept predictions instantly.
- **External Local Folders Mounting**: Mount arbitrary local folders with security-scoped bookmarks. Two-way synchronization between external files and MDWriter with atomic disk write-backs.
- **Menu Bar Quick Entry (`⌥⇧N`)**: Lightweight menu bar popover (`NSStatusItem`) for capturing fleeting thoughts, memos, or markdown notes directly into Inbox with `⌘⏎`.
- **CoreSpotlight System Search & Deep Linking**: Real-time macOS Spotlight indexing for all notes, keywords, and folders. Search globally via Spotlight and jump directly to notes via `mdwriter://note/<id>`.
- **macOS App Intents & Shortcuts Integration**: Native Shortcuts and Siri actions including `CreateNoteIntent`, `SearchNotesIntent`, and `AppendToNoteIntent`.
- **KaTeX Formulas & Mermaid Diagram Rendering**: Native LaTeX math rendering (`$...$` and `$$...$$`) and Mermaid visual diagram generation in previews, PDF exports, and image cards.
- **Multi-Document Combined Book Export**: Merge multiple sheets or entire folders into structured books with auto-generated tables of contents and chapter breaks.
- **Note Pinning, Note Templates & Social Card Export**: Pin critical documents to the top, create notes from customizable templates, and export beautiful social media card images.
- **iCloud (CloudKit) Sync Architecture**: Ready-to-use CloudKit private database synchronization architecture and status diagnostics (defaults to Local-First mode without requiring paid developer credentials).

### Improved & Fixed
- Streaming thinking model support: Smoothly parse and fold `<think>` tags and `reasoning_content` in chat.
- Context mentions: Type `@` in chat to mention specific `@Note`, `@Folder`, or `@Memo`.
- Full Swift 6 strict concurrency compliance and zero-hardcoded bilingual localization.

---

### Chinese
### 新增
- **编辑器内联 AI 与行级 Diff 审阅卡片 (`⌘K`)**：原生毛玻璃悬浮指令栏与选区胶囊工具条，支持 8 项写作预设与自由提问；统一红绿行级 Diff 审阅卡片，支持实时增减字数统计、`Accept (⏎)` 采纳、`Reject (Esc)` 放弃、`Retry (⌘R)` 重试及修改前自动去重快照备份。
- **本地向量语义检索引擎 (Local RAG via Apple `NaturalLanguage`)**：基于 Apple 原生系统句子向量（中文 640 维、英文 512 维），实现本地全库段落级向量切片、增量内存缓存、余弦相似度计算与关键字混合加权重排序（Hybrid Fusion），AI 可自主跨笔记调取全库知识切片。
- **`[[WikiLinks]]` 双向链接与反向链接面板 (Backlinks)**：支持正向链接跳转与未创建笔记一键新建；右侧大纲面板新增专属 Links Tab，全库检索引用当前文档的上下文摘录卡片。
- **本地多模态视觉 (Vision OCR)**：基于 Apple 原生 Vision 框架实现中文/英文毫秒级离线图片/PDF 文本识别与图表结构化转 Markdown，内置 Tool Calling 工具链扩充至 29 个。
- **Ghost Text 实时写作续写建议**：光标停止输入 1.2s 防抖触发，智能结合上下文预测生成 1~2 句续写内容，悬浮胶囊展示，按下 `Tab ⇥` 键瞬间采纳。
- **外部本地文件夹直接挂载 (External Folders)**：原生支持挂载任意本地目录并利用 Security-Scoped Bookmarks 持久化；外部磁盘改动双向同步，应用内编辑原子防抖写回磁盘对应 `.md` 文件。
- **菜单栏全局速记窗口 (Quick Entry ⌥⇧N)**：系统菜单栏常驻笔墨图标，弹出极简毛玻璃浮动卡片，支持 `⌘⏎` 秒速保存至收集箱并自动收起。
- **CoreSpotlight 系统级搜索索引与深度链接**：全自动建立 macOS 系统聚焦（Spotlight）索引，全局搜索笔记标题、正文与标签，点击通过 `mdwriter://` 瞬间唤醒定位打开文档。
- **macOS App Intents 原生快捷指令**：提供新建笔记、搜索笔记、追加文本至笔记等系统 Shortcuts 与 Siri 动作。
- **KaTeX 数学公式与 Mermaid 图表原生渲染**：导出 PDF、长图与 HTML 预览均原生解析渲染 `$...$` 公式与 Mermaid 图表。
- **多文档合订导出 (Book Mode)**：支持按文件夹或手动排序将多篇独立笔记拼接为包含总目录、规范章节标题与分隔线的合订本长文。
- **笔记置顶、笔记模板与社交长图卡片导出**：笔记列表置顶、多场景开箱即用模板，以及一键导出精致社交分享长图卡片。
- **iCloud (CloudKit) 同步架构**：完整实现 CloudKit 云端同步状态机与偏好设置面板（默认保持本地优先 Local-First 安全模式，无需付费开发者证书即可稳定运行）。

### 优化与修复
- 思考模型流式解析：优雅折叠 `<think>` 思考过程与 `reasoning_content`。
- 上下文引用系统：聊天框输入 `@` 瞬间联想并引用 `@Note`、`@Folder` 或 `@Memo`。
- 全量 Swift 6 严格并发检查通过与 100% 界面双语本地化覆盖。

## [3.2.1] - 2026-07-30

### Added
- **Automatic AI Document Context Awareness**: LLMs automatically perceive active document metadata, word statistics, tags, and content according to configurable context levels (Off / Metadata / Full Document), eliminating manual copy-pasting.
- **AI Quick Control Toggles Bar**: Added quick toggle pill buttons directly inside the chat input box for Extended Thinking, Web Search, MCP extensions, and Document Context levels.
- **Customizable System Prompt**: Enhanced default writing assistant prompt with support for user-defined custom system instructions in AI Settings pane.
- **Sidebar Tags Classification & Filtering**: Introduced a dedicated Tags section in the library sidebar, listing all document tags with real-time note counts for instant tag-based filtering.
- **Markdown Emphasis & Export PDF Styling Fix**: Fixed an issue where italic text (*text*) was wrongly tinted with gold/yellow emphasis colors in the editor, and normalized line breaks & CSS rules in exported PDF and HTML documents.

---

### Chinese
### 新增与修复
- **AI 智能文档上下文自动感知**：大模型可根据配置的上下文层级（关闭 / 元数据 / 完整文档）自动感知当前文档标题、标签、字数及文本内容，告别手动复制粘贴与文本拼接。
- **AI 对话控制快捷开关栏**：在对话输入框上方集成一键控制胶囊按钮，可实时开关深度思考 (Thinking)、联网搜索 (Web Search)、MCP 扩展工具以及一键循环切换文档上下文层级。
- **自定义 System Prompt 系统提示词**：升级了内置的 macOS 原生写作助手提示词，并在 AI 设置面板中提供了可自定义的 Prompt 编辑器。
- **侧边栏 Tags 标签分类与自动筛选**：在侧边栏导航中新增 Tags 专属分组，实时汇总呈现全库所有笔记标签及对应的关联文档数量，点击即可瞬间筛选对应标签文档。
- **Markdown 强调样式与 PDF 导出对齐修复**：彻底修正了编辑器中 `*斜体*` 被误染成黄色高亮下划线的问题（使强调样式精准继承正文色彩），并补齐了导出 PDF/HTML 中的段落与换行 CSS 规范。

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
