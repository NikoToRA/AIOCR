import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let camera: CameraSession
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        DispatchQueue.main.async { camera.attachPreview(to: v) }
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct CameraView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var camera = CameraSession()
    @State private var showTypeMenu = false
    @State private var showSettings = false
    @State private var processing = false
    @State private var alertMessage: String?
    @State private var navigateToResult: Bool = false
    @State private var resultText: String = ""
    @State private var chosenType: DocumentType = .generalText
    @State private var chosenCustomPrompt: String? = nil

    private let processor = DocumentProcessor(
        storage: AzureStorageStub(),
        di: DocumentIntelligenceStub(),
        openai: OpenAIStub()
    )

    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()

            guideOverlay

            VStack {
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding()
                Spacer()
                controlsBar
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationDestination(isPresented: $navigateToResult) {
            TextAnalysisView(text: resultText, documentType: chosenType, customPrompt: chosenCustomPrompt)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $showTypeMenu) {
            DocumentTypeMenu { type, customPrompt in
                chosenType = type
                chosenCustomPrompt = customPrompt
                Task { await startTextAnalysis() }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            AuditLogger.shared.log(.appLaunch)
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    // Heavy start on background thread to avoid UI hang warnings
                    DispatchQueue.global(qos: .userInitiated).async {
                        try? camera.start()
                        AuditLogger.shared.log(.cameraGranted)
                    }
                } else {
                    DispatchQueue.main.async {
                        alertMessage = "カメラのアクセス許可が必要です"
                        AuditLogger.shared.log(.cameraDenied)
                    }
                }
            }
        }
        .alert(item: Binding(get: { alertMessage.map { IdentifiedAlert(id: UUID(), message: $0) } }, set: { _ in alertMessage = nil })) { i in
            Alert(title: Text("注意"), message: Text(i.message), dismissButton: .default(Text("OK")))
        }
    }

    private var guideOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
            .frame(width: UIScreen.main.bounds.width * 0.85, height: UIScreen.main.bounds.height * 0.45)
            .blendMode(.difference)
            .padding(.top, 80)
    }

    private var controlsBar: some View {
        VStack(spacing: 12) {
            Text(sessionManager.capturedCount > 0 ? "\(sessionManager.capturedCount)枚撮影済み" : "")
                .font(.subheadline)
                .foregroundColor(.white)

            HStack(spacing: 24) {
                Button {
                    if sessionManager.capturedCount == 0 {
                        alertMessage = "写真を撮影してください"
                    } else {
                        showTypeMenu = true
                    }
                } label: {
                    Text("AIでテキスト化")
                        .bold()
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .disabled(processing)

                Button(action: shutter) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.2)).frame(width: 68, height: 68)
                        Circle().fill(Color.white).frame(width: 56, height: 56)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func shutter() {
        #if DEBUG
        print("[Flow] shutter tapped")
        #endif
        camera.captureStill { image in
            #if DEBUG
            print("[Flow] capture completion image=\(image != nil)")
            #endif
            if let img = image {
                // Ensure UI state updates happen on main thread
                DispatchQueue.main.async { sessionManager.addImage(img) }
            }
            AuditLogger.shared.log(.capture)
        }
    }

    private func startTextAnalysis() async {
        await MainActor.run { processing = true }
        let images = sessionManager.currentImages
        do {
            AuditLogger.shared.log(.analyzeStart)
            let text = try await processor.process(images: images, type: chosenType, customPrompt: chosenCustomPrompt)
            await MainActor.run {
                resultText = text
                navigateToResult = true
            }
            AuditLogger.shared.log(.analyzeSuccess)
        } catch {
            await MainActor.run {
                alertMessage = "解析に失敗しました: \(error.localizedDescription)"
            }
            AuditLogger.shared.log(.analyzeError, detail: error.localizedDescription)
        }
        await MainActor.run { processing = false }
    }
}

private struct IdentifiedAlert: Identifiable { let id: UUID; let message: String }
