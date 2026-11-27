import SwiftUI
import MDEditorKit

struct MarkdownViewWrapper: View {
    let text: String
    let configuration: EditorConfiguration
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("markdownTheme") private var markdownThemeRaw: String = MarkdownTheme.pure.rawValue

    private var markdownTheme: MarkdownTheme {
        MarkdownTheme.fromStorage(markdownThemeRaw)
    }

    var body: some View {
        let isDark = (colorScheme == .dark)
        MDEditorMarkdownPreview(
            text: text,
            configuration: configuration,
            theme: .default
        )
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
            .background(markdownTheme.paperColor(isDark: isDark))
            .foregroundStyle(markdownTheme.textColor(isDark: isDark))
    }
}
