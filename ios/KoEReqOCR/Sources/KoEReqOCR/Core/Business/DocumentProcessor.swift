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
    }

    func process(images: [UIImage], type: DocumentType, customPrompt: String?) async throws -> String {
        // MVP: local-only path with stubs; swap to real services later
        let urls = try await storage.uploadImages(images)
        let ocr = try await di.analyzeDocument(imageUrls: urls)
        let joined = ocr.textBlocks.joined(separator: "\n")
        let structured = try await openai.processText(ocrText: joined, documentType: type, customPrompt: customPrompt)
        return structured
    }
}

