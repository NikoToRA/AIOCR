import Foundation
import UIKit

final class DocumentProcessor {
    private let storage: AzureStorageService
    private let di: DocumentIntelligenceService
    private let openai: OpenAIService

    init(storage: AzureStorageService, di: DocumentIntelligenceService, openai: OpenAIService) {
        self.storage = storage
        self.di = di
        self.openai = openai
        print("📦 DocumentProcessor initialized - storage: \(String(describing: type(of: storage)))")
    }

    func performOCR(images: [UIImage]) async throws -> String {
        print("🔍 performOCR: Starting with \(images.count) images")
        print("📤 performOCR: Calling storage.uploadImages...")
        let urls = try await storage.uploadImages(images)
        print("✅ performOCR: Upload complete, got \(urls.count) URLs")
        print("📝 performOCR: Calling di.analyzeDocument...")
        let ocr = try await di.analyzeDocument(imageUrls: urls)
        print("✅ performOCR: Analysis complete")
        let joined = ocr.textBlocks.joined(separator: "\n")
        return joined
    }

    func processLLM(ocrText: String, type: DocumentType, customPrompt: String?) async throws -> String {
        let structured = try await openai.processText(ocrText: ocrText, documentType: type, customPrompt: customPrompt)
        return structured
    }

    func process(images: [UIImage], type: DocumentType, customPrompt: String?) async throws -> String {
        let joined = try await performOCR(images: images)
        let structured = try await processLLM(ocrText: joined, type: type, customPrompt: customPrompt)
        return structured
    }
}

