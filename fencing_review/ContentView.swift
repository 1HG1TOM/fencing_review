import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn: Bool = false
    @State private var userID: String?

    var body: some View {
        if !isLoggedIn {
            LoginView { id in
                Logger.shared.setUser(id: id)
                userID = id
                isLoggedIn = true
            }
        } else {
            HomeView()
        }
    }
}
