import SwiftUI

@main
struct KoEReqOCRApp: App {
    @StateObject private var sessionManager = SessionManager(storage: LocalStorageServiceImpl())

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CameraView()
            }
            .environmentObject(sessionManager)
        }
    }
}

