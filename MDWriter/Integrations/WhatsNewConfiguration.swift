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
    static var appVersion: WhatsNew.Version {
        .current(in: .main)
    }

    /// Update this only when there is a major feature release.
    static var whatsNewVersion: WhatsNew.Version {
        "1.9.11"
    }

    /// Define the "What's New" content for the current version
    static var current: WhatsNew {
        WhatsNew(
            // The version identifying these features.
            // Usually matches your Bundle Version.
            version: whatsNewVersion,

            title: WhatsNew.Title(text: WhatsNew.Text(String(localized: "What's New in MDWriter"))),

            features: [
                WhatsNew.Feature(
                    image: .init(systemName: "cpu"),
                    title: WhatsNew.Text(String(localized: "TextKit 2 Engine")),
                    subtitle: WhatsNew.Text(
                        String(
                            localized:
                                "A complete overhaul of the editor core for massive stability and performance gains."
                        ))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "paintpalette"),
                    title: WhatsNew.Text(String(localized: "Pro Markdown Rendering")),
                    subtitle: WhatsNew.Text(
                        String(
                            localized:
                                "Ulysses-style syntax highlighting with elegant faders for a distraction-free experience."
                        ))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "keyboard"),
                    title: WhatsNew.Text(String(localized: "IME Stability")),
                    subtitle: WhatsNew.Text(
                        String(
                            localized:
                                "Native support for Chinese input and mixed-language writing without cursor jumping."
                        ))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "photo"),
                    title: WhatsNew.Text(String(localized: "Inline Image Preview")),
                    subtitle: WhatsNew.Text(
                        String(
                            localized:
                                "View your local images directly inside the editor and export previews with ease."
                        ))
                ),
            ],
            primaryAction: .init(title: WhatsNew.Text(String(localized: "Continue")))
        )
    }
}
