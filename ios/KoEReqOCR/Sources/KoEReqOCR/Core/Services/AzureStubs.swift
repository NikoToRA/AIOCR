import Foundation
import UIKit

struct AzureStorageStub: AzureStorageService {
    func uploadImages(_ images: [UIImage]) async throws -> [String] {
        // Return mock blob URLs
        return images.enumerated().map { idx, _ in "https://example.blob.core.windows.net/tmp/img_\(idx).jpg" }
    }

    func getSASToken(containerName: String, fileName: String) async throws -> String {
        return "sv=2024-01-01&sig=stub"
    }

    func saveSession(_ session: SessionData) async throws { /* no-op for MVP */ }
}

struct DocumentIntelligenceStub: DocumentIntelligenceService {
    func analyzeDocument(imageUrls: [String]) async throws -> OCRResult {
        // Minimal fake OCR result
        return OCRResult(textBlocks: ["サンプルOCRテキスト"], tables: [], checkboxes: [])
    }
}

struct OpenAIStub: OpenAIService {
    func processText(ocrText: String, documentType: DocumentType, customPrompt: String?) async throws -> String {
        // Echo back structured-like format
        return "[\(documentType.rawValue)]\n\(ocrText)\n\(customPrompt ?? "")"
    }
}

