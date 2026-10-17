//
//  CloudKitSyncManager.swift
//  MDWriter
//
//  Created by Steve Shi on 2026/10/18.
//

import CloudKit
import Combine
import Foundation
import SwiftData
import SwiftUI

/// iCloud 同步状态机
enum CloudKitSyncStatus: Equatable, Sendable {
    case disabled
    case provisioningRequired(reason: String)
    case accountAvailable(accountID: String)
    case noAccount
    case restricted
    case syncing
    case synced(lastSync: Date)
    case error(String)

    var localizedDescription: LocalizedStringKey {
        switch self {
        case .disabled:
            return LocalizedStringKey("Disabled (Local-First)")
        case .provisioningRequired:
            return LocalizedStringKey("Apple Developer Signature Required")
        case .accountAvailable:
            return LocalizedStringKey("iCloud Account Ready")
        case .noAccount:
            return LocalizedStringKey("No iCloud Account Signed In")
        case .restricted:
            return LocalizedStringKey("iCloud Access Restricted")
        case .syncing:
            return LocalizedStringKey("Syncing with iCloud...")
        case .synced:
            return LocalizedStringKey("All Changes Synced")
        case .error(let msg):
            return LocalizedStringKey(msg)
        }
    }

    var statusColor: Color {
        switch self {
        case .disabled: return .secondary
        case .provisioningRequired: return .orange
        case .accountAvailable, .synced: return .green
        case .syncing: return .blue
        case .noAccount, .restricted, .error: return .red
        }
    }
}

/// iCloud (CloudKit) 同步主控管理器
/// 遵循用户约束：完整实现架构与检测逻辑，但默认不启用（需付费开发者证书签名才可安全开启）
@MainActor
final class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()

    /// 【开发者代码启用总开关】
    /// 默认为 false，UI 完全隐藏且不启动 CloudKit。
    /// 当开通付费 Apple 开发者账户并配置 Team ID & Entitlements 后，只需将此处改为 `true` 即可直接通过代码启用整个 iCloud 同步功能。
    public static let isFeatureAvailable: Bool = false

    /// 同步开关：默认为 false，保证在无付费开发者签名环境下的零崩溃与 Local-First 安全
    @AppStorage("mdwriter_cloudkit_sync_enabled") var isCloudKitSyncEnabled: Bool = false {
        didSet {
            updateStatus()
        }
    }

    @Published private(set) var syncStatus: CloudKitSyncStatus = .disabled
    @Published private(set) var lastSyncDate: Date? = nil
    @Published private(set) var isCheckingAccount: Bool = false

    let containerIdentifier: String = "iCloud.com.steveshi.mdwriter"

    private init() {
        updateStatus()
    }

    private func updateStatus() {
        if !isCloudKitSyncEnabled {
            syncStatus = .disabled
        } else {
            syncStatus = .provisioningRequired(reason: "Requires Apple Developer Program Team ID & iCloud Entitlements")
        }
    }

    /// 检查 macOS 本机 iCloud 账户状态
    func checkiCloudAccountStatus() async {
        isCheckingAccount = true
        defer { isCheckingAccount = false }

        guard isCloudKitSyncEnabled else {
            syncStatus = .disabled
            return
        }

        do {
            let container = CKContainer(identifier: containerIdentifier)
            let status = try await container.accountStatus()
            switch status {
            case .available:
                if let recordID = try? await container.userRecordID() {
                    syncStatus = .accountAvailable(accountID: recordID.recordName)
                } else {
                    syncStatus = .accountAvailable(accountID: "Active")
                }
            case .noAccount:
                syncStatus = .noAccount
            case .restricted:
                syncStatus = .restricted
            case .couldNotDetermine:
                syncStatus = .provisioningRequired(reason: "Could not determine iCloud account status")
            case .temporarilyUnavailable:
                syncStatus = .error("iCloud temporarily unavailable")
            @unknown default:
                syncStatus = .error("Unknown iCloud status")
            }
        } catch {
            // 在未签名环境捕获由于 Entitlements 缺失抛出的异常，平滑降级，绝不崩溃
            syncStatus = .provisioningRequired(reason: error.localizedDescription)
        }
    }

    /// 创建 SwiftData 的 ModelConfiguration
    /// 依据 isCloudKitSyncEnabled 安全切换，未启用时使用纯本地存储
    func makeModelConfiguration(schema: Schema, url: URL? = nil) -> ModelConfiguration {
        if Self.isFeatureAvailable && isCloudKitSyncEnabled {
            #if DEBUG
            print("[CloudKitSyncManager] Initializing with CloudKit database: private")
            #endif
            return ModelConfiguration(
                schema: schema,
                url: url ?? URL.documentsDirectory.appending(path: "MDWriter.store"),
                cloudKitDatabase: .private(containerIdentifier)
            )
        } else {
            return ModelConfiguration(
                schema: schema,
                url: url ?? URL.documentsDirectory.appending(path: "MDWriter.store"),
                cloudKitDatabase: .none
            )
        }
    }

    /// 标记一次同步完成
    func markSyncSuccess() {
        let now = Date()
        lastSyncDate = now
        if isCloudKitSyncEnabled {
            syncStatus = .synced(lastSync: now)
        }
    }
}
