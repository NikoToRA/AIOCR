import Foundation
import UIKit

// MARK: - Core Models

public struct SessionData: Codable, Identifiable, Equatable {
    public let id: String
    public var images: [Data]
    public var originalText: String
    public var editedText: String
    public var documentType: DocumentType
    public var customPromptUsed: String?
    public var createdAt: Date
    public var qrCodeGenerated: Bool

    public init(id: String = UUID().uuidString,
                images: [Data] = [],
                originalText: String = "",
                editedText: String = "",
                documentType: DocumentType = .generalText,
                customPromptUsed: String? = nil,
                createdAt: Date = .init(),
                qrCodeGenerated: Bool = false) {
        self.id = id
        self.images = images
        self.originalText = originalText
        self.editedText = editedText
        self.documentType = documentType
        self.customPromptUsed = customPromptUsed
        self.createdAt = createdAt
        self.qrCodeGenerated = qrCodeGenerated
    }
}

public enum DocumentType: String, CaseIterable, Codable, Identifiable {
    case referralLetter = "紹介状"
    case medicationNotebook = "お薬手帳"
    case generalText = "一般テキスト"
    case custom = "オリジナル"

    public var id: String { rawValue }
}

public struct CustomPrompt: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var prompt: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString,
                name: String,
                prompt: String,
                createdAt: Date = .init()) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.createdAt = createdAt
    }
}

public struct CheckboxInfo: Codable, Equatable { public var label: String; public var checked: Bool }

public struct OCRResult: Codable, Equatable {
    public var textBlocks: [String]
    public var tables: [[[String]]]
    public var checkboxes: [CheckboxInfo]
}

// Helpers
public extension UIImage {
    var jpegDataMedium: Data? { jpegData(compressionQuality: 0.7) }
}

