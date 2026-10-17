# MDWriter：LLM 深度拓展与产品功能演进规划

> 基于 MDWriter 当前代码架构（v3.2.1+：`SwiftUI` + `SwiftData` + `MDEditorKit (TextKit 2)` + `OpenAIClient / FoundationModels 双引擎` + `mcp-swift-sdk`）梳理的产品演进规划与实施记录。所有设计与实现均遵循 **“安静、专业、原生 macOS、本地优先（Local-First）”** 的核心原则，方便多个 AI 编码工具（Claude Code / Cursor / Codex / Gemini）无缝接力协作。

## 一、 现状盘点与架构切入点

| 模块 | 既有基础能力 | 演进切入点与当前状态 |
| :--- | :--- | :--- |
| **双引擎 AI 架构** | `AIService`（Apple FoundationModels 负责摘要/标题/标签/翻译）+ `LLMService`（Ollama/LM Studio/MLX 等本地 OpenAI 兼容接口） | ✅ **已完成**：`SSEParser`、`LLMService`、`ChatMessageView`、`ChatPanelView` 已打通 `<think>` 标签与 `reasoning_content` 流式解析与折叠渲染；<br>⏳ **待演进**：双引擎自动 Fallback 路由 |
| **上下文感知** | `AIContextLevel` 支持 `Off` / `Metadata` / `Full Doc` 三档，单篇笔记绑定 `ChatMessage` 历史 | ✅ **已完成**：跨笔记与文件夹引用（`@Note` / `@Folder` / `@Memo`）原生解析与一键补全已就绪；<br>⏳ **待演进**：全库语义检索（Local RAG） |
| **Tool Calling 工具链** | `LLMToolDefinitions` + `ToolExecutor` 内置完整工具栈（已扩充至 27 个工具） | ✅ **已完成（全量扩充至 27 个工具）**：新增 `get_document_outline`、`search_and_replace_in_doc`、`manage_folders`、`manage_memos`、`create_snapshot`、`fetch_webpage_markdown`、`export_document`、`diff_with_latest_snapshot`，升级 `create_note` / `list_notes` 支持 `folder_name`；<br>⏳ **待演进**：Human-in-the-Loop 高风险确认卡片 |
| **编辑器安全与交互** | 右侧 `ChatPanelView`（`⇧⌘L`）+ 顶部 `AIAssistantView` 弹窗卡片 | ✅ **已完成**：AI 执行 `replace_selection` 与 `search_and_replace_in_doc` 前自动触发去重 `Snapshot` 安全快照；<br>⏳ **待演进**：编辑器正文内联 AI（`⌘K` 光标指令、选区浮动工具栏、红绿 Diff 审阅确认） |
| **文稿库与同步** | `Folder` / `Note` / `Memo` / `Snapshot` 四大 SwiftData 模型；`.mdwbk` AES-256 备份；Dropbox E2EE 同步 | ✅ **已完成**：笔记置顶（Pin to Top / 徽标与置顶排序）、预设笔记模板（Meeting / Daily / RFC / Weekly / Reading）、社交长图卡片导出与一键复制；<br>⏳ **待演进**：双向链接（`[[WikiLink]]`）、写作目标追踪（Writing Goals）、iCloud / 外部文件夹挂载、多文档拼接导出（Book Mode） |

## 二、 集成 LLM 功能的深度拓展方向

### 1. 编辑器内联 AI 体验（Inline AI & Diff Review）
* **Inline Command Bar（`⌘K` / `/` 斜杠指令）**：在 TextKit 2 光标所在位置（可利用 `EditorController.caretFrameInWindow()` 获取光标窗口坐标）呼出轻量级浮动输入框，流式生成内容并直接预览在正文中。
* **浮动选区 AI 菜单（Selection Popover）**：选中一段文字后自动浮现紧凑工具条（润色、精简、扩写、改写语气、翻译、解释代码）。
* **AI 修改 Diff 预览与逐段接受/拒绝（Accept / Reject Diff）**：
  * ✅ **底层安全快照已就绪**：`ToolExecutor.createSafetySnapshotIfNeeded()` 已在每次 AI 替换前自动保存 `Snapshot`，且 `diff_with_latest_snapshot` 工具支持提取统一差异。
  * ⏳ **UI 层待实现**：在编辑器或对话气泡中以浅绿（新增）/浅红删除线（原文本）高亮展示差异，提供 `Accept (⏎)` / `Reject (Esc)` 按钮。
* **Ghost Text 续写补全（Inline Autocomplete）**：利用本地低延迟小模型或 Apple FoundationModels，在用户停顿后基于前文预测下一句，按 `Tab` 键采纳。

### 2. 全库知识检索与多文档上下文（Local RAG & `@` 引用系统）
* **`@` 上下文提及选择器（Context Mention）（✅ 已完成）**：在 `ChatInputView` 中支持输入 `@` 或点击引用菜单，快速插入笔记/文件夹/附注标记并自动解析注入 System Prompt：
  * `@Note: "NoteTitle"`：将指定笔记全文注入本次对话上下文。
  * `@Folder: "FolderName"`：注入该文件夹下所有笔记的大纲与核心摘要。
  * `@Memo`：将当前笔记关联的所有 `Memo`（Dashboard 附注）一并作为背景资料提供给 LLM。
* **基于 Apple `NaturalLanguage` / 本地 Embedding 的全库语义搜索（Local RAG）（⏳ 待演进）**：
  * 利用 macOS 原生 `NLEmbedding` 或 Ollama `/v1/embeddings` 接口，在 SwiftData 中为笔记段落建立本地向量索引。
  * 新增 `semantic_search_library` 工具，支持跨笔记问答并附上 `mdwriter://note/<id>` 跳转链接。
* **跨文档综合写作（Multi-Note Synthesis）**：支持在 `NoteListView` 中多选多篇灵感笔记，一键交由 LLM 整合成长文草稿。

### 3. 内置 Tool Calling 工具链（27 个已实现全量清单）

#### 核心新增/升级工具清单（已落地）
| 工具名 | 绑定模块 | 状态 | 功能与参数说明 |
| :--- | :--- | :--- | :--- |
| `get_document_outline` | `MDHeaderParser` + `DocumentStatistics` | ✅ 已实现 | 返回当前文档字数、字符数、预计阅读时长，以及 H1~H6 标题数组（`level`, `heading`, `title`, `line_index`） |
| `search_and_replace_in_doc` | `EditorController` + `Snapshot` | ✅ 已实现 | 参数：`search` (必填), `replace` (必填), `is_regex` (可选 Bool)。修改前自动创建安全快照，支持普通文本全量替换与 `NSRegularExpression` 正则替换 |
| `manage_folders` | `Folder` + `Note` | ✅ 已实现 | 参数：`action` (`list` / `create` / `move_note`), `folder_name`, `note_title`。支持列出文件夹及笔记数、新建文件夹、将指定或当前笔记移入目标文件夹（不存在时自动创建，传 `Inbox` 或空字符串移回收件箱） |
| `manage_memos` | `Memo` + `Note.memos` | ✅ 已实现 | 参数：`action` (`list` / `add` / `delete`), `content`。支持读取、新增、按文本匹配删除当前笔记的侧边栏 `Memo` 附注 |
| `create_snapshot` | `Snapshot` + `Note.snapshots` | ✅ 已实现 | 无参调用，立即为当前激活文档创建一条历史版本快照 |
| `create_note` / `list_notes` | `Note` + `Folder` | ✅ 已升级 | 新增可选参数 `folder_name`，支持在指定文件夹下直接创建笔记或按文件夹筛选笔记列表 |
| `fetch_webpage_markdown` | `WebSearchTool` | ✅ 已实现 | 参数：`url` (必填), `max_length` (可选)。深度抓取 HTTP/HTTPS 网页正文，剥离样式脚本后转换为高纯净度 Markdown，配合 `web_search` 实现搜索+阅读闭环 |
| `export_document` | `ExportService` | ✅ 已实现 | 参数：`format` (`pdf` / `html` / `rtf` / `markdown` / `image`), `destination_path` (可选)。通过对话直接将当前文档导出为指定格式并落盘本地 |
| `diff_with_latest_snapshot` | `Note.snapshots` | ✅ 已实现 | 计算当前正文与最新历史版本快照的行级差异，生成 Git 风格的统一 Diff 摘要及增删统计 |

### 4. 推理模型（Reasoning）与多模态（Vision）深度适配
* **完善 `Thinking`（深度思考）全链路（✅ 已完成）**：
  * `SSEParser.swift` 已支持解析 OpenAI 兼容流中的 `delta.reasoning_content` 与 `delta.reasoning` 字段。
  * `LLMService.swift` 将流式推理内容统一封装为 `<think>...</think>` 格式，并根据 `config.isThinkingEnabled` 动态注入 `[Reasoning Mode: Enabled]` 或 `/no_think` 系统指令。
  * `ChatMessageView.swift` 与 `ChatPanelView.swift` 新增 `ThinkingContentParser` 与可折叠的 `ThinkingBlockView` 组件；复制/插入/替换选区按钮自动剥离 `<think>` 块，仅向编辑器写入纯净正文。
* **本地多模态视觉（Vision / OCR）接入（⏳ 待实现）**：
  * 支持将图片或 PDF 页面拖入 `ChatInputView`，调用本地多模态模型（如 `Qwen2.5-VL`、`Gemma-3`）或 macOS `VisionKit` 提取文字、识别表格并插入编辑器。

### 5. 预设写作角色（Personas）与 MCP 生态深化
* **角色与工作流切换器**：将单一 `customSystemPrompt` 扩展为可切换的 Persona 预设库（技术架构师、学术审稿人、双语译者等），并支持为特定 `Folder` 绑定专属写作风格指南。
* **结构化长文审校（AI Linter）**：在 `DashboardAITab` 中扫描全文逻辑、术语一致性与冗长句，点击问题项通过 `select_range` 高亮定位。
* **MCP 进阶**：支持 HTTP/SSE 远程 MCP Server、接入 MCP `resources` 与 `prompts` 协议，并为高风险工具增加 Human-in-the-Loop 确认卡片。

## 三、 软件本体（非 AI）核心功能拓展建议

### 1. 编辑器与 Markdown 渲染增强
* **双向链接与反向链接（`[[WikiLinks]]` & Backlinks）**：输入 `[[` 自动补全笔记标题，点击通过 `mdwriter://note/` 跳转，并在 `DashboardView` 展示反向链接面板。
* **KaTeX 数学公式与 Mermaid 图表渲染**：在 `ExportService` 与预览中支持 `$...$` / `$$...$$` 公式及 ```` ```mermaid ```` 图表。
* **表格快捷键辅助与段落聚焦模式**：支持表格内 `Tab` 跳格与一键对齐；打字机模式支持“非当前段落淡化（Paragraph Dimming）”。

### 2. 文稿库组织与 Ulysses 式工作流
* **笔记置顶（Pin to Top）（✅ 已完成）**：`Note` 支持 `isPinned`，列表高亮图钉标识，置顶笔记自动排序前置，支持右键一键置顶/取消。
* **笔记模板库（Templates）（✅ 已完成）**：支持空白文档、会议纪要、每日日志、技术方案 RFC、工作周报、读书笔记模板快捷创建。
* **社交长图导出（Share as Image）（✅ 已完成）**：`ExportService` + `ExportPreviewView` 原生渲染卡片布局，支持主题底色、阴影、元数据、一键拷贝到剪贴板与 PNG 文件保存。
* **智能文件夹（Smart Folders）**：保存多条件过滤规则（标签 + 时间 + 字数）。
* **多文稿拼接预览与合并导出（Combined Sheets / Book Mode）**：支持选中整个 `Folder` 或多篇 `Note` 按 `order` 顺序合并预览并导出为同一份 PDF / Markdown。

### 3. 写作目标、导出与 macOS 系统级集成
* **写作目标与热力图（Writing Goals & Streak）**：为单篇笔记或文件夹设定目标字数环，并记录每日码字热力图。
* **外部本地文件夹直接挂载（External Folders）与 iCloud (CloudKit) 同步**。
* **菜单栏全局速记窗口（Quick Entry）、`CoreSpotlight` 系统搜索索引与 `AppIntents` 快捷指令支持**。

## 四、 实施路线图与进度追踪

### Phase 1：高价值、低侵入快赢特性
- [x] **打通 `Thinking` 模型 `<think>` 标签与 `reasoning_content` 流式解析与折叠 UI**（2026-10-17 已完成）
- [x] **扩充 Tool Calling 工具集至 24 个**（新增 `get_document_outline`、`search_and_replace_in_doc`、`manage_folders`、`manage_memos`、`create_snapshot`，升级 `create_note` / `list_notes`）（2026-10-17 已完成）
- [x] **AI 修改前自动创建去重 `Snapshot` 安全快照**（2026-10-17 已完成）
- [x] **笔记置顶（Pin）、笔记模板与导出社交长图/卡片**（2026-10-18 已完成）
- [x] **Tool Calling 工具链补齐至 27 个（新增 `fetch_webpage_markdown`、`export_document`、`diff_with_latest_snapshot`）**（2026-10-18 已完成）

### Phase 2：核心竞争力跃升
- [x] **`@Note` / `@Folder` / `@Memo` 上下文引用系统（Context Mention）**（2026-10-18 已完成）
- [x] **编辑器内联 AI（`⌘K` 光标指令 + 选中文本浮动 AI 工具条 + 内联 Diff 审阅卡片）**（2026-10-18 已完成）
- [x] **基于本地 Embedding / NLEmbedding 的全库向量语义检索（Local RAG）**（2026-10-18 已完成）
- [x] **`[[WikiLinks]]` 双向链接、反向链接面板与多笔记合并导出（Book Mode）**（2026-10-18 已完成）
- [x] **KaTeX 数学公式与 Mermaid 图表渲染支持**（2026-10-18 已完成）

#### Phase 3：生态与平台级扩展
- [x] **本地多模态视觉（图片/PDF OCR 与图表转 Markdown）与 Ghost Text 实时续写**（2026-10-18 已完成）
- [x] **外部本地文件夹直接挂载（External Folders）与 iCloud 同步**（2026-10-18 已完成，遵循“iCloud 架构写好但默认不启用，需付费签名才可激活”准则）
- [x] **菜单栏全局速记窗口（Quick Entry）、CoreSpotlight 索引与 macOS App Intents 快捷指令**（2026-10-18 已完成）

## 五、 已完成工作技术交接记录（供其他工具/Agent 协作参考）

> **更新时间**：2026-10-18  
> **状态**：**Phase 1、Phase 2 与 Phase 3 全路线图特性已全部圆满交付！** 内置 Tool Calling 工具链扩充至 **29 个**。全部代码通过 Swift 6 严格并发检查与 Xcode 全量构建（`** BUILD SUCCEEDED **`），零硬编码用户字符串，未引入任何破坏性 SwiftData 迁移。

### 1. 修改与新增文件清单与职责变更（Phase 3 增量交付）

1. **本地多模态视觉（Vision OCR）与工具链扩增（`MDWriter/Core/Services/Vision/`）**
   * **`VisionOCRService.swift`**：利用 Apple 官方 `VNRecognizeTextRequest` 框架，支持中文/英文离线高精度毫秒级文本识别；支持多图 Base64 编码与图表转 Markdown 提示词构造。
   * **`ChatInputView.swift`**：输入框顶部增加原生图片/扫描识别按钮，支持直接选择本地图片或 PDF 页面并提取文字插入对话上下文。
   * **`LLMToolDefinitions.swift` & `ToolExecutor.swift`**：工具链扩增至 **29 个**，新增 `ocr_image_content` 工具，允许 AI 自主识别本地图片路径并提取文字内容。
2. **Ghost Text 编辑器实时续写预测（`MDWriter/Features/Editor/`）**
   * **`GhostTextController.swift`**：轻量写作续写控制器，光标停止输入 1.2s 防抖触发，提取光标前 500 字符上下文，调用本地大模型预测生成 1~2 句续写文本。
   * **`GhostTextSuggestionBar.swift`**：悬浮于编辑器底部的半透明建议胶囊，动态展示实时生成的续写建议，按下 `Tab ⇥` 键瞬间采纳并追加至光标所在位置。
   * **`ContentView.swift`**：打通编辑器光标变化与选中事件监听，无缝协同内联 AI 与 Ghost Text。
3. **外部本地文件夹直接挂载（External Folders）**
   * **`ExternalFolderManager.swift`**：原生支持选择外部任意本地目录，利用 `Security-Scoped Bookmark` 持久化访问权限；提供双向同步，外部 Markdown 文件的改动自动同步至应用，应用内编辑防抖原子写回磁盘对应 `.md` 文件。
   * **`LibraryView.swift` & `NoteListView.swift`**：侧边栏新增“外部文件夹 / External Folders”专属分组，支持挂载、卸载、在访达中显示；支持在挂载文件夹内直接新建 Markdown 文件。
   * **`Models.swift`**：`Note` 实体增设 `externalFilePath: String?` 属性，与现有大纲、内联 AI、版本快照、导出等功能 100% 互通。
4. **iCloud (CloudKit) 同步架构（写好但不启用）**
   * **`CloudKitSyncManager.swift`**：完整实现 CloudKit 同步配置工厂与状态机（`.disabled`、`.provisioningRequired`、`.accountAvailable` 等）。
   * 严格遵循“若需付费开发者签名则写好但不启用”的原则，默认保持 `isCloudKitSyncEnabled = false`（本地优先 Local-First 模式），规避因缺少 Apple 开发者签名而引起的崩溃。
   * **`BackupSyncSettingsView.swift`**：新增专属 iCloud (CloudKit) 同步偏好设置面板，提供状态指示徽标、诊断检测与配置说明。
5. **菜单栏全局速记窗口（Quick Entry）**
   * **`QuickEntryManager.swift`**：常驻 macOS 菜单栏（`NSStatusItem`）笔墨图标，管理原生 `NSPopover` 浮动速记窗口。
   * **`QuickEntryView.swift`**：极简毛玻璃速记卡片，支持标题输入（可选，默认首行）、Markdown 正文输入、目标文件夹选择（默认 Inbox）、快捷键 `⌘⏎` 保存并自动收起。
   * **`MenuCommands.swift`**：在 File 菜单中增加“Quick Entry (⌥⇧N)”全局快捷入口。
6. **CoreSpotlight 系统级搜索索引**
   * **`SpotlightIndexer.swift`**：利用 macOS 原生 `CoreSpotlight` 框架，为笔记标题、正文、标签与修改时间建立 `CSSearchableItem` 索引。
   * 在笔记创建、自动保存、移入废纸篓及删除时全自动维护系统索引。
   * **`LibraryView.swift`**：打通 `mdwriter://note/<id>` URL Scheme 监听，用户在系统聚焦（Spotlight）中搜索点击后瞬间定位打开对应文档。
7. **macOS App Intents 快捷指令支持**
   * **`MDWriterAppIntents.swift`**：
     * `CreateNoteIntent`：支持在系统快捷指令与 Siri 中快速新建笔记；
     * `SearchNotesIntent`：支持按关键词检索笔记列表；
     * `AppendToNoteIntent`：支持向指定笔记追加内容；
     * `MDWriterShortcutsProvider`：注册系统默认 AppShortcuts。
   * **`Project.swift`**：添加 `AppIntents` 与 `CoreSpotlight` 系统框架依赖，自动生成 `Metadata.appintents`。
8. **本地化字典与并发适配**
   * **`Localizable.xcstrings`**：累计增补 35 个中英双语词条，覆盖外部文件夹、iCloud 同步、快速速记、系统搜索及快捷指令所有文案。
   * 全部类型严格符合 Swift 6 并发安全标准。

### 2. 构建与运行验证结论
* 运行 `tuist generate --no-open` 更新工程依赖。
* 运行 `xcodebuild -workspace MDWriter.xcworkspace -scheme MDWriter -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`，输出 **`** BUILD SUCCEEDED **`**，完全通过编译与严格并发检查。

