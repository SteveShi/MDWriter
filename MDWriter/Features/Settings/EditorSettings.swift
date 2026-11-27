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

    // 行为与写作专注模式
    @AppStorage("editorTypewriterMode") var typewriterMode: Bool = true {
        didSet { notifyChange() }
    }
    @AppStorage("editorTypewriterAnchor") var typewriterAnchorRaw: String = TypewriterAnchor.center.rawValue {
        didSet { notifyChange() }
    }
    @AppStorage("editorFocusMode") var focusModeRaw: String = EditorFocusMode.off.rawValue {
        didSet { notifyChange() }
    }
    @AppStorage("editorOutdentSyntaxMarkers") var outdentSyntaxMarkers: Bool = true {
        didSet { notifyChange() }
    }
    @AppStorage("editorHighlightCurrentLine") var highlightCurrentLine: Bool = false {
        didSet { notifyChange() }
    }
    @AppStorage("editorRenderMathInline") var renderMathInline: Bool = true {
        didSet { notifyChange() }
    }

    var typewriterAnchor: TypewriterAnchor {
        get { TypewriterAnchor(rawValue: typewriterAnchorRaw) ?? .center }
        set { typewriterAnchorRaw = newValue.rawValue }
    }

    var focusMode: EditorFocusMode {
        get { EditorFocusMode(rawValue: focusModeRaw) ?? .off }
        set { focusModeRaw = newValue.rawValue }
    }

    // 配色主题（每套均原生支持亮色与暗色双色板，与预览/导出一致）
    @AppStorage("markdownTheme") var markdownThemeRaw: String = MarkdownTheme.pure.rawValue {
        didSet { notifyChange() }
    }

    // 应用外观模式（跟随系统 / 亮色 / 暗色）
    @AppStorage("appTheme") var appThemeRaw: String = AppTheme.system.rawValue {
        didSet { notifyChange() }
    }

    /// 由 SwiftUI 根视图同步过来的系统当前明暗状态，避免在 System 模式下读取延迟。
    private var observedSystemIsDark: Bool?

    private var currentMarkdownTheme: MarkdownTheme {
        MarkdownTheme.fromStorage(markdownThemeRaw)
    }

    private var currentAppTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }

    /// 当前最终生效的暗色状态（兼顾 System / Light / Dark）。
    var effectiveIsDark: Bool {
        switch currentAppTheme {
        case .light: return false
        case .dark: return true
        case .system:
            return observedSystemIsDark ?? currentAppTheme.resolvedIsDark()
        }
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
            typewriterAnchor: .center,
            focusMode: .off,
            outdentSyntaxMarkers: true,
            highlightCurrentLine: false,
            renderMathInline: true,
            theme: MarkdownTheme.pure.editorTheme(isDark: AppTheme.system.resolvedIsDark())
        )

        self.updateConfiguration()

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateConfiguration()
                }
            }
            .store(in: &cancellables)

        // 监听 macOS 系统亮/暗外观切换，保证 System 模式下编辑器即时变色
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.observedSystemIsDark = nil
                    self?.updateConfiguration()
                }
            }
            .store(in: &cancellables)
    }

    /// 供 ContentView 在 SwiftUI `@Environment(\.colorScheme)` 变更时立即同步。
    func syncSystemColorScheme(_ scheme: ColorScheme) {
        let isDark = (scheme == .dark)
        if observedSystemIsDark != isDark {
            observedSystemIsDark = isDark
            updateConfiguration()
        }
    }

    private func notifyChange() {
        updateConfiguration()
    }

    private func updateConfiguration() {
        let zoom = UserDefaults.standard.double(forKey: "textZoom")
        let textZoom = zoom > 0 ? zoom : 1.0

        let showMarkup =
            UserDefaults.standard.object(forKey: "markdownShowMarkup") as? Bool ?? true

        var theme = currentMarkdownTheme.editorTheme(isDark: effectiveIsDark)
        if !showMarkup {
            theme.syntaxMarker = theme.syntaxMarker.opacity(0.0)
        }

        var newConfig = EditorConfiguration(
            fontName: fontName,
            lineHeightMultiple: CGFloat(lineHeightMultiple),
            contentWidth: CGFloat(contentWidth),
            paragraphSpacing: CGFloat(paragraphSpacing),
            typewriterMode: typewriterMode,
            typewriterAnchor: typewriterAnchor,
            focusMode: focusMode,
            outdentSyntaxMarkers: outdentSyntaxMarkers,
            highlightCurrentLine: highlightCurrentLine,
            renderMathInline: renderMathInline,
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
