import Foundation
import UIKit

// MARK: - Service Protocols

public protocol CameraService: AnyObject {
    func start() throws
    func stop()
    func captureStill(completion: @escaping (UIImage?) -> Void)
    func accumulatedImages() -> [UIImage]
    func clearAccumulated()
}

public protocol AzureStorageService {
    func uploadImages(_ images: [UIImage]) async throws -> [String] // URLs
    func getSASToken(containerName: String, fileName: String) async throws -> String
    func saveSession(_ session: SessionData) async throws
}

public protocol DocumentIntelligenceService {
    func analyzeDocument(imageUrls: [String]) async throws -> OCRResult
}

public protocol OpenAIService {
    func processText(ocrText: String, documentType: DocumentType, customPrompt: String?) async throws -> String // Structured text
}

public protocol LocalStorageService {
    func saveSession(_ session: SessionData) throws
    func loadSessions() throws -> [SessionData]
    func deleteSession(id: String) throws
    func saveCustomPrompt(_ prompt: CustomPrompt) throws
    func loadCustomPrompts() throws -> [CustomPrompt]
}

