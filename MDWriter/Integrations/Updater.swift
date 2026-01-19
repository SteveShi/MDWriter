//
//  Updater.swift
//  MDWriter
//
//  Created for Sparkle Integration.
//

#if os(macOS)
import Foundation
import Sparkle
import SwiftUI
import Combine

/// A wrapper around Sparkle's SPUStandardUpdaterController
class Updater: ObservableObject {
    private let updaterController: SPUStandardUpdaterController
    
    @Published var canCheckForUpdates = false

    init() {
        // Initialize Sparkle
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    /// Manually check for updates
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
#endif