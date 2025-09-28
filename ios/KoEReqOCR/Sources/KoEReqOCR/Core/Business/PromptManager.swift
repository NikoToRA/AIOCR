import Foundation

final class PromptManager {
    private let local: LocalStorageService

    init(local: LocalStorageService) { self.local = local }

    func presets() -> [CustomPrompt] {
        [
            .init(name: "紹介状", prompt: "紹介状の主要項目を抽出し、箇条書きで整形してください。"),
            .init(name: "お薬手帳", prompt: "薬剤名・用量・用法・期間を整形して一覧化してください。"),
            .init(name: "一般テキスト", prompt: "本文を段落として整形してください。")
        ]
    }

    func allCustom() -> [CustomPrompt] {
        (try? local.loadCustomPrompts()) ?? []
    }
}

