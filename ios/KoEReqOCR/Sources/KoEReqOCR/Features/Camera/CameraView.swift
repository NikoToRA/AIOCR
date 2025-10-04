import SwiftUI
import AVFoundation
import os.log

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
    @State private var showSettings = false
    @State private var alertMessage: String?
    @State private var navigateToResult: Bool = false
    @State private var chosenType: DocumentType = .generalText
    @State private var chosenCustomPrompt: String? = nil
    @State private var processing = false
    @State private var analysisVM: AnalysisViewModel? = nil
    @State private var showAccordion: Bool = false
    @State private var showCustomList: Bool = false
    @State private var customPrompts: [CustomPrompt] = []
    private let local = LocalStorageServiceImpl()

    private static let logger = Logger(subsystem: "com.wonderdrill.KoEReqOCR", category: "CameraView")

    // Prefer Azure if configured; fall back to local stubs
    private let processor = DocumentProcessor(
        storage: AzureFunctionsStorage() ?? AzureStorageStub(),
        di: AzureDocumentIntelligence() ?? DocumentIntelligenceStub(),
        openai: AzureOpenAIText() ?? OpenAIStub()
    )

    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()


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
                bottomOverlay
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationDestination(isPresented: $navigateToResult) {
            if let vm = analysisVM { TextAnalysisView(viewModel: vm) }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .onAppear {
            AuditLogger.shared.log(.appLaunch)
            customPrompts = (try? local.loadCustomPrompts()) ?? []

            // Log Azure service status
            if AzureFunctionsStorage() != nil {
                Self.logger.notice("Azure integration: ENABLED")
            } else {
                Self.logger.warning("Azure integration: DISABLED - using stubs")
            }

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

    private var bottomOverlay: some View {
        ZStack {
            // 右下：AI解析フローティング + アコーディオン
            VStack(alignment: .trailing, spacing: 12) {
                Spacer()

                if showAccordion {
                    accordionButton(title: DocumentType.referralLetter.rawValue, icon: "doc.text.fill", color: .cyan) {
                        selectAndNavigate(type: .referralLetter, customPrompt: nil)
                    }
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))

                    accordionButton(title: DocumentType.medicationNotebook.rawValue, icon: "pills.fill", color: .green) {
                        selectAndNavigate(type: .medicationNotebook, customPrompt: nil)
                    }
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))

                    accordionButton(title: DocumentType.generalText.rawValue, icon: "text.alignleft", color: .purple) {
                        selectAndNavigate(type: .generalText, customPrompt: nil)
                    }
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))

                    accordionButton(title: DocumentType.custom.rawValue, icon: "sparkles", color: .orange) {
                        if sessionManager.capturedCount == 0 {
                            alertMessage = "写真を撮影してください"
                        } else if customPrompts.isEmpty {
                            selectAndNavigate(type: .custom, customPrompt: nil)
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showCustomList.toggle() }
                        }
                    }
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))

                    if showCustomList && !customPrompts.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .trailing, spacing: 8) {
                                ForEach(customPrompts.prefix(6)) { p in
                                    Button {
                                        selectAndNavigate(type: .custom, customPrompt: p.prompt)
                                    } label: {
                                        Text(p.name)
                                            .font(.caption).bold()
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                    .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
                                            )
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    }
                }

                Button {
                    if sessionManager.capturedCount == 0 {
                        alertMessage = "写真を撮影してください"
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showAccordion.toggle()
                            if !showAccordion { showCustomList = false }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: showAccordion ? "xmark.circle.fill" : "wand.and.stars")
                            .font(.title3)
                            .foregroundColor(.white)
                        Text(showAccordion ? "閉じる" : "AI解析")
                            .font(.headline).bold()
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(showAccordion ?
                                LinearGradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.5)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: .blue.opacity(0.5), radius: 12, x: 0, y: 6)
                    )
                }
                .accessibilityLabel("AI解析メニュー")
            }
            .padding(.trailing, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // 下段中央：シャッターボタン（最前面）
            VStack {
                Spacer()

                // 撮影済みカウンタ
                if sessionManager.capturedCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.stack.fill")
                            .font(.caption)
                        Text("\(sessionManager.capturedCount)")
                            .font(.headline).bold()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 8)
                    .transition(.scale.combined(with: .opacity))
                }

                Button(action: shutter) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 84, height: 84)
                            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)

                        Circle()
                            .fill(.white)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.1), lineWidth: 2)
                            )
                    }
                }
                .accessibilityLabel("写真を撮影")
                .padding(.bottom, 40)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showAccordion)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showCustomList)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sessionManager.capturedCount)
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

    private func selectAndNavigate(type: DocumentType, customPrompt: String?) {
        chosenType = type
        chosenCustomPrompt = customPrompt
        let vm = AnalysisViewModel(processor: processor, images: sessionManager.currentImages, type: type, customPrompt: customPrompt)
        analysisVM = vm
        navigateToResult = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showAccordion = false }
    }

    // Analysis flow handled in TextAnalysisView via AnalysisViewModel
}

// MARK: - UI Parts
private func accordionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
            Text(title)
                .font(.subheadline).bold()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.9), color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
        )
    }
    .accessibilityLabel("文書タイプ \(title)")
}

private struct IdentifiedAlert: Identifiable { let id: UUID; let message: String }
