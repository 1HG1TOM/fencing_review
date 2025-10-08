import SwiftUI

struct ContentView: View {
    @ObservedObject var connectivity = WatchConnectivityManager()

    var body: some View {
        VStack(spacing: 20) {
            // 接続状態表示
            Text(connectivity.isReachable ? "📡 接続中" : "📴 未接続")
                .font(.footnote)
                .foregroundColor(connectivity.isReachable ? .green : .red)

            // フラグ送信ボタン（大きく・緑に）
            Button(action: {
                connectivity.sendFlagTimestamp()
            }) {
                Text("フラグ")
                    .font(.title2.bold())
                    .frame(width: 140, height: 140)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 8)
            }
            .buttonStyle(PlainButtonStyle()) // デフォルトの小型化を防ぐ
        }
        .padding()
    }
}
