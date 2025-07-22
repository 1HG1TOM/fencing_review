import SwiftUI

struct ContentView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager()

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()

                Button(action: {
                    connectivityManager.sendFlagTimestamp()
                }) {
                    Text("フラグ")
                        .font(.title2)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }
}
