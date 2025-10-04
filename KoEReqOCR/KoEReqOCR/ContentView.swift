//
//  ContentView.swift
//  KoEReqOCR
//
//  Created by Suguru Hirayama on 2025/09/28.
//

import SwiftUI
import AVFoundation
import UIKit

// シンプルなカメラプレビュー（依存を最小化した単体版）
struct CameraView: View {
    @State private var camera = SimpleCamera()
    @State private var capturedCount = 0
    @State private var showResult = false
    @State private var resultText = ""
    @State private var alert: String?
    @State private var showAccordion = false

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewLayer(camera: camera)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                .frame(width: UIScreen.main.bounds.width * 0.85,
                       height: UIScreen.main.bounds.height * 0.45)
                .blendMode(.difference)
                .padding(.top, 80)
                .allowsHitTesting(false)

            // 撮影済み枚数（下段中央の少し上に表示）
            if capturedCount > 0 {
                Text("\(capturedCount)枚撮影済み")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 140)
                    .transition(.opacity)
            }

            // 下段中央：シャッターボタンのみ
            HStack {
                Spacer()
                Button(action: shutter) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.2)).frame(width: 76, height: 76)
                        Circle().fill(Color.white).frame(width: 64, height: 64)
                    }
                }
                .accessibilityLabel("写真を撮影")
                Spacer()
            }
            .padding(.bottom, 40)

            // 右下：AI解析フローティング + アコーディオン
            VStack(alignment: .trailing, spacing: 10) {
                if showAccordion {
                    accordionButton(title: "紹介状") { selectTypeAndAnalyze("紹介状") }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    accordionButton(title: "お薬手帳") { selectTypeAndAnalyze("お薬手帳") }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    accordionButton(title: "一般テキスト") { selectTypeAndAnalyze("一般テキスト") }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                Button {
                    if capturedCount == 0 {
                        alert = "写真を撮影してください"
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showAccordion.toggle()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: showAccordion ? "xmark" : "wand.and.stars")
                            .font(.headline)
                        Text(showAccordion ? "閉じる" : "AI解析")
                            .font(.headline).bold()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .accessibilityLabel("AI解析メニュー")
            }
            .padding(.trailing, 16)
            .padding(.bottom, 24)
        }
        // シートはAIメニューに置き換えたため削除
        .sheet(isPresented: $showResult) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("解析結果（デモ）").bold()
                    TextEditor(text: $resultText)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                    Button("閉じる") { showResult = false }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
                .navigationTitle("結果")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear { requestCamera() }
        .alert(item: Binding(get: { alert.map { AlertItem(id: UUID(), message: $0) } }, set: { _ in alert = nil })) { a in
            Alert(title: Text("注意"), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
    }

    private func requestCamera() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                DispatchQueue.global(qos: .userInitiated).async { try? camera.start() }
            } else {
                DispatchQueue.main.async { alert = "カメラのアクセス許可が必要です" }
            }
        }
    }

    private func shutter() {
        camera.captureStill { img in
            if img != nil { DispatchQueue.main.async { capturedCount += 1 } }
        }
    }

    private func selectTypeAndAnalyze(_ type: String) {
        // デモ用: 実画像は使わずダミーを返す
        resultText = "[\(type)]\nサンプルOCRテキスト\n（ここにAzure連携の結果が入ります）"
        showResult = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showAccordion = false }
    }
}

private struct AlertItem: Identifiable { let id: UUID; let message: String }

// MARK: - Camera Preview Infrastructure
private struct CameraPreviewLayer: UIViewRepresentable {
    let camera: SimpleCamera
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        DispatchQueue.main.async { camera.attachPreview(to: v) }
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class SimpleCamera: NSObject {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()

    func attachPreview(to view: UIView) {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
    }

    func start() throws {
        guard session.inputs.isEmpty else { if !session.isRunning { session.startRunning() }; return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration(); throw NSError(domain: "Camera", code: -1, userInfo: nil)
        }
        session.addInput(input)
        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration(); throw NSError(domain: "Camera", code: -2, userInfo: nil)
        }
        session.addOutput(photoOutput)
        session.commitConfiguration()
        session.startRunning()
    }

    func captureStill(completion: @escaping (UIImage?) -> Void) {
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: PhotoDelegate(completion))
    }

    private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        private let completion: (UIImage?) -> Void
        init(_ completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard error == nil, let data = photo.fileDataRepresentation(), let img = UIImage(data: data) else { completion(nil); return }
            completion(img)
        }
    }
}

// MARK: - UI Parts
private func accordionButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.subheadline).bold()
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.9))
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            )
    }
    .accessibilityLabel("文書タイプ \(title)")
}

#Preview { CameraView() }
