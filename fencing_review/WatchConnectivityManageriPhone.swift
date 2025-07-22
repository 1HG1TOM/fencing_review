import Foundation
import WatchConnectivity

class WatchConnectivityManageriPhone: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManageriPhone()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // CameraManager から登録される
    var onFlagReceived: ((TimeInterval) -> Void)?

    // フラグ送信を受信
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let timestamp = message["flag_timestamp"] as? TimeInterval {
            print("受信（non-reply）: flag_timestamp = \(timestamp)")
            onFlagReceived?(timestamp)
        } else {
            print("不明なメッセージ: \(message)")
        }
    }


    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch session activated with state: \(activationState.rawValue)")
    }
}
