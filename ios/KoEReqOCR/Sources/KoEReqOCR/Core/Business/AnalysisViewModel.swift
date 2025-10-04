import Foundation
import UIKit

@MainActor
final class AnalysisViewModel: ObservableObject {
    enum Stage: Equatable { case idle, ocrRunning, llmRunning, completed, failed(String) }

    @Published var text: String = ""
    @Published var stage: Stage = .idle

    let type: DocumentType
    let customPrompt: String?
    let images: [UIImage]

    private let processor: DocumentProcessor

    init(processor: DocumentProcessor, images: [UIImage], type: DocumentType, customPrompt: String?) {
        self.processor = processor
        self.images = images
        self.type = type
        self.customPrompt = customPrompt
    }

    func start() async {
        stage = .ocrRunning
        AuditLogger.shared.log(.analyzeStart)
        do {
            let ocrText = try await processor.performOCR(images: images)
            self.text = ocrText
            stage = .llmRunning
            let structured = try await processor.processLLM(ocrText: ocrText, type: type, customPrompt: customPrompt)
            self.text = structured
            stage = .completed
            AuditLogger.shared.log(.analyzeSuccess)
        } catch {
            stage = .failed(error.localizedDescription)
            AuditLogger.shared.log(.analyzeError, detail: error.localizedDescription)
        }
    }
}

