# Changelog

## [1.5.1] - 2026-01-12

### Fixed
- **Theme Adaptation**: Fixed editor font color not adapting to light/dark mode (remained white in light mode).
- **Settings Synchronization**: Fixed issue where typography settings (font, size, etc.) and theme selection in the Preferences window did not sync in real-time with the main editor.
- **System Theme Support**: Improved "Follow System" theme logic to ensure the AppKit editor updates immediately when macOS switches appearance.

### Changed
- Refactored theme and typography management to a global state for better cross-window synchronization.
- Updated CI/CD pipeline to support Universal (Intel/Apple Silicon) DMG packaging.

## [1.5.0] - 2026-01-12

### Added
- **Ulysses-Style Library**: Modern navigation with "All Documents" and "Inbox" sections.
- **Find & Replace**: Full-featured find and replace functionality in the editor.
- **Keyboard Shortcuts**: Added a new keyboard shortcuts reference sheet (Cmd+/).
- **Dashboard**: Added word count and reading time overlay.

### Changed
- Version numbering updated to 1.5.0.
- Refactored View menu to consolidate visibility toggles.
- Improved sidebar layout and localization.
