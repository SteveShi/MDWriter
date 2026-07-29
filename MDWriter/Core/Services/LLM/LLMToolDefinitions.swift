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
            replaceSelectionTool,
            insertAtCursorTool,
            selectRangeTool,
            applyFormattingTool,
            createNoteTool,
            deleteNoteTool,
            renameNoteTool,
            listNotesTool,
            openNoteTool,
            searchNotesTool,
            setDocumentTitleTool,
            manageTagsTool,
            insertTableTool,
            insertCodeBlockTool,
            webSearchTool,
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

    static let replaceSelectionTool = OpenAIToolDefinition(
        name: "replace_selection",
        description: "Replace the selected text (or insert at cursor if no selection) with new text.",
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
        description: "Create a new note in the library with a specified title and optional initial content or tags.",
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
        description: "Move a note to trash or permanently delete it by title or ID.",
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
        description: "List notes in the library, optionally filtered by tag or keyword.",
        parameters: AnyCodable([
            "type": "object",
            "properties": [
                "tag": [
                    "type": "string",
                    "description": "Filter notes by tag"
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

    // MARK: - Metadata Tools

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
}
