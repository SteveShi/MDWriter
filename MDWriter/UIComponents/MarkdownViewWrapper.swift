import SwiftUI
import MDEditor

struct MarkdownViewWrapper: View {
    let text: String
    let configuration: EditorConfiguration
    
    var body: some View {
        MDEditorMarkdownPreview(
            text: text,
            configuration: configuration,
            theme: .default
        )
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
    }
}
