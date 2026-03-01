import SwiftUI
import MarkdownView

struct MarkdownViewWrapper: View {
    let text: String
    
    var body: some View {
        MarkdownView(text)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
    }
}
