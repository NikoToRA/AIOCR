import Foundation
import UIKit

enum AzureError: Error { case configurationMissing, requestFailed, invalidResponse }

struct AzureConfig {
    let functionsBaseURL: URL
    let functionsKey: String
    let openAIEndpoint: URL
    let openAIDeployment: String

    static func load() -> AzureConfig? {
        guard let info = Bundle.main.infoDictionary else {
            print("Azure config loading failed - no bundle info dictionary")
            return nil
        }

        print("Available keys in Info.plist: \(Array(info.keys).sorted())")

        guard let fn = info["AZURE_FUNCTIONS_BASE_URL"] as? String else {
            print("Azure config loading failed - missing AZURE_FUNCTIONS_BASE_URL")
            return nil
        }

        guard let fnURL = URL(string: fn) else {
            print("Azure config loading failed - invalid AZURE_FUNCTIONS_BASE_URL: \(fn)")
            return nil
        }

        guard let key = info["AZURE_FUNCTIONS_KEY"] as? String else {
            print("Azure config loading failed - missing AZURE_FUNCTIONS_KEY")
            return nil
        }

        guard let oai = info["AZURE_OPENAI_ENDPOINT"] as? String else {
            print("Azure config loading failed - missing AZURE_OPENAI_ENDPOINT")
            return nil
        }

        guard let oaiURL = URL(string: oai) else {
            print("Azure config loading failed - invalid AZURE_OPENAI_ENDPOINT: \(oai)")
            return nil
        }

        guard let dep = info["AZURE_OPENAI_DEPLOYMENT"] as? String else {
            print("Azure config loading failed - missing AZURE_OPENAI_DEPLOYMENT")
            return nil
        }

        print("Azure config loaded successfully")
        return AzureConfig(functionsBaseURL: fnURL, functionsKey: key, openAIEndpoint: oaiURL, openAIDeployment: dep)
    }
}

final class AzureFunctionsStorage: AzureStorageService {
    private let config: AzureConfig
    init?(config: AzureConfig? = AzureConfig.load()) {
        guard let cfg = config else {
            print("AzureFunctionsStorage init failed - config missing")
            return nil
        }
        self.config = cfg
        print("AzureFunctionsStorage initialized successfully")
    }

    func uploadImages(_ images: [UIImage]) async throws -> [String] {
        // Expect an Azure Function that returns pre-signed SAS URLs and we PUT images to them
        var urlComponents = URLComponents(url: config.functionsBaseURL.appendingPathComponent("issueUploadUrls"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "code", value: config.functionsKey)]
        let reqURL = urlComponents.url!

        print("🌐 uploadImages: Requesting \(reqURL.absoluteString)")
        print("📊 uploadImages: Image count = \(images.count)")

        let body = ["count": images.count]
        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: reqURL)
        req.httpMethod = "POST"; req.addValue("application/json", forHTTPHeaderField: "Content-Type"); req.httpBody = data

        print("🚀 uploadImages: Sending request...")
        let (respData, resp): (Data, URLResponse)
        do {
            (respData, resp) = try await URLSession.shared.data(for: req)
            print("✅ uploadImages: Received response")
        } catch {
            print("❌ uploadImages: Network error - \(error.localizedDescription)")
            print("❌ uploadImages: Error details - \(error)")
            throw AzureError.requestFailed
        }

        guard let http = resp as? HTTPURLResponse else {
            print("❌ uploadImages: invalid response type")
            throw AzureError.requestFailed
        }

        print("🔄 uploadImages: HTTP status \(http.statusCode)")

        guard http.statusCode == 200 else {
            if let errorBody = String(data: respData, encoding: .utf8) {
                print("❌ uploadImages: HTTP \(http.statusCode) - \(errorBody)")
            } else {
                print("❌ uploadImages: HTTP \(http.statusCode) - no body")
            }
            throw AzureError.requestFailed
        }

        guard let list = try JSONSerialization.jsonObject(with: respData) as? [String], list.count == images.count else {
            print("❌ uploadImages: invalid response format")
            throw AzureError.invalidResponse
        }

        // Upload each image via PUT to SAS URL
        print("📤 Uploading \(list.count) images to Blob Storage...")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (idx, urlStr) in list.enumerated() {
                group.addTask {
                    print("📸 Uploading image \(idx + 1)/\(list.count) to: \(urlStr)")
                    guard let url = URL(string: urlStr), let data = images[idx].jpegData(compressionQuality: 0.8) else {
                        print("❌ Failed to prepare image \(idx + 1)")
                        return
                    }
                    var put = URLRequest(url: url)
                    put.httpMethod = "PUT"
                    put.httpBody = data
                    put.addValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                    put.addValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")

                    print("🚀 Sending PUT request for image \(idx + 1)...")
                    let (_, putResp) = try await URLSession.shared.data(for: put)
                    guard let http = putResp as? HTTPURLResponse else {
                        print("❌ Invalid response for image \(idx + 1)")
                        throw AzureError.requestFailed
                    }
                    print("📦 Image \(idx + 1) upload: HTTP \(http.statusCode)")
                    guard (200..<300).contains(http.statusCode) else {
                        print("❌ Image \(idx + 1) upload failed: HTTP \(http.statusCode)")
                        throw AzureError.requestFailed
                    }
                }
            }
            try await group.waitForAll()
        }
        print("✅ All images uploaded successfully")

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
    init?(config: AzureConfig? = AzureConfig.load()) {
        guard let cfg = config else {
            print("AzureDocumentIntelligence init failed - config missing")
            return nil
        }
        self.config = cfg
        print("AzureDocumentIntelligence initialized successfully")
    }

    func analyzeDocument(imageUrls: [String]) async throws -> OCRResult {
        // Expect an Azure Function that wraps DI call and returns OCRResult JSON
        var urlComponents = URLComponents(url: config.functionsBaseURL.appendingPathComponent("analyzeDocument"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "code", value: config.functionsKey)]
        let url = urlComponents.url!

        print("🔍 analyzeDocument: Requesting \(url.absoluteString)")
        print("📋 analyzeDocument: URLs count = \(imageUrls.count)")

        let body = ["urls": imageUrls]
        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        print("🚀 analyzeDocument: Sending request...")
        let (respData, resp): (Data, URLResponse)
        do {
            (respData, resp) = try await URLSession.shared.data(for: req)
            print("✅ analyzeDocument: Received response")
        } catch {
            print("❌ analyzeDocument: Network error - \(error.localizedDescription)")
            print("❌ analyzeDocument: Error details - \(error)")
            throw AzureError.requestFailed
        }

        guard let http = resp as? HTTPURLResponse else {
            print("❌ analyzeDocument: Invalid response type")
            throw AzureError.requestFailed
        }

        print("🔄 analyzeDocument: HTTP status \(http.statusCode)")

        guard http.statusCode == 200 else {
            if let errorBody = String(data: respData, encoding: .utf8) {
                print("❌ analyzeDocument: HTTP \(http.statusCode) - \(errorBody)")
            } else {
                print("❌ analyzeDocument: HTTP \(http.statusCode) - no body")
            }
            throw AzureError.requestFailed
        }

        let result = try JSONDecoder().decode(OCRResult.self, from: respData)
        print("✅ analyzeDocument: Successfully decoded OCRResult")
        return result
    }
}

final class AzureOpenAIText: OpenAIService {
    private let config: AzureConfig
    init?(config: AzureConfig? = AzureConfig.load()) {
        guard let cfg = config else {
            print("AzureOpenAIText init failed - config missing")
            return nil
        }
        self.config = cfg
        print("AzureOpenAIText initialized successfully")
    }

    struct Payload: Codable { let ocrText: String; let documentType: String; let customPrompt: String?; let deployment: String }

    func processText(ocrText: String, documentType: DocumentType, customPrompt: String?) async throws -> String {
        // Expect an Azure Function that calls Azure OpenAI and returns structured text
        var urlComponents = URLComponents(url: config.functionsBaseURL.appendingPathComponent("processText"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "code", value: config.functionsKey)]
        let url = urlComponents.url!
        let payload = Payload(ocrText: ocrText, documentType: documentType.rawValue, customPrompt: customPrompt, deployment: config.openAIDeployment)
        let data = try JSONEncoder().encode(payload)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.addValue("application/json", forHTTPHeaderField: "Content-Type"); req.httpBody = data
        print("🧠 processText: Requesting \(url.absoluteString)")
        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            print("❌ processText: Invalid response type")
            throw AzureError.requestFailed
        }
        if http.statusCode != 200 {
            let body = String(data: respData, encoding: .utf8) ?? "<no body>"
            print("❌ processText: HTTP \(http.statusCode) - \(body)")
            throw AzureError.requestFailed
        }
        guard let s = String(data: respData, encoding: .utf8) else {
            print("❌ processText: failed to decode body as UTF-8")
            throw AzureError.invalidResponse
        }
        return s
    }
}
