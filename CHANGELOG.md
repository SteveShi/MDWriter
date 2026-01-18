# CHANGELOG

## [1.9.9] - 2026-01-18
### New Features
- **Automatic Updates**: Integrated the **Sparkle** framework to keep the application up-to-date with the latest features and security fixes.
- **What's New**: Introduced a "What's New" welcome screen powered by **WhatsNewKit** to highlight key changes upon updating.
- **Localization**: Achieved full interface localization for English and Simplified Chinese, including all menus, toolbars, and settings.

### Bug Fixes
- **Release Automation**: Final hardening of Sparkle private key injection and appcast generation to resolve Keychain and path issues.
- **Build System**: Fixed incorrect app bundle selection (Sparkle's Updater.app vs MDWriter.app).
- **Window State Restoration**: Implemented window frame and sidebar state persistence. The application now correctly remembers its size, position, and sidebar visibility across launches.
- **WhatsNewKit Persistence**: Fixed an issue where the "What's New" screen would not automatically appear on the first launch after an update by explicitly syncing version identifiers.
- **Swift 6 Concurrency**: Resolved `ObservableObject` and `@MainActor` isolation conflicts in the `Updater` component.
- **Sendable Model Transfers**: Re-engineered the note drag-and-drop mechanism using a `NoteTransfer` proxy struct to comply with Swift 6 strict concurrency requirements for non-sendable SwiftData models.
- **Redundant Conformance**: Removed redundant `Sendable` declarations in `MarkdownTextStorage` and `Note` model to eliminate compiler warnings.

### Improvements
- **Menu Integration**: Added dedicated menu items for "Check for Updates" and "What's New" in the application and help menus.
- **Hardcoded String Cleanup**: Audited the codebase to replace hardcoded strings with localized keys, ensuring a consistent experience across languages.
- **Development Tooling**: Prepared support for **XCStringsTool** to streamline future localization workflows.
- **Automatic Update Settings**: Added a new "Updates" section in General Settings with a toggle to control automatic update checking.
- **Sparkle Integration**: Optimized the Sparkle updater with better state handling and added the necessary EdDSA public key for secure update verification.
- **Help Menu**: Added a "What's New" item to the Help menu for manual access to version highlights.
- **Dependency Patching**: Applied source-level fixes to the `XCStringsTool` dependency to resolve `@retroactive` attribute conflicts during compilation.

## [1.8.1] - 2026-01-15
### Editor & Performance
- **Highlighting Cache**: Introduced an `NSCache` for code block highlighting, eliminating redundant computations and significantly improving typing fluidness in documents with multiple code blocks.
- **Database-Level Filtering**: Refactored the note list to use dynamic SwiftData predicates. Filtering and searching are now handled at the database layer, greatly reducing memory overhead and UI lag for large libraries.

### Visual Styling
- **Unified Syntax Symbols**: All Markdown markers (headers, bold, italic, etc.) now use a consistent, lightweight font weight and fixed size.
- **Improved Block Rendering**: Enhanced visual distinction for blockquotes with subtle backgrounds and refined list item alignment with proper hanging indents for multi-line entries.
- **List Preview Fidelity**: Restored "What You See Is What You Get" rendering for note summaries in the sidebar, supporting inline Markdown styles.

### Engineering
- **Predicate Stability**: Fixed compilation errors caused by complex SwiftData predicate expressions.
- **Chinese Documentation**: Fully localized internal code comments to Chinese for better maintainability.

## [1.8.0] - 2026-01-15
### Engineering & Architecture
- **Swift 6 Migration**: Fully migrated the codebase to **Swift 6** with strict concurrency checking to eliminate data races and enhance overall system stability.
- **Improved Data Isolation**: Refactored `MarkdownTextStorage` and editor bindings to comply with modern Swift concurrency requirements, fixing a critical input-related crash.
- **Regex Compatibility**: Resolved escape character issues in the syntax highlighting engine to ensure compatibility with the latest Swift compilers.

### Editor & Performance
- **Enhanced Code Highlighting**: Integrated the **Highlightr** engine to provide professional and accurate syntax highlighting for code blocks.
- **Highlighting Optimization**: Implemented Regex object caching in the MarkX engine, significantly reducing typing latency and CPU usage during long-form writing.
- **Typewriter Mode**: Refined the vertical scrolling logic in typewriter mode for a more fluid and natural writing experience.

### Improvements
- **Dependency Clean-up**: Optimized project dependencies and resolved several asset catalog warnings to ensure a cleaner build process.
- **Documentation**: Synchronized and updated the project README to reflect the latest engineering standards.

## [1.7.0] - 2026-01-13
### Added
- **Document Snapshots**: Save versions of your document manually (File > Save Version or `Cmd+Opt+S`).
- **Snapshot Browser**: View document history, compare character counts, and restore previous versions (File > Browse Versions...).
- **Full Library Backup**: Export your entire library including folders, notes, and version history to a `.mdwbk` file (File > Backup Library...).
- **Library Restore**: Restore your library from a backup file (File > Restore Library...).

## [1.6.1] - 2026-01-13

### Engineering & Infrastructure
- **Removed Deprecated Updater**: Removed the custom `AppUpdater` component in favor of the industry-standard **Sparkle** framework for more reliable and secure application updates.
- **Codebase Clean-up**: Eliminated redundant view models and unused dependencies, resulting in a cleaner architecture and slightly reduced application size.
- **Sparkle Integration Prep**: Added necessary configurations and dependencies to fully support Sparkle 2.0 for future updates.

### Fixes
- **Drag and Drop Reliability**: Fixed an issue where dragging documents could fail or cause data inconsistencies. Implemented a robust `NoteID` transfer mechanism to ensure seamless interaction between the library, sidebar, and trash.
- **System Integrity**: Added proper `UTExportedTypeDeclarations` for `com.mdwriter.note` in Debug builds to fix drag-and-drop debugging issues.

## [1.6.0] - 2026-01-13

### New Features
- **Ulysses-style Professional Editor**: A complete overhaul of the text editing area to replicate the premium aesthetics and functionality of Ulysses.
- **High-Performance Rendering Engine**: Rebuilt the highlighting system using a specialized regex engine. This ensures 100% accurate rendering for Chinese characters and an exceptionally smooth ("絲滑") input experience with stable font weights.
- **Refined Markdown Symbols**: Markers like `#`, `*`, and `**` are now elegantly understated—sized to 70% of base text, 50% opacity, and perfectly bottom-aligned to the text baseline to minimize visual noise.
- **Professional Bottom Toolbar**: Replaced the old dashboard with a sleek, Ulysses-inspired footer toolbar. It provides instant access to common formatting and a "More Options" popover with a comprehensive set of Markdown shortcuts and structural tools.
- **Optimized Chinese Typography**: Pre-configured the editor with "PingFang SC", 1.7x line height, and 12pt paragraph spacing for superior readability of Chinese and mixed-language content.
- **Drag and Drop support**: Documents can now be dragged and dropped into folders, the inbox, or the trash for intuitive organization.
- **Trash Functionality**: Deleted documents are now moved to a "Trash" folder instead of being immediately removed.
- **Markdown Theme System**: Added 8 professional themes (Pure, Solarized Light/Dark, GitHub, Dracula, Nord, Monokai, Night Owl) for both editor and export.
- **Auto-Title Sync**: Document titles now automatically update based on the first line of content.
- **Typewriter Mode**: Added optional vertical cursor centering for a more focused writing experience.

### Fixes and Improvements
- **Real-time Settings Sync**: Rebuilt the settings backend using a global observer pattern. Changes to Markdown standards or typography now apply instantly across all windows without requiring an app restart.
- **Iconography Overhaul**: Updated all toolbar icons to a cohesive style, including a new text-based "Aa" font settings button and professional icons for images and themes.
- **Enhanced Markdown Support**: Improved visual styling for task lists, nested lists, code blocks with backgrounds, and compact link/image markers.
- **PDF Export Fix**: Resolved issues with blank PDFs and poor dark-mode visibility by ensuring explicit background/text colors and A4 layout.
- **Visual Refinement**: Achieved a seamless, integrated UI by removing safe area gaps, redundant separators, and consolidating settings dialogs.
- **Sandbox Compatibility**: Enabled local image rendering and replaced the previous update mechanism with a lightweight, sandbox-friendly checker.
- **Localization Audit**: Completed and synchronized English and Simplified Chinese localizations across all interface elements.

## [1.5.3] - 2026-01-12

### UI Updates
- **Menu Bar Consolidation**: Merged redundant "View" menus into a single, system-integrated menu for a cleaner macOS experience.
- **Integrated Theme Selection**: Theme selection is now conveniently accessible directly from the "View" menu.

### CI/CD Improvements
- **Release Automation**: Updated GitHub Actions to automatically extract release notes from `CHANGELOG.md` upon tagging.

## [1.5.2] - 2026-01-12

### Core Improvements
- **Full SwiftData Integration**: Replaced legacy file-system management with a modern SwiftData database for robust data persistence.
- **Auto-Save Functionality**: Optimized the editor binding logic to ensure every change is instantly synced to the database.

### Fixes and Optimizations
- **Resolved Compilation Errors**: Fixed theme-related build failures and missing imports.
- **Theme System Upgrade**: Simplified theme selection to "Light" and "Dark" modes.
- **Performance Tuning**: Improved document loading times and full-text search performance.

### UI Updates
- **Library View Refinement**: Polished the sidebar layout for folders and notes to align more closely with macOS design guidelines.
