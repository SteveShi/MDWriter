# CHANGELOG

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
- **Resolved Compilation Errors**: Fixed theme-related build failures and missing `UniformTypeIdentifiers` imports.
- **Theme System Upgrade**: Simplified theme selection to "Light" and "Dark" modes.
- **Performance Tuning**: Improved document loading times and full-text search performance.

### UI Updates
- **Library View Refinement**: Polished the sidebar layout for folders and notes to align more closely with macOS design guidelines.