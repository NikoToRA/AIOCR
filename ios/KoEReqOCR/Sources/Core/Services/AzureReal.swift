import Foundation
import UIKit

enum AzureError: Error { case configurationMissing, requestFailed, invalidResponse }

struct AzureConfig {
    let functionsBaseURL: URL
    let openAIEndpoint: URL
    let openAIDeployment: String

    static func load() -> AzureConfig? {
        guard let info = Bundle.main.infoDictionary,
              let fn = info["AZURE_FUNCTIONS_BASE_URL"] as? String,
              let fnURL = URL(string: fn),
              let oai = info["AZURE_OPENAI_ENDPOINT"] as? String,
              let oaiURL = URL(string: oai),
              let dep = info["AZURE_OPENAI_DEPLOYMENT"] as? String else { return nil }
        return AzureConfig(functionsBaseURL: fnURL, openAIEndpoint: oaiURL, openAIDeployment: dep)
    }
}

final class AzureFunctionsStorage: AzureStorageService {
    private let config: AzureConfig
    init?(config: AzureConfig? = AzureConfig.load()) { guard let cfg = config else { return nil }; self.config = cfg }

    func uploadImages(_ images: [UIImage]) async throws -> [String] {
        // Expect an Azure Function that returns pre-signed SAS URLs and we PUT images to them
        let reqURL = config.functionsBaseURL.appendingPathComponent("issueUploadUrls")
        let body = ["count": images.count]
        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: reqURL)
        req.httpMethod = "POST"; req.addValue("application/json", forHTTPHeaderField: "Content-Type"); req.httpBody = data

        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let list = try JSONSerialization.jsonObject(with: respData) as? [String], list.count == images.count else {
            throw AzureError.invalidResponse
        }

        // Upload each image via PUT to SAS URL
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (idx, urlStr) in list.enumerated() {
                group.addTask {
                    guard let url = URL(string: urlStr), let data = images[idx].jpegData(compressionQuality: 0.8) else { return }
                    var put = URLRequest(url: url); put.httpMethod = "PUT"; put.httpBody = data
                    put.addValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                    let (_, putResp) = try await URLSession.shared.data(for: put)
                    guard let http = putResp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw AzureError.requestFailed }
                }
            }
            try await group.waitForAll()
        }

        // Return public or internal URLs as given by Function
        return list
    }

    func getSASToken(containerName: String, fileName: String) async throws -> String {
        // Prefer uploadImages flow; keeping for interface compatibility
        throw AzureError.configurationMissing
    }

    func saveSession(_ session: SessionData) async throws {
        // Call Function to persist session metadata if needed
        // Not implemented in MVP
    }
}

final class AzureDocumentIntelligence: DocumentIntelligenceService {
    private let config: AzureConfig
    init?(config: AzureConfig? = AzureConfig.load()) { guard let cfg = config else { return nil }; self.config = cfg }

    func analyzeDocument(imageUrls: [String]) async throws -> OCRResult {
        // Expect an Azure Function that wraps DI call and returns OCRResult JSON
        let url = config.functionsBaseURL.appendingPathComponent("analyzeDocument")
        let body = ["urls": imageUrls]
        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.addValue("application/json", forHTTPHeaderField: "Content-Type"); req.httpBody = data
        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { throw AzureError.requestFailed }
        let result = try JSONDecoder().decode(OCRResult.self, from: respData)
        return result
    }
}

final class AzureOpenAIText: OpenAIService {
    private let config: AzureConfig
    init?(config: AzureConfig? = AzureConfig.load()) { guard let cfg = config else { return nil }; self.config = cfg }

    struct Payload: Codable { let ocrText: String; let documentType: String; let customPrompt: String?; let deployment: String }

    func processText(ocrText: String, documentType: DocumentType, customPrompt: String?) async throws -> String {
        // Expect an Azure Function that calls Azure OpenAI and returns structured text
        let url = config.functionsBaseURL.appendingPathComponent("processText")
        let payload = Payload(ocrText: ocrText, documentType: documentType.rawValue, customPrompt: customPrompt, deployment: config.openAIDeployment)
        let data = try JSONEncoder().encode(payload)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.addValue("application/json", forHTTPHeaderField: "Content-Type"); req.httpBody = data
        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { throw AzureError.requestFailed }
        guard let s = String(data: respData, encoding: .utf8) else { throw AzureError.invalidResponse }
        return s
    }
}

