import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            NavigationLink("オリジナル文書編集") { CustomPromptEditorView() }
            NavigationLink("ストレージ確認") { StorageBrowserView() }
        }
        .navigationTitle("設定")
    }
}

