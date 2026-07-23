import Combine
import MDEditorKit
import SwiftUI

@MainActor
class EditorSettings: ObservableObject {
    static let shared = EditorSettings()

    // 字体
    @AppStorage("editorFontName") var fontName: String = "System" {
        didSet { notifyChange() }
    }

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

    // 行为
    @AppStorage("editorTypewriterMode") var typewriterMode: Bool = true {
        didSet { notifyChange() }
    }

    // 配色主题（与预览/导出一致）
    @AppStorage("markdownTheme") var markdownThemeRaw: String = MarkdownTheme.pure.rawValue {
        didSet { notifyChange() }
    }

    // 应用明暗主题（与 AppTheme 同源），用于决定 Pure 主题下编辑器文字颜色
    @AppStorage("appTheme") var appThemeRaw: String = AppTheme.light.rawValue {
        didSet { notifyChange() }
    }

    private var currentMarkdownTheme: MarkdownTheme {
        MarkdownTheme(rawValue: markdownThemeRaw) ?? .pure
    }

    private var currentAppTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .light
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
            typewriterMode: true,
            theme: MarkdownTheme.pure.editorTheme(for: AppTheme.light)
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
        let zoom = UserDefaults.standard.double(forKey: "textZoom")
        let textZoom = zoom > 0 ? zoom : 1.0

        let showMarkup =
            UserDefaults.standard.object(forKey: "markdownShowMarkup") as? Bool ?? true

        var theme = currentMarkdownTheme.editorTheme(for: currentAppTheme)
        if !showMarkup {
            theme.syntaxMarker = theme.syntaxMarker.opacity(0.0)
        }

        var newConfig = EditorConfiguration(
            fontName: fontName,
            lineHeightMultiple: CGFloat(lineHeightMultiple),
            contentWidth: CGFloat(contentWidth),
            paragraphSpacing: CGFloat(paragraphSpacing),
            typewriterMode: typewriterMode,
            theme: theme,
            imageProvider: { filename in
                ImageManager.shared.loadImage(named: filename)
            },
            imageSaver: { image in
                ImageManager.shared.saveImage(image)
            }
        )
        newConfig.fontSize = 17.0 * CGFloat(textZoom)

        if self.configuration != newConfig {
            self.configuration = newConfig
            self.objectWillChange.send()
        }
    }
}
