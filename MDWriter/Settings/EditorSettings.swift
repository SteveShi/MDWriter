import Combine
import MDEditor
import SwiftUI

extension MarkdownStandard {
    var displayName: LocalizedStringKey {
        switch self {
        case .markdownXL: return LocalizedStringKey("Markdown XL")
        case .standard: return LocalizedStringKey("Standard")
        }
    }
}

@MainActor
class EditorSettings: ObservableObject {
    static let shared = EditorSettings()

    // 字体
    @AppStorage("editorFontName") var fontName: String = "System" {
        didSet { notifyChange() }
    }
    // 取消 fontSize 设置

    @AppStorage("editorLineHeight") var lineHeightMultiple: Double = 1.7 {
        didSet { notifyChange() }
    }

    // 布局
    @AppStorage("editorContentWidth") var contentWidth: Double = 750.0 {
        didSet { notifyChange() }
    }
    @AppStorage("editorParagraphSpacing") var paragraphSpacing: Double = 18.0 {
        didSet { notifyChange() }
    }
    @AppStorage("editorFirstLineIndent") var firstLineIndent: Double = 0.0 {
        didSet { notifyChange() }
    }

    // 行为
    @AppStorage("editorTypewriterMode") var typewriterMode: Bool = true {
        didSet { notifyChange() }
    }

    // Markdown
    @AppStorage("markdownStandard") var markdownStandard: MarkdownStandard = .markdownXL {
        didSet { notifyChange() }
    }

    // 对外发布的配置快照
    @Published var configuration: EditorConfiguration

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.configuration = EditorConfiguration(
            fontName: "PingFang SC",
            lineHeightMultiple: 1.7,
            contentWidth: 750.0,
            paragraphSpacing: 18.0,
            firstLineIndent: 0.0,
            typewriterMode: true,
            markdownStandard: .markdownXL
        )

        // Initial sync
        self.updateConfiguration()

        // Observe external UserDefaults changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateConfiguration()
                }
            }
            .store(in: &cancellables)
    }

    private func notifyChange() {
        updateConfiguration()
    }

    private func updateConfiguration() {
        let newConfig = EditorConfiguration(
            fontName: fontName,
            lineHeightMultiple: CGFloat(lineHeightMultiple),
            contentWidth: CGFloat(contentWidth),
            paragraphSpacing: CGFloat(paragraphSpacing),
            firstLineIndent: CGFloat(firstLineIndent),
            typewriterMode: typewriterMode,
            markdownStandard: markdownStandard,
            imageProvider: { filename in
                ImageManager.shared.loadImage(named: filename)
            }
        )

        if self.configuration != newConfig {
            self.configuration = newConfig
            self.objectWillChange.send()
        }
    }
}
