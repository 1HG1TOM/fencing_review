import SwiftUI

@main
struct fencing_review: App {
    init() {
            _ = WatchConnectivityManageriPhone.shared // ← これがないとセッション起動しません
        }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
