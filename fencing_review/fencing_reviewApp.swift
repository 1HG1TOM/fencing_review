import SwiftUI

@main
struct fencing_reviewApp: App {
    // AppDelegate を接続
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
