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

    // 録画状態の送信メソッド
    func sendRecordingStateToWatch(_ isRecording: Bool) {
        let message = ["isRecording": isRecording]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("録画状態の送信に失敗: \(error.localizedDescription)")
            })
        } else {
            print("Apple Watch に接続されていません")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let timestamp = message["flag_timestamp"] as? TimeInterval {
            print("受信: flag_timestamp = \(timestamp)")
            onFlagReceived?(timestamp)
        }
    }
}
