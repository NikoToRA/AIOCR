import SwiftUI

struct CustomPromptEditorView: View {
    @State private var prompts: [CustomPrompt] = []
    @State private var name: String = ""
    @State private var prompt: String = ""
    private let local = LocalStorageServiceImpl()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Form {
                Section("新規作成") {
                    TextField("文書名", text: $name)
                    TextEditor(text: $prompt).frame(minHeight: 120)
                    Button("保存") { save() }
                        .disabled(name.isEmpty || prompt.isEmpty)
                }
                Section("一覧") {
                    if prompts.isEmpty { Text("まだありません") }
                    ForEach(prompts) { item in
                        VStack(alignment: .leading) {
                            Text(item.name).bold()
                            Text(item.prompt).font(.caption).foregroundColor(.secondary).lineLimit(2)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(item) } label: { Label("削除", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .navigationTitle("オリジナル文書編集")
        .onAppear { reload() }
    }

    private func reload() { prompts = (try? local.loadCustomPrompts()) ?? [] }
    private func save() {
        let item = CustomPrompt(name: name, prompt: prompt)
        try? local.saveCustomPrompt(item)
        name = ""; prompt = ""; reload()
    }
    private func delete(_ item: CustomPrompt) {
        // Soft delete: overwrite without the item
        prompts.removeAll { $0.id == item.id }
        let data = try? JSONEncoder().encode(prompts)
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("KoEReqOCR"),
           let data {
            try? data.write(to: dir.appendingPathComponent("custom_prompts.json"), options: .atomic)
        }
        reload()
    }
}

