//
//  ToolExecutor.swift
//  MDWriter
//

import Foundation
import SwiftData
import SwiftUI

/// Executor for built-in MDWriter tools, web search, and MCP server management.
@MainActor
final class ToolExecutor {
    weak var editorController: EditorController?
    var modelContext: ModelContext?
    var currentNote: Note?

    private let webSearchTool = WebSearchTool()

    init(editorController: EditorController? = nil, modelContext: ModelContext? = nil, currentNote: Note? = nil) {
        self.editorController = editorController
        self.modelContext = modelContext
        self.currentNote = currentNote
    }

    /// Executes a tool call by name and JSON arguments string.
    func execute(name: String, argumentsJSON: String) async throws -> String {
        let argsData = argumentsJSON.data(using: .utf8) ?? Data()
        let argsDict = (try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]) ?? [:]

        switch name {
        // MARK: - Editor Tools
        case "get_selected_text":
            let text = editorController?.proxy.getSelectedText() ?? ""
            return text.isEmpty ? "(No text currently selected)" : text

        case "get_document_content":
            if let text = editorController?.fullText, !text.isEmpty {
                return text
            } else if let content = currentNote?.content {
                return content
            }
            return "(Empty document)"

        case "replace_selection":
            guard let text = argsDict["text"] as? String else {
                return "Error: missing 'text' parameter"
            }
            editorController?.proxy.insert(text)
            return "Successfully replaced selected text."

        case "insert_at_cursor":
            guard let text = argsDict["text"] as? String else {
                return "Error: missing 'text' parameter"
            }
            editorController?.proxy.insert(text)
            return "Successfully inserted text at cursor."

        case "select_range":
            guard let loc = argsDict["location"] as? Int, let len = argsDict["length"] as? Int else {
                return "Error: missing 'location' or 'length' parameter"
            }
            editorController?.proxy.setSelectedRange(NSRange(location: loc, length: len))
            return "Selected range (\(loc), \(len))."

        case "apply_formatting":
            guard let fmt = argsDict["format"] as? String else {
                return "Error: missing 'format' parameter"
            }
            switch fmt {
            case "bold": editorController?.toggleBold()
            case "italic": editorController?.toggleItalic()
            case "code": editorController?.toggleInlineCode()
            case "strikethrough": editorController?.toggleStrikethrough()
            case "blockquote": editorController?.applyBlockPrefix("> ")
            case "h1": editorController?.applyBlockPrefix("# ")
            case "h2": editorController?.applyBlockPrefix("## ")
            case "h3": editorController?.applyBlockPrefix("### ")
            default: return "Unknown format type: \(fmt)"
            }
            return "Applied '\(fmt)' formatting."

        // MARK: - Note / Library Tools
        case "create_note":
            guard let title = argsDict["title"] as? String else {
                return "Error: missing 'title' parameter"
            }
            let content = (argsDict["content"] as? String) ?? ""
            let newNote = Note(title: title, content: content)
            if let tags = argsDict["tags"] as? [String] {
                newNote.tags = tags
            }
            modelContext?.insert(newNote)
            try? modelContext?.save()
            return "Successfully created note '\(title)'."

        case "delete_note":
            guard let title = argsDict["title"] as? String else {
                return "Error: missing 'title' parameter"
            }
            let descriptor = FetchDescriptor<Note>()
            let notes = (try? modelContext?.fetch(descriptor)) ?? []
            if let noteToDelete = notes.first(where: { $0.title == title }) {
                noteToDelete.isTrashed = true
                try? modelContext?.save()
                return "Moved note '\(title)' to trash."
            }
            return "Note with title '\(title)' not found."

        case "rename_note":
            guard let oldTitle = argsDict["old_title"] as? String,
                  let newTitle = argsDict["new_title"] as? String else {
                return "Error: missing 'old_title' or 'new_title' parameter"
            }
            let descriptor = FetchDescriptor<Note>()
            let notes = (try? modelContext?.fetch(descriptor)) ?? []
            if let noteToRename = notes.first(where: { $0.title == oldTitle }) {
                noteToRename.title = newTitle
                try? modelContext?.save()
                return "Renamed note from '\(oldTitle)' to '\(newTitle)'."
            }
            return "Note '\(oldTitle)' not found."

        case "list_notes":
            let descriptor = FetchDescriptor<Note>()
            let notes = ((try? modelContext?.fetch(descriptor)) ?? []).filter { !$0.isTrashed }
            let tagFilter = argsDict["tag"] as? String
            let keywordFilter = argsDict["keyword"] as? String

            let filtered = notes.filter { n in
                if let t = tagFilter, !n.tags.contains(t) { return false }
                if let k = keywordFilter, !n.title.localizedCaseInsensitiveContains(k) { return false }
                return true
            }

            let resultList = filtered.map { ["title": $0.title, "tags": $0.tags.joined(separator: ", ")] }
            let jsonData = (try? JSONSerialization.data(withJSONObject: resultList)) ?? Data()
            return String(data: jsonData, encoding: .utf8) ?? "[]"

        case "open_note":
            guard let title = argsDict["title"] as? String else {
                return "Error: missing 'title' parameter"
            }
            NotificationCenter.default.post(name: Notification.Name("OpenNoteByTitle"), object: title)
            return "Opened note '\(title)'."

        case "search_notes":
            guard let query = argsDict["query"] as? String else {
                return "Error: missing 'query' parameter"
            }
            let descriptor = FetchDescriptor<Note>()
            let notes = ((try? modelContext?.fetch(descriptor)) ?? []).filter { !$0.isTrashed }
            let matches = notes.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.content.localizedCaseInsensitiveContains(query)
            }
            let results = matches.prefix(10).map { ["title": $0.title, "snippet": String($0.content.prefix(150))] }
            let jsonData = (try? JSONSerialization.data(withJSONObject: results)) ?? Data()
            return String(data: jsonData, encoding: .utf8) ?? "[]"

        // MARK: - Metadata Tools
        case "set_document_title":
            guard let title = argsDict["title"] as? String else {
                return "Error: missing 'title' parameter"
            }
            if let note = currentNote {
                note.title = title
                try? modelContext?.save()
                return "Updated document title to '\(title)'."
            }
            return "No active document to set title."

        case "manage_tags":
            guard let action = argsDict["action"] as? String,
                  let tags = argsDict["tags"] as? [String],
                  let note = currentNote else {
                return "Error: missing required parameters"
            }
            if action == "add" {
                for t in tags where !note.tags.contains(t) {
                    note.tags.append(t)
                }
            } else if action == "remove" {
                note.tags.removeAll(where: { tags.contains($0) })
            }
            try? modelContext?.save()
            return "Updated tags: \(note.tags.joined(separator: ", "))"

        // MARK: - Markdown Tools
        case "insert_table":
            guard let headers = argsDict["headers"] as? [String],
                  let rows = argsDict["rows"] as? [[String]] else {
                return "Error: missing 'headers' or 'rows' parameter"
            }
            let tableMD = generateMarkdownTable(headers: headers, rows: rows)
            editorController?.proxy.insert(tableMD)
            return "Inserted Markdown table."

        case "insert_code_block":
            guard let code = argsDict["code"] as? String else {
                return "Error: missing 'code' parameter"
            }
            let lang = (argsDict["language"] as? String) ?? ""
            let codeBlockMD = "```\(lang)\n\(code)\n```\n"
            editorController?.proxy.insert(codeBlockMD)
            return "Inserted code block."

        // MARK: - Web Search Tool
        case "web_search":
            guard let query = argsDict["query"] as? String else {
                return "Error: missing 'query' parameter"
            }
            let searchResults = try await webSearchTool.search(query: query)
            let resultData = try JSONEncoder().encode(searchResults)
            return String(data: resultData, encoding: .utf8) ?? "[]"

        // MARK: - MCP Management Tools
        case "add_mcp_server":
            guard let serverName = argsDict["name"] as? String,
                  let command = argsDict["command"] as? String else {
                return "Error: missing 'name' or 'command' parameter"
            }
            let argsList = (argsDict["args"] as? [String]) ?? []
            let envDict = argsDict["env"] as? [String: String]

            var configs = MCPConfigurationManager.shared.loadConfig()
            let newConfig = MCPServerConfig(name: serverName, command: command, args: argsList, env: envDict)
            configs.removeAll(where: { $0.name == serverName })
            configs.append(newConfig)

            do {
                try MCPConfigurationManager.shared.saveConfig(servers: configs)
                Task {
                    await MCPClientManager.shared.reloadAndConnectAll()
                }
                return "Successfully added and connected MCP server extension '\(serverName)'."
            } catch {
                return "Failed to save MCP server extension: \(error.localizedDescription)"
            }

        case "list_mcp_servers":
            let configs = MCPConfigurationManager.shared.loadConfig()
            if configs.isEmpty {
                return "No MCP servers configured."
            }
            var result = "Configured MCP Servers:\n"
            for cfg in configs {
                let status = MCPClientManager.shared.statuses.first(where: { $0.name == cfg.name })
                let isConnected = status?.isConnected == true
                let tools = status?.toolCount ?? 0
                result += "- Name: \(cfg.name) | Connected: \(isConnected) | Tools: \(tools) | Command: \(cfg.command) \((cfg.args ?? []).joined(separator: " "))\n"
            }
            return result.trimmingCharacters(in: .whitespacesAndNewlines)

        default:
            return "Unknown tool: \(name)"
        }
    }

    private func generateMarkdownTable(headers: [String], rows: [[String]]) -> String {
        var sb = "| " + headers.joined(separator: " | ") + " |\n"
        sb += "| " + headers.map { _ in "---" }.joined(separator: " | ") + " |\n"
        for row in rows {
            sb += "| " + row.joined(separator: " | ") + " |\n"
        }
        return sb + "\n"
    }
}
