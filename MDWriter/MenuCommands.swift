//
//  MenuCommands.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftUI

// MARK: - Focused Values
struct SelectedNoteKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var hasSelectedNote: Bool? {
        get { self[SelectedNoteKey.self] }
        set { self[SelectedNoteKey.self] = newValue }
    }
}

// MARK: - App Commands (Settings)
struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Button(LocalizedStringKey("Settings...")) {
                #if os(macOS)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                #endif
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

// MARK: - File Commands
struct FileCommands: Commands {
    @FocusedValue(\.hasSelectedNote) var hasSelectedNote: Bool?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(LocalizedStringKey("New Sheet")) {
                NotificationCenter.default.post(name: .newNote, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button(LocalizedStringKey("New Group")) {
                NotificationCenter.default.post(name: .newFolder, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button(LocalizedStringKey("Save Version")) {
                NotificationCenter.default.post(name: .createSnapshot, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(hasSelectedNote != true)

            Button(LocalizedStringKey("Browse Versions...")) {
                print("DEBUG: Menu item Browse Versions clicked")
                NotificationCenter.default.post(name: .showSnapshotBrowser, object: nil)
            }
            .disabled(hasSelectedNote != true)
            // Intentionally no shortcut, accessed via menu

            Divider()

            Button(LocalizedStringKey("Backup Library...")) {
                NotificationCenter.default.post(name: .backupLibrary, object: nil)
            }

            Button(LocalizedStringKey("Restore Library...")) {
                NotificationCenter.default.post(name: .restoreLibrary, object: nil)
            }

            Divider()

            Button(LocalizedStringKey("Import...")) {
                NotificationCenter.default.post(name: .importNote, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandGroup(after: .importExport) {
            Button(LocalizedStringKey("Print...")) {
                NotificationCenter.default.post(name: .printDocument, object: nil)
            }
            .keyboardShortcut("p", modifiers: .command)
        }
    }
}

// MARK: - Edit Commands (Find/Replace)
struct EditCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()

            Button(LocalizedStringKey("Find...")) {
                NotificationCenter.default.post(name: .showFind, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)

            Button(LocalizedStringKey("Find & Replace...")) {
                NotificationCenter.default.post(name: .showFindReplace, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button(LocalizedStringKey("Find Next")) {
                NotificationCenter.default.post(name: .findNext, object: nil)
            }
            .keyboardShortcut("g", modifiers: .command)

            Button(LocalizedStringKey("Find Previous")) {
                NotificationCenter.default.post(name: .findPrevious, object: nil)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
        }
    }
}

// MARK: - View Commands
struct ViewCommands: Commands {
    @Binding var showLibrary: Bool
    @Binding var showDashboard: Bool
    @Binding var showOutline: Bool
    @Binding var textZoom: CGFloat

    @Binding var currentTheme: AppTheme

    var body: some Commands {
        CommandGroup(replacing: .sidebar) {
            Button(
                showLibrary
                    ? LocalizedStringKey("Hide Library") : LocalizedStringKey("Show Library")
            ) {
                withAnimation { showLibrary.toggle() }
            }
            .keyboardShortcut("1", modifiers: .command)

            Button(
                showDashboard
                    ? LocalizedStringKey("Hide Dashboard") : LocalizedStringKey("Show Dashboard")
            ) {
                withAnimation { showDashboard.toggle() }
            }
            .keyboardShortcut("4", modifiers: .command)

            Divider()

            Button(
                showOutline
                    ? LocalizedStringKey("Hide Outline") : LocalizedStringKey("Show Outline")
            ) {
                withAnimation { showOutline.toggle() }
            }
            .keyboardShortcut("o", modifiers: [.command, .option])
        }

        CommandGroup(replacing: .toolbar) {
            Menu(LocalizedStringKey("Theme")) {
                Button(action: { currentTheme = .light }) {
                    Label(LocalizedStringKey("Light"), systemImage: "sun.max")
                }
                Button(action: { currentTheme = .dark }) {
                    Label(LocalizedStringKey("Dark"), systemImage: "moon")
                }
            }
        }

        CommandGroup(after: .toolbar) {
            Divider()

            Button(LocalizedStringKey("Zoom In")) {
                textZoom = min(textZoom + 0.1, 2.0)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button(LocalizedStringKey("Zoom Out")) {
                textZoom = max(textZoom - 0.1, 0.5)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button(LocalizedStringKey("Actual Size")) {
                textZoom = 1.0
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
}

// MARK: - Format Commands
struct FormatCommands: Commands {
    var body: some Commands {
        CommandMenu(LocalizedStringKey("Format")) {
            // Headings
            Menu(LocalizedStringKey("Heading")) {
                Button(LocalizedStringKey("Heading 1")) {
                    NotificationCenter.default.post(name: .formatHeading, object: 1)
                }
                .keyboardShortcut("1", modifiers: [.command, .control])

                Button(LocalizedStringKey("Heading 2")) {
                    NotificationCenter.default.post(name: .formatHeading, object: 2)
                }
                .keyboardShortcut("2", modifiers: [.command, .control])

                Button(LocalizedStringKey("Heading 3")) {
                    NotificationCenter.default.post(name: .formatHeading, object: 3)
                }
                .keyboardShortcut("3", modifiers: [.command, .control])

                Button(LocalizedStringKey("Heading 4")) {
                    NotificationCenter.default.post(name: .formatHeading, object: 4)
                }
                .keyboardShortcut("4", modifiers: [.command, .control])
            }

            Divider()

            // Text Styling
            Button(LocalizedStringKey("Bold")) {
                NotificationCenter.default.post(name: .formatBold, object: nil)
            }
            .keyboardShortcut("b", modifiers: .command)

            Button(LocalizedStringKey("Italic")) {
                NotificationCenter.default.post(name: .formatItalic, object: nil)
            }
            .keyboardShortcut("i", modifiers: .command)

            Button(LocalizedStringKey("Strikethrough")) {
                NotificationCenter.default.post(name: .formatStrikethrough, object: nil)
            }
            .keyboardShortcut("u", modifiers: [.command, .control])

            Button(LocalizedStringKey("Highlight")) {
                NotificationCenter.default.post(name: .formatHighlight, object: nil)
            }
            .keyboardShortcut("h", modifiers: [.command, .control])

            Divider()

            // Lists
            Menu(LocalizedStringKey("List")) {
                Button(LocalizedStringKey("Bulleted List")) {
                    NotificationCenter.default.post(name: .formatBulletList, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)

                Button(LocalizedStringKey("Numbered List")) {
                    NotificationCenter.default.post(name: .formatNumberedList, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button(LocalizedStringKey("Task List")) {
                    NotificationCenter.default.post(name: .formatTaskList, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
            }

            Divider()

            // Block Elements
            Button(LocalizedStringKey("Blockquote")) {
                NotificationCenter.default.post(name: .formatBlockquote, object: nil)
            }
            .keyboardShortcut("'", modifiers: .command)

            Button(LocalizedStringKey("Code Block")) {
                NotificationCenter.default.post(name: .formatCodeBlock, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)

            Button(LocalizedStringKey("Inline Code")) {
                NotificationCenter.default.post(name: .formatInlineCode, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Divider()

            // Links & Media
            Button(LocalizedStringKey("Link...")) {
                NotificationCenter.default.post(name: .insertLink, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .option])

            Button(LocalizedStringKey("Image...")) {
                NotificationCenter.default.post(name: .insertImage, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Divider()

            Button(LocalizedStringKey("Horizontal Rule")) {
                NotificationCenter.default.post(name: .insertHorizontalRule, object: nil)
            }
            .keyboardShortcut("-", modifiers: [.command, .shift])
        }
    }
}

// MARK: - Help Commands
struct HelpCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(LocalizedStringKey("MDWriter Help")) {
                if let url = URL(string: "https://github.com/lpgneg19/MDWriter") {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #else
                    UIApplication.shared.open(url)
                    #endif
                }
            }

            Button(LocalizedStringKey("Keyboard Shortcuts")) {
                NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
            }
            .keyboardShortcut("/", modifiers: .command)

            Divider()

            Button(LocalizedStringKey("What's New")) {
                NotificationCenter.default.post(name: .showWhatsNew, object: nil)
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    // Edit
    static let showFind = Notification.Name("showFind")
    static let showFindReplace = Notification.Name("showFindReplace")
    static let findNext = Notification.Name("findNext")
    static let findPrevious = Notification.Name("findPrevious")

    // Format - Headings
    static let formatHeading = Notification.Name("formatHeading")

    // Format - Text
    static let formatBold = Notification.Name("formatBold")
    static let formatItalic = Notification.Name("formatItalic")
    static let formatStrikethrough = Notification.Name("formatStrikethrough")
    static let formatHighlight = Notification.Name("formatHighlight")

    // Format - Lists
    static let formatBulletList = Notification.Name("formatBulletList")
    static let formatNumberedList = Notification.Name("formatNumberedList")
    static let formatTaskList = Notification.Name("formatTaskList")

    // Format - Blocks
    static let formatBlockquote = Notification.Name("formatBlockquote")
    static let formatCodeBlock = Notification.Name("formatCodeBlock")
    static let formatInlineCode = Notification.Name("formatInlineCode")

    // Insert
    static let insertLink = Notification.Name("insertLink")
    static let insertImage = Notification.Name("insertImage")
    static let insertHorizontalRule = Notification.Name("insertHorizontalRule")

    // Other
    static let printDocument = Notification.Name("printDocument")
    static let showKeyboardShortcuts = Notification.Name("showKeyboardShortcuts")
    static let showWhatsNew = Notification.Name("showWhatsNew")

    // File
    static let newNote = Notification.Name("newNote")
    static let newFolder = Notification.Name("newFolder")
    static let importNote = Notification.Name("importNote")
    static let createSnapshot = Notification.Name("createSnapshot")
    static let showSnapshotBrowser = Notification.Name("showSnapshotBrowser")
    static let backupLibrary = Notification.Name("backupLibrary")
    static let restoreLibrary = Notification.Name("restoreLibrary")
}
