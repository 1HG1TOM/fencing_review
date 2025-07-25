import Foundation
import WatchConnectivity
import WatchKit

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendFlagTimestamp() {
        guard let session = session, session.isReachable else {
            print("iPhone に到達できません")
            return
        }

        // ハプティックフィードバックを追加
        WKInterfaceDevice.current().play(.click)

        let currentTimestamp = Date().timeIntervalSince1970
        let message: [String: Any] = ["flag_timestamp": currentTimestamp]

        session.sendMessage(message, replyHandler: nil) { error in
            print("送信失敗: \(error.localizedDescription)")
        }
    }

    // WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated: \(activationState.rawValue)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("接続状態が変更されました: \(session.isReachable)")
    }
}
