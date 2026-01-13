# v1.7.0 Implementation Plan - History & Backup

This plan outlines the steps to implement Document Snapshots (History) and Full Library Backup/Restore.

## 1. Database Schema Update
- [ ] **Define `Snapshot` Model**:
    - `id`: UUID
    - `content`: String
    - `createdAt`: Date
    - `note`: Relationship to `Note`
- [ ] **Update `Note` Model**:
    - Add `@Relationship(deleteRule: .cascade) var snapshots: [Snapshot]`
- [ ] **Data Migration**: SwiftData should handle this automatically for simple additions.

## 2. Snapshot Logic
- [ ] **Manual Snapshot**:
    - Add "Save Version" / "Create Snapshot" command in File menu or Editor menu.
- [ ] **Automatic Snapshot**:
    - Implement logic to create a snapshot automatically:
        - Logic: If the last snapshot is older than X minutes (e.g., 10 min) AND changes have been made, create a new one on save/edit.
        - Alternatively: Create a snapshot on app open/close if changed.

## 3. Snapshot Browser UI
- [ ] **Snapshot List View**:
    - Access via "File > Browsing History" or Inspector.
    - List snapshots by date.
- [ ] **Comparison/Preview**:
    - When a snapshot is selected, show its content (read-only).
    - Provide "Restore" button.
- [ ] **Restore Logic**:
    - On Restore: Create a NEW snapshot of the *current* state (for safety), then replace `Note.content` with snapshot content.

## 4. Full Backup & Restore
- [ ] **Backup**:
    - Export all `Folder` and `Note` data to a JSON file (or a ZIP of JSONs).
    - or Zip the SwiftData store files. (JSON is more portable/safe across schema changes if we write a transformer).
    - *Decision*: We will implement a **JSON-based Archive** (`.mdwbk`) which contains all notes and folder structure. This is safer than raw SQL copying.
- [ ] **Restore**:
    - Import `.mdwbk` file.
    - Option 1: Merge with existing.
    - Option 2: Replace Library (Nuke and pave). **User likely wants this for "Restore Backup".**
    - Show confirmation alert.

## 5. UI Integration
- [ ] **Menu Items**:
    - File > Save Version
    - File > Browse Versions...
    - File > Backup Library...
    - File > Restore Library...

## Next Steps
1. Modify `Models.swift`.
2. Create `SnapshotService` or helper logic.
3. Build `BackupService`.
4. Implement UIs.
