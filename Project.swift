import ProjectDescription

let project = Project(
    name: "MDWriter",
    packages: [
        .package(url: "https://github.com/SteveShi/MDEditorKit.git", from: "2.1.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.4"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.1")
    ],
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "37YXT4PNH7",
            "SWIFT_VERSION": "6.0",
            "CODE_SIGN_STYLE": "Automatic",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "GENERATE_INFOPLIST_FILE": "YES",
            "COMBINE_HIDPI_IMAGES": "YES",
            "ENABLE_HARDENED_RUNTIME": "YES",
            "DEAD_CODE_STRIPPING": "YES",
            "SWIFT_COMPILATION_MODE": "wholemodule",
            "INFOPLIST_KEY_NSHumanReadableCopyright": "2025 Steve Shi. All Rights Reserved.",
            "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.productivity",
            "INFOPLIST_KEY_NSPrincipalClass": "NSApplication"
        ]
    ),
    targets: [
        .target(
            name: "MDWriter",
            destinations: .macOS,
            product: .app,
            bundleId: "listentotherain.MDWriter",
            deploymentTargets: .macOS("14.0"),
            sources: ["MDWriter/**"],
            resources: ["MDWriter/Assets.xcassets"],
            dependencies: [
                .package(product: "MDEditorKit"),
                .package(product: "Sparkle"),
                .package(product: "MCP")
            ],
            settings: .settings(
                base: [
                    "GENERATE_INFOPLIST_FILE": "YES",
                    "INFOPLIST_FILE": "MDWriter/App/Info.plist",
                    "PRODUCT_BUNDLE_IDENTIFIER": "listentotherain.MDWriter",
                    "COMBINE_HIDPI_IMAGES": "YES",
                    "ENABLE_HARDENED_RUNTIME": "YES",
                    "OTHER_LDFLAGS": ["-framework", "Sparkle"],
                    "CODE_SIGN_ENTITLEMENTS": "MDWriter/App/MDWriter.entitlements",
                    "MARKETING_VERSION": "$(MARKETING_VERSION)",
                    "CURRENT_PROJECT_VERSION": "$(CURRENT_PROJECT_VERSION)"
                ]
            )
        )
    ]
)
