//
//  WhatsNewConfiguration.swift
//  MDWriter
//
//  Created for WhatsNewKit Integration.
//

import Foundation
import WhatsNewKit

struct WhatsNewConfiguration {
    /// Current app version (CFBundleShortVersionString)
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.9.12"
    }

    /// Define the "What's New" content for the current version
    static var current: WhatsNew {
        WhatsNew(
            // The version identifying these features.
            // Usually matches your Bundle Version.
            version: appVersion,

            title: WhatsNew.Title(text: WhatsNew.Text(String(localized: "What's New in MDWriter"))),

            features: [
                WhatsNew.Feature(
                    image: .init(systemName: "bolt.circle"),
                    title: WhatsNew.Text(String(localized: "Live Markdown Rendering")),
                    subtitle: WhatsNew.Text(
                        String(
                            localized:
                                "Markdown styling now updates immediately while you type, matching a true WYSIWYG experience."
                        ))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "tray.and.arrow.down"),
                    title: WhatsNew.Text(String(localized: "Reliable Auto-Save")),
                    subtitle: WhatsNew.Text(
                        String(
                            localized:
                                "Edits are saved automatically with debounce and safe flush on note switch or app deactivation."
                        ))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "sparkles"),
                    title: WhatsNew.Text(String(localized: "Stability Improvements")),
                    subtitle: WhatsNew.Text(
                        String(
                            localized:
                                "Multiple editor and system integrations have been hardened for smoother daily use."
                        ))
                ),
            ],
            primaryAction: .init(title: WhatsNew.Text(String(localized: "Continue")))
        )
    }
}
