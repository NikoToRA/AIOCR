import SwiftUI

struct StorageBrowserView: View {
    @State private var sessions: [SessionData] = []
    private let local = LocalStorageServiceImpl()

    var body: some View {
        List {
            ForEach(sessions) { s in
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.documentType.rawValue).bold()
                    Text(s.editedText).font(.caption).foregroundColor(.secondary).lineLimit(2)
                    Text(s.createdAt.formatted()).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("ストレージ確認")
        .onAppear { reload() }
    }

    private func reload() { sessions = (try? local.loadSessions()) ?? [] }
}

