//
//  WhatsNewConfiguration.swift
//  MDWriter
//
//  Created for WhatsNewKit Integration.
//

import Foundation
import WhatsNewKit

struct WhatsNewConfiguration {
    /// Define the "What's New" content for the current version
    static var current: WhatsNew {
        WhatsNew(
            // The version identifying these features.
            // Usually matches your Bundle Version.
            version: "1.0.0",
            
            title: WhatsNew.Title(text: WhatsNew.Text(String(localized: "Welcome to MDWriter"))),
            
            features: [
                WhatsNew.Feature(
                    image: .init(systemName: "square.and.pencil"),
                    title: WhatsNew.Text(String(localized: "Enhanced Editor")),
                    subtitle: WhatsNew.Text(String(localized: "Experience a distraction-free writing environment with new formatting tools."))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "sidebar.left"),
                    title: WhatsNew.Text(String(localized: "Library Management")),
                    subtitle: WhatsNew.Text(String(localized: "Organize your notes into folders and groups effortlessly."))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "arrow.triangle.2.circlepath"),
                    title: WhatsNew.Text(String(localized: "Auto-Updates")),
                    subtitle: WhatsNew.Text(String(localized: "MDWriter now keeps itself up to date automatically."))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "globe"),
                    title: WhatsNew.Text(String(localized: "Localization")),
                    subtitle: WhatsNew.Text(String(localized: "Fully localized interface for English and Simplified Chinese."))
                )
            ],
            primaryAction: .init(title: WhatsNew.Text(String(localized: "Get Started")))
        )
    }
}