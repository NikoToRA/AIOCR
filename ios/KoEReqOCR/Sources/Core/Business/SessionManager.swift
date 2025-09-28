import Foundation
import UIKit

@MainActor
final class SessionManager: ObservableObject {
    @Published var currentImages: [UIImage] = []
    @Published var capturedCount: Int = 0

    private let storage: LocalStorageService

    init(storage: LocalStorageService) { self.storage = storage }

    func addImage(_ image: UIImage) {
        currentImages.append(image)
        capturedCount = currentImages.count
    }

    func clear() {
        currentImages.removeAll()
        capturedCount = 0
    }

    func saveSession(editedText: String, type: DocumentType, customPrompt: String?) {
        let datas = currentImages.compactMap { $0.jpegDataMedium }
        var session = SessionData(images: datas, originalText: "", editedText: editedText, documentType: type, customPromptUsed: customPrompt)
        session.createdAt = Date()
        try? storage.saveSession(session)
    }

    func storedSessions() -> [SessionData] {
        (try? storage.loadSessions()) ?? []
    }
}

