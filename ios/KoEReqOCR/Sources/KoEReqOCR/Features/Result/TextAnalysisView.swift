import SwiftUI

struct TextAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager

    @ObservedObject var viewModel: AnalysisViewModel
    @State private var navigateToQR = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            TextEditor(text: $viewModel.text)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                .disabled(viewModel.stage == .ocrRunning || viewModel.stage == .llmRunning)
            HStack {
                Button("取り直し") {
                    retakePhotos()
                }
                .foregroundColor(.red)

                Spacer()

                Button {
                    navigateToQR = true
                } label: {
                    Text("QR生成")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.stage != .completed)
            }
        }
        .padding()
        .navigationTitle(viewModel.type.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToQR) {
            QRCodeView(
                text: viewModel.text,
                documentType: viewModel.type,
                customPrompt: viewModel.customPrompt,
                images: viewModel.images
            )
        }
        .onDisappear {
            // QRコード画面に遷移した場合は何もしない
            // カメラ画面に戻る場合のみクリア（戻るボタンor取り直し）
            if !navigateToQR {
                sessionManager.clear()
            }
        }
        .task { await viewModel.start() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            switch viewModel.stage {
            case .ocrRunning:
                ProgressView().scaleEffect(0.9)
                Text("OCR解析中…").foregroundColor(.secondary)
            case .llmRunning:
                ProgressView().scaleEffect(0.9)
                Text("LLM処理中…").foregroundColor(.secondary)
            case .completed:
                Text("編集可能").foregroundColor(.secondary)
            case .failed(let msg):
                Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                Text("エラー: \(msg)").foregroundColor(.secondary)
            case .idle:
                EmptyView()
            }
            Spacer()
        }
    }

    private func retakePhotos() {
        sessionManager.clear()
        dismiss()
    }
}
