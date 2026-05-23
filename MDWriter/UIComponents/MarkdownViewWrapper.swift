import SwiftUI
import MDEditor

struct MarkdownViewWrapper: View {
    let text: String
    let configuration: EditorConfiguration
    @AppStorage("markdownTheme") private var markdownTheme: MarkdownTheme = .pure

    var body: some View {
        MDEditorMarkdownPreview(
            text: text,
            configuration: configuration,
            theme: .default
        )
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
            .background(markdownTheme.paperColor)
            .foregroundStyle(markdownTheme.textColor)
            .environment(\.colorScheme, markdownTheme.isDark ? .dark : .light)
    }
}
