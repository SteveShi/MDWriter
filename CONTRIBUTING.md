# Contributing to MDWriter

Thank you for your interest in contributing to MDWriter! We welcome contributions from everyone. By participating in this project, you help make MDWriter a better tool for the community.

## 🐛 Bug Reports

If you find a bug, please create an issue on GitHub. Be sure to include:

1.  **A descriptive title** of the issue.
2.  **Steps to reproduce** the bug.
3.  **Expected behavior** vs. **actual behavior**.
4.  Standard environment details (macOS version, MDWriter version).
5.  Screenshots or recordings if applicable.

## 💡 Feature Requests

We welcome ideas for new features! Please open an issue to discuss your idea before implementing it. This ensures that your work aligns with the project's goals and avoids duplicate effort.

## 🛠 Development Workflow

MDWriter uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project file. This prevents merge conflicts in the project file.

### Prerequisites

*   macOS 14.0+
*   Xcode 15.0+
*   [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Getting Started

1.  **Fork** the repository on GitHub.
2.  **Clone** your fork locally:
    ```bash
    git clone https://github.com/YOUR_USERNAME/MDWriter.git
    cd MDWriter
    ```
3.  **Generate the Xcode project**:
    ```bash
    xcodegen generate --spec project.yml
    ```
4.  **Open the project**:
    Open `MDWriter.xcodeproj` in Xcode.
5.  **Build and Run**:
    Select the `MDWriter` scheme and press `Cmd + R` to build and run the app.

### Dependencies

MDWriter uses Swift Package Manager for dependencies. Xcode will automatically resolve them when you open the project. Key dependencies include:
*   [Highlightr](https://github.com/raspu/Highlightr)
*   [Sparkle](https://github.com/sparkle-project/Sparkle)
*   [swift-markdown](https://github.com/swiftlang/swift-markdown)
*   [WhatsNewKit](https://github.com/SvenTiigi/WhatsNewKit)

## 📝 Coding Guidelines

*   **Language**: Swift 6.0
*   **UI Framework**: SwiftUI
*   **Data Persistence**: SwiftData
*   **Style**: Follow standard Swift style conventions. Keep code clean, readable, and well-documented where necessary.

## 🚀 Submitting a Pull Request

1.  Create a new branch for your changes:
    ```bash
    git checkout -b feature/your-feature-name
    ```
2.  Make your changes and verify them locally.
3.  Commit your changes with clear, descriptive commit messages.
4.  Push your branch to your fork:
    ```bash
    git push origin feature/your-feature-name
    ```
5.  Open a Pull Request on the main repository.

## 📄 License

By contributing, you agree that your contributions will be licensed under the [Mozilla Public License Version 2.0](LICENSE).
