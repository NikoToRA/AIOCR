import Foundation

final class LocalStorageServiceImpl: LocalStorageService {
    private let fm = FileManager.default
    private let baseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL? = nil) {
        if let baseURL { self.baseURL = baseURL }
        else {
            let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.baseURL = dir.appendingPathComponent("KoEReqOCR", isDirectory: true)
        }
        try? fm.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func saveSession(_ session: SessionData) throws {
        let url = baseURL.appendingPathComponent("session_\(session.id).json")
        let data = try encoder.encode(session)
        try data.write(to: url, options: .atomic)
    }

    func loadSessions() throws -> [SessionData] {
        let files = (try? fm.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.lastPathComponent.hasPrefix("session_") && $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? decoder.decode(SessionData.self, from: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func deleteSession(id: String) throws {
        let url = baseURL.appendingPathComponent("session_\(id).json")
        if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
    }

    func saveCustomPrompt(_ prompt: CustomPrompt) throws {
        var prompts = try loadCustomPrompts()
        if let idx = prompts.firstIndex(where: { $0.id == prompt.id }) {
            prompts[idx] = prompt
        } else {
            prompts.append(prompt)
        }
        let url = baseURL.appendingPathComponent("custom_prompts.json")
        let data = try encoder.encode(prompts)
        try data.write(to: url, options: .atomic)
    }

    func loadCustomPrompts() throws -> [CustomPrompt] {
        let url = baseURL.appendingPathComponent("custom_prompts.json")
        guard fm.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return (try? decoder.decode([CustomPrompt].self, from: data)) ?? []
    }
}

