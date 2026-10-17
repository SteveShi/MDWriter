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

        case "get_document_outline":
            let content = (editorController?.fullText.isEmpty == false ? editorController?.fullText : currentNote?.content) ?? ""
            if content.isEmpty {
                return "(Empty document)"
            }
            let headers = MDHeaderParser.parseHeaders(from: content)
            let stats = DocumentStatistics.calculate(from: content)
            let outlineItems: [[String: Any]] = headers.map {
                [
                    "level": $0.level,
                    "heading": String(repeating: "#", count: $0.level) + " " + $0.title,
                    "title": $0.title,
                    "line_index": $0.lineIndex
                ]
            }
            let payload: [String: Any] = [
                "characters": stats.characters,
                "words": stats.words,
                "estimated_reading_minutes": stats.readingTime,
                "headings": outlineItems
            ]
            let jsonData = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
            return String(data: jsonData, encoding: .utf8) ?? "{}"

        case "replace_selection":
            guard let text = argsDict["text"] as? String else {
                return "Error: missing 'text' parameter"
            }
            createSafetySnapshotIfNeeded()
            editorController?.proxy.insert(text)
            return "Saved safety snapshot and replaced selected text."

        case "search_and_replace_in_doc":
            guard let search = argsDict["search"] as? String, !search.isEmpty,
                  let replace = argsDict["replace"] as? String else {
                return "Error: missing 'search' or 'replace' parameter"
            }
            let isRegex = (argsDict["is_regex"] as? Bool) ?? false
            let currentText = (editorController?.fullText.isEmpty == false ? editorController?.fullText : currentNote?.content) ?? ""
            guard !currentText.isEmpty else {
                return "Document is empty."
            }

            createSafetySnapshotIfNeeded()

            if isRegex {
                do {
                    let regex = try NSRegularExpression(pattern: search, options: [])
                    let range = NSRange(currentText.startIndex..<currentText.endIndex, in: currentText)
                    let matches = regex.numberOfMatches(in: currentText, options: [], range: range)
                    guard matches > 0 else {
                        return "No regex matches found for '\(search)'."
                    }
                    let updated = regex.stringByReplacingMatches(in: currentText, options: [], range: range, withTemplate: replace)
                    applyFullDocumentUpdate(updated)
                    return "Saved safety snapshot and replaced \(matches) regex match(es) for '\(search)'."
                } catch {
                    return "Invalid regular expression '\(search)': \(error.localizedDescription)"
                }
            } else {
                guard currentText.contains(search) else {
                    return "No exact matches found for '\(search)'."
                }
                let occurrences = max(0, currentText.components(separatedBy: search).count - 1)
                if let controller = editorController {
                    controller.proxy.replaceAll(search: search, with: replace)
                    currentNote?.modifiedAt = Date()
                    try? modelContext?.save()
                } else {
                    let updated = currentText.replacingOccurrences(of: search, with: replace)
                    applyFullDocumentUpdate(updated)
                }
                return "Saved safety snapshot and replaced \(occurrences) occurrence(s) of '\(search)'."
            }

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
            var targetFolder: Folder? = nil
            if let folderName = argsDict["folder_name"] as? String, !folderName.isEmpty {
                let folderDesc = FetchDescriptor<Folder>()
                let folders = (try? modelContext?.fetch(folderDesc)) ?? []
                targetFolder = folders.first(where: { $0.name.localizedCaseInsensitiveCompare(folderName) == .orderedSame })
            }
            let newNote = Note(title: title, content: content, folder: targetFolder)
            if let tags = argsDict["tags"] as? [String] {
                newNote.tags = tags
            }
            modelContext?.insert(newNote)
            try? modelContext?.save()
            if let fName = targetFolder?.name {
                return "Successfully created note '\(title)' in folder '\(fName)'."
            }
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
            let folderFilter = argsDict["folder_name"] as? String
            let keywordFilter = argsDict["keyword"] as? String

            let filtered = notes.filter { n in
                if let t = tagFilter, !n.tags.contains(t) { return false }
                if let f = folderFilter, !f.isEmpty {
                    let noteFolder = n.folder?.name ?? "Inbox"
                    if noteFolder.localizedCaseInsensitiveCompare(f) != .orderedSame { return false }
                }
                if let k = keywordFilter, !n.title.localizedCaseInsensitiveContains(k) { return false }
                return true
            }

            let resultList = filtered.map {
                [
                    "title": $0.title,
                    "folder": $0.folder?.name ?? "Inbox",
                    "tags": $0.tags.joined(separator: ", ")
                ]
            }
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

        case "semantic_search_library":
            guard let query = argsDict["query"] as? String else {
                return "Error: missing 'query' parameter"
            }
            let limit = (argsDict["limit"] as? Int) ?? 5
            let minSim = (argsDict["min_similarity"] as? Double) ?? 0.25

            let descriptor = FetchDescriptor<Note>()
            let allNotes = ((try? modelContext?.fetch(descriptor)) ?? []).filter { !$0.isTrashed }
            let results = SemanticSearchService.shared.search(
                query: query,
                notes: allNotes,
                limit: max(1, min(limit, 10)),
                minSimilarity: minSim
            )

            if results.isEmpty {
                return "No semantically matching notes found for '\(query)'."
            }

            var output = "### Semantic Search Results for \"\(query)\":\n\n"
            for (idx, r) in results.enumerated() {
                let scorePercent = Int(r.similarity * 100)
                let folderInfo = r.folderName != nil ? " [Folder: \(r.folderName!)]" : ""
                output += "\(idx + 1). **\(r.noteTitle)**\(folderInfo) — Match: \(scorePercent)%\n"
                output += "   > \(r.snippet.replacingOccurrences(of: "\n", with: "\n   > "))\n\n"
            }
            return output

        case "ocr_image_content":
            guard let imagePath = argsDict["image_path"] as? String else {
                return "Error: missing 'image_path' parameter"
            }
            let url = imagePath.hasPrefix("file://") ? (URL(string: imagePath) ?? URL(fileURLWithPath: imagePath)) : URL(fileURLWithPath: imagePath)
            do {
                let result = try await VisionOCRService.shared.recognizeText(fromFileURL: url)
                if result.recognizedText.isEmpty {
                    return "No readable text detected in image '\(imagePath)'."
                }
                return """
                ### OCR Recognition Result:
                Lines detected: \(result.lineCount), Confidence: \(Int(result.confidence * 100))%

                \(result.recognizedText)
                """
            } catch {
                return "OCR Error for '\(imagePath)': \(error.localizedDescription)"
            }

        case "manage_folders":
            guard let action = argsDict["action"] as? String else {
                return "Error: missing 'action' parameter"
            }
            let folderDesc = FetchDescriptor<Folder>()
            let folders = (try? modelContext?.fetch(folderDesc)) ?? []

            switch action {
            case "list":
                let list: [[String: Any]] = folders.map { f in
                    [
                        "name": f.name,
                        "note_count": f.notes.filter { !$0.isTrashed }.count
                    ]
                }
                let jsonData = (try? JSONSerialization.data(withJSONObject: list)) ?? Data()
                return String(data: jsonData, encoding: .utf8) ?? "[]"

            case "create":
                guard let folderName = argsDict["folder_name"] as? String,
                      !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return "Error: missing 'folder_name' parameter"
                }
                if folders.contains(where: { $0.name.localizedCaseInsensitiveCompare(folderName) == .orderedSame }) {
                    return "Folder '\(folderName)' already exists."
                }
                let newFolder = Folder(name: folderName)
                modelContext?.insert(newFolder)
                try? modelContext?.save()
                return "Created folder '\(folderName)'."

            case "move_note":
                let noteTitle = argsDict["note_title"] as? String
                let targetNote: Note?
                if let title = noteTitle, !title.isEmpty {
                    let noteDesc = FetchDescriptor<Note>()
                    let allNotes = (try? modelContext?.fetch(noteDesc)) ?? []
                    targetNote = allNotes.first(where: { $0.title == title && !$0.isTrashed })
                } else {
                    targetNote = currentNote
                }
                guard let note = targetNote else {
                    return "Target note not found."
                }
                let folderName = (argsDict["folder_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if folderName.isEmpty || folderName.localizedCaseInsensitiveCompare("Inbox") == .orderedSame {
                    note.folder = nil
                    try? modelContext?.save()
                    return "Moved note '\(note.title)' to Inbox."
                }
                if let existingFolder = folders.first(where: { $0.name.localizedCaseInsensitiveCompare(folderName) == .orderedSame }) {
                    note.folder = existingFolder
                    try? modelContext?.save()
                    return "Moved note '\(note.title)' to folder '\(existingFolder.name)'."
                } else {
                    let createdFolder = Folder(name: folderName)
                    modelContext?.insert(createdFolder)
                    note.folder = createdFolder
                    try? modelContext?.save()
                    return "Created folder '\(folderName)' and moved note '\(note.title)' into it."
                }

            default:
                return "Unknown folder action: \(action)"
            }

        // MARK: - Metadata, Memos & Snapshot Tools
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

        case "manage_memos":
            guard let action = argsDict["action"] as? String,
                  let note = currentNote else {
                return "Error: missing 'action' parameter or no active note"
            }
            switch action {
            case "list":
                let memos = note.memos.sorted(by: { $0.createdAt < $1.createdAt })
                let items = memos.enumerated().map { idx, m in
                    ["index": idx + 1, "content": m.content]
                }
                let jsonData = (try? JSONSerialization.data(withJSONObject: items)) ?? Data()
                return String(data: jsonData, encoding: .utf8) ?? "[]"

            case "add":
                guard let content = argsDict["content"] as? String,
                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return "Error: missing 'content' parameter for adding memo"
                }
                let memo = Memo(content: content, note: note)
                modelContext?.insert(memo)
                note.memos.append(memo)
                try? modelContext?.save()
                return "Added memo to note '\(note.title)'."

            case "delete":
                guard let matchText = argsDict["content"] as? String, !matchText.isEmpty else {
                    return "Error: missing 'content' substring to match memo for deletion"
                }
                if let targetMemo = note.memos.first(where: { $0.content.localizedCaseInsensitiveContains(matchText) }) {
                    note.memos.removeAll(where: { $0 == targetMemo })
                    modelContext?.delete(targetMemo)
                    try? modelContext?.save()
                    return "Deleted matching memo from note '\(note.title)'."
                }
                return "No memo matching '\(matchText)' found on current note."

            default:
                return "Unknown memo action: \(action)"
            }

        case "create_snapshot":
            guard let note = currentNote else {
                return "No active note to snapshot."
            }
            let content = (editorController?.fullText.isEmpty == false ? editorController?.fullText : note.content) ?? note.content
            let snapshot = Snapshot(content: content, note: note)
            modelContext?.insert(snapshot)
            note.snapshots.append(snapshot)
            try? modelContext?.save()
            return "Created version snapshot for '\(note.title)' (\(content.count) chars)."

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

        // MARK: - Web Search & Fetch Tools
        case "web_search":
            guard let query = argsDict["query"] as? String else {
                return "Error: missing 'query' parameter"
            }
            let searchResults = try await webSearchTool.search(query: query)
            let resultData = try JSONEncoder().encode(searchResults)
            return String(data: resultData, encoding: .utf8) ?? "[]"

        case "fetch_webpage_markdown":
            guard let urlString = argsDict["url"] as? String else {
                return "Error: missing 'url' parameter"
            }
            let maxLength = (argsDict["max_length"] as? Int) ?? 8000
            return try await webSearchTool.fetchWebpageMarkdown(urlString: urlString, maxLength: maxLength)

        // MARK: - Export & Snapshot Tools
        case "export_document":
            guard let format = argsDict["format"] as? String else {
                return "Error: missing 'format' parameter"
            }
            let destPath = argsDict["destination_path"] as? String
            let docText = (editorController?.fullText.isEmpty == false ? editorController?.fullText : currentNote?.content) ?? ""
            let docTitle = currentNote?.title ?? "Document"
            return try await ExportService.shared.exportDocument(
                text: docText,
                title: docTitle,
                formatString: format,
                destinationPath: destPath
            )

        case "diff_with_latest_snapshot":
            let currentText = (editorController?.fullText.isEmpty == false ? editorController?.fullText : currentNote?.content) ?? ""
            guard let latestSnapshot = currentNote?.snapshots.sorted(by: { $0.createdAt > $1.createdAt }).first else {
                return "No history snapshot found for note '\(currentNote?.title ?? "Untitled")'."
            }
            let snapshotText = latestSnapshot.content
            if snapshotText == currentText {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                return "Current document is identical to the latest snapshot (recorded at \(formatter.string(from: latestSnapshot.createdAt))). No changes detected."
            }

            return computeUnifiedDiff(
                oldText: snapshotText,
                newText: currentText,
                snapshotDate: latestSnapshot.createdAt
            )

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

    // MARK: - Private Helpers

    /// Automatically saves a version snapshot of the current note before destructive AI edits,
    /// avoiding duplicate snapshots if the latest snapshot already has identical content.
    private func createSafetySnapshotIfNeeded() {
        guard let note = currentNote else { return }
        let currentContent = (editorController?.fullText.isEmpty == false ? editorController?.fullText : note.content) ?? note.content
        guard !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if let latest = note.snapshots.sorted(by: { $0.createdAt > $1.createdAt }).first,
           latest.content == currentContent {
            return
        }

        let snapshot = Snapshot(content: currentContent, note: note)
        modelContext?.insert(snapshot)
        note.snapshots.append(snapshot)
        try? modelContext?.save()
    }

    /// Replaces the entire active document text in both the editor and SwiftData Note model.
    private func applyFullDocumentUpdate(_ updatedText: String) {
        if let controller = editorController {
            controller.selectAll()
            controller.insert(updatedText)
        }
        if let note = currentNote {
            note.content = updatedText
            note.modifiedAt = Date()
            try? modelContext?.save()
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

    private func computeUnifiedDiff(oldText: String, newText: String, snapshotDate: Date) -> String {
        let oldLines = oldText.components(separatedBy: "\n")
        let newLines = newText.components(separatedBy: "\n")
        let diff = newLines.difference(from: oldLines)

        var insertedCount = 0
        var removedCount = 0
        for change in diff {
            switch change {
            case .insert: insertedCount += 1
            case .remove: removedCount += 1
            }
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let dateStr = formatter.string(from: snapshotDate)

        var diffOutput = """
        --- Snapshot (\(dateStr))
        +++ Current Document
        Summary: +\(insertedCount) lines added, -\(removedCount) lines removed.
        \n
        """

        var removedDict: [Int: String] = [:]
        var insertedDict: [Int: String] = [:]
        for change in diff {
            switch change {
            case .remove(let offset, let element, _):
                removedDict[offset] = element
            case .insert(let offset, let element, _):
                insertedDict[offset] = element
            }
        }

        var diffLines: [String] = []
        for (offset, line) in removedDict.sorted(by: { $0.key < $1.key }) {
            diffLines.append("-\t[L\(offset + 1)] \(line)")
        }
        for (offset, line) in insertedDict.sorted(by: { $0.key < $1.key }) {
            diffLines.append("+\t[L\(offset + 1)] \(line)")
        }

        if diffLines.count > 100 {
            let truncatedLines = diffLines.prefix(100).joined(separator: "\n")
            diffOutput += truncatedLines + "\n...(Diff truncated, showing first 100 changes out of \(diffLines.count))"
        } else {
            diffOutput += diffLines.joined(separator: "\n")
        }

        return diffOutput
    }
}
