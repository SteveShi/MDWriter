//
//  QuickEntryManager.swift
//  MDWriter
//
//  Created by Steve Shi on 2026/10/18.
//

import AppKit
import Foundation
import SwiftData
import SwiftUI

/// 菜单栏速记浮窗主控单例
@MainActor
final class QuickEntryManager: NSObject, ObservableObject {
    static let shared = QuickEntryManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var modelContainer: ModelContainer?

    private override init() {
        super.init()
    }

    /// 在应用程序启动时装载菜单栏图标与浮窗
    func setupStatusItem(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer

        // 创建状态栏条目
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                let image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "MDWriter Quick Entry")
                button.image = image
                button.target = self
                button.action = #selector(statusBarButtonClicked(_:))
                button.toolTip = "MDWriter Quick Entry"
            }
            self.statusItem = item
        }

        // 配置原生 NSPopover
        if popover == nil {
            let pop = NSPopover()
            pop.behavior = .transient
            pop.animates = true

            let rootView = QuickEntryView(onDismiss: { [weak self] in
                self?.closePopover()
            })
            .modelContainer(modelContainer)

            pop.contentViewController = NSHostingController(rootView: rootView)
            self.popover = pop
        }
    }

    @objc private func statusBarButtonClicked(_ sender: Any?) {
        togglePopover()
    }

    /// 切换速记浮窗显隐状态
    func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // 确保浮窗每次打开时都是激活状态
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// 关闭速记浮窗
    func closePopover() {
        popover?.performClose(nil)
    }
}
