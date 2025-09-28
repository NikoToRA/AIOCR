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
    @State private var showTypes = false
    @State private var showResult = false
    @State private var resultText = ""
    @State private var alert: String?

    var body: some View {
        ZStack {
            CameraPreviewLayer(camera: camera)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                .frame(width: UIScreen.main.bounds.width * 0.85,
                       height: UIScreen.main.bounds.height * 0.45)
                .blendMode(.difference)
                .padding(.top, 80)

            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Text(capturedCount > 0 ? "\(capturedCount)枚撮影済み" : "")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    HStack(spacing: 24) {
                        Button {
                            if capturedCount == 0 { alert = "写真を撮影してください" }
                            else { showTypes = true }
                        } label: {
                            Text("AIでテキスト化")
                                .bold()
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                        }

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
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showTypes) {
            VStack(spacing: 16) {
                Text("文書タイプを選択").font(.headline)
                HStack(spacing: 12) {
                    ForEach(["紹介状","お薬手帳","一般テキスト"], id: \.self) { t in
                        Button(t) {
                            resultText = simpleAnalyze()
                            showTypes = false
                            showResult = true
                        }.buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .presentationDetents([.medium])
        }
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

    private func simpleAnalyze() -> String {
        // デモ用: 実画像は使わずダミーを返す
        return "サンプルOCRテキスト\n（ここにAzure連携の結果が入ります）"
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

#Preview { CameraView() }
