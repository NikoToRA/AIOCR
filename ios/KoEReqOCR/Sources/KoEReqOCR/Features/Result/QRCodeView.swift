import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct QRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager

    let text: String
    let documentType: DocumentType
    let customPrompt: String?
    let images: [UIImage]

    @State private var image: UIImage?
    @State private var saved = false

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        VStack(spacing: 16) {
            if let img = image {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260, height: 260)
                    .padding()
            } else {
                ProgressView()
            }

            if saved {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("保存しました")
                        .font(.subheadline).bold()
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.1))
                )
            }

            Text("このQRは編集後テキストをエンコードしています。")
                .font(.footnote).foregroundColor(.secondary)

            Button {
                // カメラ画面まで戻る（2画面前）
                sessionManager.clear()
                dismiss()
            } label: {
                Text("新しい撮影を開始")
                    .font(.headline).bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    )
            }
            .padding(.top, 8)

            Spacer()
        }
        .navigationTitle("QRコード")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                }
            }
        }
        .onAppear {
            generate()
            saveToStorage()
        }
        .padding()
    }

    private func generate() {
        let data = Data(text.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.correctionLevel = "M"
        if let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
           let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            image = UIImage(cgImage: cgimg)
        }
    }

    private func saveToStorage() {
        sessionManager.saveSession(editedText: text, type: documentType, customPrompt: customPrompt)
        AuditLogger.shared.log(.sessionSaved)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            saved = true
        }
    }
}

