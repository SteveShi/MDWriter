//
//  UpdaterViewModel.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import Foundation
import SwiftUI
import Combine

// 临时占位，不依赖 Sparkle 库，以便您能直接运行并看到编辑器修复效果
class UpdaterViewModel: NSObject, ObservableObject {
    @Published var canCheckForUpdates = true
    
    func checkForUpdates() {
        // 当您安装了 Sparkle 2 后，请恢复之前的代码
        if let url = URL(string: "https://github.com/lpgneg19/MDWriter/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}
