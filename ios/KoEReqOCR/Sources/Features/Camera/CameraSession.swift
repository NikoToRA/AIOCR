import Foundation
import AVFoundation
import UIKit

final class CameraSession: NSObject, CameraService, AVCapturePhotoCaptureDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var images: [UIImage] = []

    func attachPreview(to view: UIView) {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    func start() throws {
        // Ensure all configuration and running happen on the dedicated queue
        var thrownError: Error?
        sessionQueue.sync {
            if !session.inputs.isEmpty {
                if !session.isRunning { session.startRunning() }
                return
            }
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                thrownError = NSError(domain: "Camera", code: -1, userInfo: [NSLocalizedDescriptionKey: "カメラ入力を初期化できません"])
                return
            }
            session.addInput(input)

            guard session.canAddOutput(photoOutput) else {
                session.commitConfiguration()
                thrownError = NSError(domain: "Camera", code: -2, userInfo: [NSLocalizedDescriptionKey: "出力を初期化できません"])
                return
            }
            session.addOutput(photoOutput)
            session.commitConfiguration()
            session.startRunning()
        }
        if let error = thrownError { throw error }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func captureStill(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: PhotoDelegateWrapper { [weak self] image in
                if let img = image { self?.images.append(img) }
                completion(image)
            })
        }
    }

    func accumulatedImages() -> [UIImage] { images }
    func clearAccumulated() { images.removeAll() }

    // Debug/diagnostic helpers
    func isRunning() -> Bool {
        var running = false
        sessionQueue.sync { running = session.isRunning }
        return running
    }

    // Wrapper to avoid retaining self as delegate
    private final class PhotoDelegateWrapper: NSObject, AVCapturePhotoCaptureDelegate {
        private let handler: (UIImage?) -> Void
        init(handler: @escaping (UIImage?) -> Void) { self.handler = handler }
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            #if DEBUG
            if let error { print("[Flow] photoOutput error: \(error.localizedDescription)") }
            #endif
            guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
                handler(nil)
                return
            }
            handler(image)
        }
    }
}

