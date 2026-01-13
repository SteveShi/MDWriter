# CHANGELOG

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