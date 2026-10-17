//
//  LLMToolDefinitions.swift
//  MDWriter
//

import Foundation

/// JSON Schema definitions for built-in LLM tools.
struct LLMToolDefinitions {
    static var allTools: [OpenAIToolDefinition] {
        return [
            getSelectedTextTool,
            getDocumentContentTool,
            getDocumentOutlineTool,
            replaceSelectionTool,
            searchAndReplaceInDocTool,
            insertAtCursorTool,
            selectRangeTool,
            applyFormattingTool,
            createNoteTool,
            deleteNoteTool,
            renameNoteTool,
            listNotesTool,
            openNoteTool,
            searchNotesTool,
            manageFoldersTool,
            setDocumentTitleTool,
            manageTagsTool,
            manageMemosTool,
            createSnapshotTool,
            diffWithLatestSnapshotTool,
            exportDocumentTool,
            insertTableTool,
            insertCodeBlockTool,
            webSearchTool,
            fetchWebpageMarkdownTool,
            semanticSearchLibraryTool,
            ocrImageContentTool,
            addMCPServerTool,
            listMCPServersTool
        ]
    }

    // MARK: - Editor Tools

    static let getSelectedTextTool = OpenAIToolDefinition(
        name: "get_selected_text",
        description: "Get the text currently selected by the user in the editor.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [:] as [String: Any]
        ])
    )

    static let getDocumentContentTool = OpenAIToolDefinition(
        name: "get_document_content",
        description: "Get the full Markdown content of the current active document.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [:] as [String: Any]
        ])
    )

    static let getDocumentOutlineTool = OpenAIToolDefinition(
        name: "get_document_outline",
        description: "Get the Markdown heading outline (H1-H6) of the active document along with line indices and document statistics.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [:] as [String: Any]
        ])
    )

    static let replaceSelectionTool = OpenAIToolDefinition(
        name: "replace_selection",
        description: "Replace the selected text (or insert at cursor if no selection) with new text. Automatically saves a safety snapshot before modifying.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "text": [
                    "type": "string",
                    "description": "The replacement or inserted text"
                ]
            ],
            "required": ["text"]
        ])
    )

    static let searchAndReplaceInDocTool = OpenAIToolDefinition(
        name: "search_and_replace_in_doc",
        description: "Search and replace text in the current active document using exact matching or regular expressions. Automatically creates a version snapshot before applying replacements.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "search": [
                    "type": "string",
                    "description": "The text or regex pattern to search for"
                ],
                "replace": [
                    "type": "string",
                    "description": "The replacement text"
                ],
                "is_regex": [
                    "type": "boolean",
                    "description": "Whether 'search' is a regular expression (default: false)"
                ]
            ],
            "required": ["search", "replace"]
        ])
    )

    static let insertAtCursorTool = OpenAIToolDefinition(
        name: "insert_at_cursor",
        description: "Insert Markdown or plain text at the current cursor position.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "text": [
                    "type": "string",
                    "description": "The text to insert at the cursor"
                ]
            ],
            "required": ["text"]
        ])
    )

    static let selectRangeTool = OpenAIToolDefinition(
        name: "select_range",
        description: "Select a range of text in the current document by character location and length.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "location": [
                    "type": "integer",
                    "description": "The starting character index"
                ],
                "length": [
                    "type": "integer",
                    "description": "The number of characters to select"
                ]
            ],
            "required": ["location", "length"]
        ])
    )

    static let applyFormattingTool = OpenAIToolDefinition(
        name: "apply_formatting",
        description: "Apply Markdown formatting (bold, italic, inline code, strikethrough, blockquote, or headings) to the current selection or line.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "format": [
                    "type": "string",
                    "enum": ["bold", "italic", "code", "strikethrough", "blockquote", "h1", "h2", "h3"]
                ]
            ],
            "required": ["format"]
        ])
    )

    // MARK: - Note / Library Tools

    static let createNoteTool = OpenAIToolDefinition(
        name: "create_note",
        description: "Create a new note in the library with a specified title and optional initial content, folder, or tags.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "Title of the new note"
                ],
                "content": [
                    "type": "string",
                    "description": "Initial Markdown content of the note"
                ],
                "folder_name": [
                    "type": "string",
                    "description": "Optional target folder name"
                ],
                "tags": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "List of keyword tags for the note"
                ]
            ],
            "required": ["title"]
        ])
    )

    static let deleteNoteTool = OpenAIToolDefinition(
        name: "delete_note",
        description: "Move a note to trash by title.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "Title of the note to delete"
                ]
            ],
            "required": ["title"]
        ])
    )

    static let renameNoteTool = OpenAIToolDefinition(
        name: "rename_note",
        description: "Rename an existing note in the library.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "old_title": [
                    "type": "string",
                    "description": "Current title of the note"
                ],
                "new_title": [
                    "type": "string",
                    "description": "New title for the note"
                ]
            ],
            "required": ["old_title", "new_title"]
        ])
    )

    static let listNotesTool = OpenAIToolDefinition(
        name: "list_notes",
        description: "List notes in the library, optionally filtered by tag, folder, or keyword.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "tag": [
                    "type": "string",
                    "description": "Filter notes by tag"
                ],
                "folder_name": [
                    "type": "string",
                    "description": "Filter notes by folder name"
                ],
                "keyword": [
                    "type": "string",
                    "description": "Filter notes containing keyword in title"
                ]
            ]
        ])
    )

    static let openNoteTool = OpenAIToolDefinition(
        name: "open_note",
        description: "Open a note by title in the main editor.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "Title of the note to open"
                ]
            ],
            "required": ["title"]
        ])
    )

    static let searchNotesTool = OpenAIToolDefinition(
        name: "search_notes",
        description: "Search notes across the library by full-text search query.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Search query text"
                ]
            ],
            "required": ["query"]
        ])
    )

    static let manageFoldersTool = OpenAIToolDefinition(
        name: "manage_folders",
        description: "List all library folders, create a new folder, or move a note into a folder (or back to Inbox).",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "action": [
                    "type": "string",
                    "enum": ["list", "create", "move_note"],
                    "description": "Folder action to perform"
                ],
                "folder_name": [
                    "type": "string",
                    "description": "Target folder name (required for 'create'; pass empty or 'Inbox' in 'move_note' to move to Inbox)"
                ],
                "note_title": [
                    "type": "string",
                    "description": "Title of the note to move (used when action is 'move_note'; defaults to active note if omitted)"
                ]
            ],
            "required": ["action"]
        ])
    )

    // MARK: - Metadata, Memos & Snapshot Tools

    static let setDocumentTitleTool = OpenAIToolDefinition(
        name: "set_document_title",
        description: "Set the title of the current active note.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "The new document title"
                ]
            ],
            "required": ["title"]
        ])
    )

    static let manageTagsTool = OpenAIToolDefinition(
        name: "manage_tags",
        description: "Add or remove keyword tags on the current active note.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "action": [
                    "type": "string",
                    "enum": ["add", "remove"]
                ],
                "tags": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "List of tags to add or remove"
                ]
            ],
            "required": ["action", "tags"]
        ])
    )

    static let manageMemosTool = OpenAIToolDefinition(
        name: "manage_memos",
        description: "List, add, or delete side-panel Memos attached to the current active note.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "action": [
                    "type": "string",
                    "enum": ["list", "add", "delete"],
                    "description": "Memo operation to perform"
                ],
                "content": [
                    "type": "string",
                    "description": "Memo text content (required when action is 'add', or substring match when action is 'delete')"
                ]
            ],
            "required": ["action"]
        ])
    )

    static let createSnapshotTool = OpenAIToolDefinition(
        name: "create_snapshot",
        description: "Save a version snapshot of the current active note so the user can restore it later in Version History.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [:] as [String: Any]
        ])
    )

    // MARK: - Markdown Formatting Tools

    static let insertTableTool = OpenAIToolDefinition(
        name: "insert_table",
        description: "Insert a formatted Markdown table into the editor at cursor position.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "headers": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Column header titles"
                ],
                "rows": [
                    "type": "array",
                    "items": [
                        "type": "array",
                        "items": ["type": "string"]
                    ],
                    "description": "Grid of row cells"
                ]
            ],
            "required": ["headers", "rows"]
        ])
    )

    static let insertCodeBlockTool = OpenAIToolDefinition(
        name: "insert_code_block",
        description: "Insert a fenced Markdown code block into the editor.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "code": [
                    "type": "string",
                    "description": "Code content"
                ],
                "language": [
                    "type": "string",
                    "description": "Programming language name (e.g. swift, python, json)"
                ]
            ],
            "required": ["code"]
        ])
    )

    // MARK: - Search Tool

    static let webSearchTool = OpenAIToolDefinition(
        name: "web_search",
        description: "Search the web for up-to-date information. Only the search query keyword is sent to the search engine.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Search query keywords"
                ]
            ],
            "required": ["query"]
        ])
    )

    static let fetchWebpageMarkdownTool = OpenAIToolDefinition(
        name: "fetch_webpage_markdown",
        description: "Fetch the webpage at a given URL and convert its body into clean Markdown. Useful after web_search to read articles, documentations, or references in detail.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "The HTTP or HTTPS URL to fetch"
                ],
                "max_length": [
                    "type": "integer",
                    "description": "Maximum character length to return (default: 8000)"
                ]
            ],
            "required": ["url"]
        ])
    )

    // MARK: - Export & Snapshot Tools

    static let exportDocumentTool = OpenAIToolDefinition(
        name: "export_document",
        description: "Export the current active document to a specified format and save it locally. Supports PDF, HTML, RTF, Markdown, or Social Card Image (PNG).",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "format": [
                    "type": "string",
                    "enum": ["pdf", "html", "rtf", "markdown", "image"],
                    "description": "Export format: 'pdf', 'html', 'rtf', 'markdown', or 'image' (social card PNG)"
                ],
                "destination_path": [
                    "type": "string",
                    "description": "Optional file path or directory. If omitted, exports to user's Downloads folder with document title."
                ]
            ],
            "required": ["format"]
        ])
    )

    static let diffWithLatestSnapshotTool = OpenAIToolDefinition(
        name: "diff_with_latest_snapshot",
        description: "Compare the current active document with its latest history snapshot to inspect text differences, additions, and deletions.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [:] as [String: Any]
        ])
    )

    // MARK: - MCP Management Tools

    static let addMCPServerTool = OpenAIToolDefinition(
        name: "add_mcp_server",
        description: "Add a new MCP server extension to the configuration and connect it immediately.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "name": [
                    "type": "string",
                    "description": "Identifier name of the MCP server (e.g. Filesystem, Fetch, GitHub, Brave)"
                ],
                "command": [
                    "type": "string",
                    "description": "Executable command (e.g. npx or uvx)"
                ],
                "args": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Arguments list (e.g. ['-y', '@modelcontextprotocol/server-filesystem', '/Users/...'])"
                ],
                "env": [
                    "type": "object",
                    "description": "Optional environment variables key-value dictionary (e.g. {'BRAVE_API_KEY': 'xxxx'})"
                ]
            ],
            "required": ["name", "command"]
        ])
    )

    static let listMCPServersTool = OpenAIToolDefinition(
        name: "list_mcp_servers",
        description: "List currently configured MCP server extensions and their connection status.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [:] as [String: Any]
        ])
    )

    static let semanticSearchLibraryTool = OpenAIToolDefinition(
        name: "semantic_search_library",
        description: "Perform local semantic vector search across all notes in the library to find relevant passages, ideas, or facts by meaning (on-device Apple NaturalLanguage RAG).",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Semantic query or question to search across the library."
                ],
                "limit": [
                    "type": "integer",
                    "description": "Optional maximum number of matching passages to return (default: 5, max: 10)."
                ],
                "min_similarity": [
                    "type": "number",
                    "description": "Optional minimum similarity threshold between 0.0 and 1.0 (default: 0.25)."
                ]
            ],
            "required": ["query"]
        ])
    )

    static let ocrImageContentTool = OpenAIToolDefinition(
        name: "ocr_image_content",
        description: "Extract text from an image or screenshot path using on-device Apple Vision OCR.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "image_path": [
                    "type": "string",
                    "description": "Local filesystem path or file URL to the image."
                ]
            ],
            "required": ["image_path"]
        ])
    )
}
