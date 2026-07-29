//
//  BackupSyncSettingsView.swift
//  MDWriter
//
//  Backup, Restore & Dropbox Sync Settings UI with AES-256 E2EE Encryption
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupSyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var syncService = DropboxSyncService.shared

    @State private var masterPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var hasMasterKeyInKeychain: Bool = false
    @State private var passwordMessage: String?
    @State private var isPasswordSuccess: Bool = false

    // Import / Restore States
    @State private var showImportPasswordDialog: Bool = false
    @State private var pendingImportData: Data?
    @State private var importPasswordInput: String = ""
    @State private var importErrorMessage: String?

    // Feedback Alerts
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        Form {
            // MARK: - Encryption Section
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey("Master Password & AES-256 Encryption"))
                                .font(.headline)
                            Text(LocalizedStringKey("Encrypt document backups and Dropbox sync data using AES-256-GCM."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    if hasMasterKeyInKeychain {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(LocalizedStringKey("Master Encryption Password is set in macOS Keychain."))
                                .font(.subheadline)
                            Spacer()
                            Button(role: .destructive) {
                                CryptoManager.shared.deleteMasterPassword()
                                hasMasterKeyInKeychain = false
                                masterPassword = ""
                                confirmPassword = ""
                            } label: {
                                Text(LocalizedStringKey("Remove Password"))
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField(LocalizedStringKey("Set Master Password"), text: $masterPassword)
                                .textFieldStyle(.roundedBorder)

                            SecureField(LocalizedStringKey("Confirm Master Password"), text: $confirmPassword)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Button(LocalizedStringKey("Save Master Password")) {
                                    savePassword()
                                }
                                .disabled(masterPassword.isEmpty || masterPassword != confirmPassword)

                                if let msg = passwordMessage {
                                    Text(msg)
                                        .font(.caption)
                                        .foregroundColor(isPasswordSuccess ? .green : .red)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(LocalizedStringKey("Security & Data Encryption"))
            }

            // MARK: - Backup & Restore Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey("Export your full document library as an encrypted .mdwbk snapshot or restore from a previous backup."))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        Button {
                            exportBackup()
                        } label: {
                            Label(LocalizedStringKey("Create Backup (.mdwbk)"), systemImage: "arrow.down.doc.fill")
                        }

                        Button {
                            importBackup()
                        } label: {
                            Label(LocalizedStringKey("Restore Backup (.mdwbk)"), systemImage: "arrow.up.doc.fill")
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(LocalizedStringKey("Library Backup & Restore"))
            }

            // MARK: - Dropbox Cloud Sync Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(LocalizedStringKey("Enable Dropbox Sync"), isOn: $syncService.isSyncEnabled)
                        .font(.body.bold())

                    if syncService.isSyncEnabled {
                        Picker(LocalizedStringKey("Sync Mode"), selection: $syncService.syncModeRaw) {
                            Text(LocalizedStringKey("Local Dropbox Directory")).tag(DropboxSyncMode.localFolder.rawValue)
                            Text(LocalizedStringKey("Dropbox REST API Token")).tag(DropboxSyncMode.apiToken.rawValue)
                        }
                        .pickerStyle(.segmented)

                        if syncService.syncMode == .localFolder {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizedStringKey("Dropbox Folder Path:"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Text(syncService.defaultDropboxFolderURL.path)
                                        .font(.caption.monospaced())
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .padding(6)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(4)

                                    Button(LocalizedStringKey("Choose Folder...")) {
                                        chooseDropboxFolder()
                                    }
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizedStringKey("Dropbox API Access Token:"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                SecureField(LocalizedStringKey("Enter Dropbox Bearer Token"), text: $syncService.apiToken)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        Toggle(LocalizedStringKey("End-to-End Encrypted Sync (E2EE)"), isOn: $syncService.encryptSyncData)
                            .font(.subheadline)

                        Picker(LocalizedStringKey("Auto Sync Frequency"), selection: $syncService.autoSyncIntervalMinutes) {
                            Text(LocalizedStringKey("Off")).tag(0)
                            Text(LocalizedStringKey("Every 5 minutes")).tag(5)
                            Text(LocalizedStringKey("Every 15 minutes")).tag(15)
                            Text(LocalizedStringKey("Every 1 hour")).tag(60)
                        }

                        Divider()

                        HStack {
                            Button {
                                syncService.performSync(context: modelContext)
                            } label: {
                                Label(LocalizedStringKey("Sync Now"), systemImage: "arrow.clockwise")
                            }
                            .disabled(syncService.syncStatus == .syncing)

                            Spacer()

                            HStack(spacing: 6) {
                                if syncService.syncStatus == .syncing {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(syncService.syncStatus.localizedDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(LocalizedStringKey("Dropbox Cloud Synchronization"))
            }
        }
        .formStyle(.grouped)
        .onAppear {
            hasMasterKeyInKeychain = CryptoManager.shared.getMasterPassword() != nil
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showImportPasswordDialog) {
            VStack(spacing: 16) {
                Text(LocalizedStringKey("Encrypted Backup File"))
                    .font(.headline)
                Text(LocalizedStringKey("This backup file is encrypted with AES-256. Please enter the decryption password to restore."))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                SecureField(LocalizedStringKey("Password"), text: $importPasswordInput)
                    .textFieldStyle(.roundedBorder)

                if let err = importErrorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                HStack(spacing: 12) {
                    Button(LocalizedStringKey("Cancel"), role: .cancel) {
                        showImportPasswordDialog = false
                        pendingImportData = nil
                    }

                    Button(LocalizedStringKey("Decrypt & Restore")) {
                        confirmDecryptAndRestore()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(importPasswordInput.isEmpty)
                }
            }
            .padding(20)
            .frame(width: 380)
        }
    }

    // MARK: - Actions

    private func savePassword() {
        guard masterPassword == confirmPassword else {
            passwordMessage = String(localized: "Passwords do not match.", comment: "Password error")
            isPasswordSuccess = false
            return
        }

        if CryptoManager.shared.saveMasterPassword(masterPassword) {
            hasMasterKeyInKeychain = true
            passwordMessage = String(localized: "Master Password saved successfully.", comment: "Password success")
            isPasswordSuccess = true
        } else {
            passwordMessage = String(localized: "Failed to save password to Keychain.", comment: "Password error")
            isPasswordSuccess = false
        }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.title = String(localized: "Export Library Backup", comment: "Save panel title")
        panel.nameFieldStringValue = "MDWriter_Backup_\(dateFormatter.string(from: Date())).mdwbk"
        panel.allowedContentTypes = [UTType(filenameExtension: "mdwbk") ?? .data]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let pwd = CryptoManager.shared.getMasterPassword()
                let data = try BackupManager.shared.createBackupData(context: modelContext, password: pwd)
                try data.write(to: url, options: .atomic)

                alertTitle = String(localized: "Backup Exported", comment: "Alert title")
                alertMessage = String(localized: "Successfully saved library backup to \(url.lastPathComponent).", comment: "Alert message")
                showAlert = true
            } catch {
                alertTitle = String(localized: "Export Error", comment: "Alert title")
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Restore Library Backup", comment: "Open panel title")
        panel.allowedContentTypes = [UTType(filenameExtension: "mdwbk") ?? .data]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                if CryptoManager.shared.isEncrypted(data: data) {
                    pendingImportData = data
                    importPasswordInput = CryptoManager.shared.getMasterPassword() ?? ""
                    importErrorMessage = nil
                    showImportPasswordDialog = true
                } else {
                    try BackupManager.shared.restoreBackup(from: data, password: nil, context: modelContext, replaceLibrary: false)
                    alertTitle = String(localized: "Library Restored", comment: "Alert title")
                    alertMessage = String(localized: "Successfully restored document library.", comment: "Alert message")
                    showAlert = true
                }
            } catch {
                alertTitle = String(localized: "Restore Error", comment: "Alert title")
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func confirmDecryptAndRestore() {
        guard let data = pendingImportData else { return }
        do {
            try BackupManager.shared.restoreBackup(from: data, password: importPasswordInput, context: modelContext, replaceLibrary: false)
            showImportPasswordDialog = false
            pendingImportData = nil

            alertTitle = String(localized: "Library Restored", comment: "Alert title")
            alertMessage = String(localized: "Successfully decrypted and restored document library.", comment: "Alert message")
            showAlert = true
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func chooseDropboxFolder() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Select Dropbox Sync Directory", comment: "Open panel title")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        panel.begin { response in
            if response == .OK, let url = panel.url {
                syncService.customFolderPath = url.path
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        return df
    }
}
