import Foundation
import AVFoundation
import UIKit

final class CameraSession: NSObject, CameraService, AVCapturePhotoCaptureDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var images: [UIImage] = []
    private var lastPhotoDelegate: PhotoDelegateWrapper?

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
            #if DEBUG
            print("[Diag] session start requested")
            #endif
            if !session.inputs.isEmpty {
                if !session.isRunning { session.startRunning() }
                #if DEBUG
                print("[Diag] session already configured; running=\(session.isRunning)")
                #endif
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
            photoOutput.isHighResolutionCaptureEnabled = true
            // Prefer quality when available
            if #available(iOS 16.0, *) {
                photoOutput.maxPhotoQualityPrioritization = .quality
            }
            session.commitConfiguration()
            session.startRunning()
            #if DEBUG
            print("[Diag] session started; running=\(session.isRunning)")
            #endif
        }
        if let error = thrownError { throw error }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func captureStill(completion: @escaping (UIImage?) -> Void) {
        #if DEBUG
        print("[Flow] capture request; running=\(self.session.isRunning)")
        #endif
        let settings = AVCapturePhotoSettings()
        if self.photoOutput.isHighResolutionCaptureEnabled { settings.isHighResolutionPhotoEnabled = true }
        if #available(iOS 16.0, *) { settings.photoQualityPrioritization = .quality }
        let delegate = PhotoDelegateWrapper { [weak self] image in
            if let img = image { self?.images.append(img) }
            completion(image)
            // Release strong ref after completion
            self?.lastPhotoDelegate = nil
        }
        self.lastPhotoDelegate = delegate
        DispatchQueue.main.async {
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
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
                #if DEBUG
                print("[Flow] didFinishProcessingPhoto: no image data")
                #endif
                handler(nil)
                return
            }
            #if DEBUG
            print("[Flow] didFinishProcessingPhoto: image ok size=\(data.count)B")
            #endif
            handler(image)
        }
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
            #if DEBUG
            if let error { print("[Flow] didFinishCaptureFor error: \(error.localizedDescription)") } else { print("[Flow] didFinishCaptureFor success") }
            #endif
        }
    }
}

