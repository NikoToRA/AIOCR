import SwiftUI

struct TextAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager

    @State var text: String
    var documentType: DocumentType
    var customPrompt: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("解析結果（編集可）").font(.headline)
            TextEditor(text: $text)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
            HStack {
                Button("取り直し") { sessionManager.clear(); dismiss() }
                Spacer()
                NavigationLink(destination: QRCodeView(text: text)) {
                    Text("QR生成")
                }
                Button("保存") { saveAndClose() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle(documentType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveAndClose() {
        sessionManager.saveSession(editedText: text, type: documentType, customPrompt: customPrompt)
        AuditLogger.shared.log(.sessionSaved)
        dismiss()
    }
}
