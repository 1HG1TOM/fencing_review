import Foundation
import WatchConnectivity
import WatchKit

struct FlagItem: Codable, Hashable {
    let id: UUID
    let timestamp: TimeInterval
}

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isReachable: Bool = false
    private var session: WCSession?

    private let pendingKey = "pending_flags_v1"
    private var pendingFlags: [FlagItem] = [] {
        didSet { savePending() }
    }

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        pendingFlags = loadPending()
    }

    func sendFlagTimestamp() {
        let currentTimestamp = Date().timeIntervalSince1970
        let item = FlagItem(id: UUID(), timestamp: currentTimestamp)
        WKInterfaceDevice.current().play(.success)

        guard let session = session else { return }

        if session.isReachable {
            // 即時送信を試みる
            let message: [String: Any] = ["flag_timestamp": currentTimestamp]
            session.sendMessage(message, replyHandler: nil) { error in
                print("⚠️ 即時送信失敗: \(error.localizedDescription)")
                self.enqueue(item)
            }
        } else {
            print("📡 オフライン → バッファに追加")
            enqueue(item)
        }
    }

    // 接続復帰時にバッファを送る
    private func flushPending() {
        guard let session = session else { return }
        guard !pendingFlags.isEmpty else { return }

        if session.isReachable {
            print("📤 再接続 → \(pendingFlags.count)件を即時送信")
            for item in pendingFlags {
                let msg: [String: Any] = ["flag_timestamp": item.timestamp]
                session.sendMessage(msg, replyHandler: nil) { error in
                    print("⚠️ 再送失敗: \(error.localizedDescription)")
                }
            }
            pendingFlags.removeAll()
        } else {
            // まだ到達不可 → 遅延配送キューに投入
            print("📦 transferUserInfoで遅延配送")
            let userInfo: [String: Any] = [
                "type": "flags_batch",
                "flags": pendingFlags.map { ["id": $0.id.uuidString, "ts": $0.timestamp] }
            ]
            session.transferUserInfo(userInfo)
            pendingFlags.removeAll()
        }
    }

    // MARK: - UserDefaults保存
    private func enqueue(_ item: FlagItem) {
        pendingFlags.append(item)
        savePending()
    }

    private func savePending() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(pendingFlags) {
            UserDefaults.standard.set(data, forKey: pendingKey)
        }
    }

    private func loadPending() -> [FlagItem] {
        guard let data = UserDefaults.standard.data(forKey: pendingKey) else { return [] }
        let dec = JSONDecoder()
        return (try? dec.decode([FlagItem].self, from: data)) ?? []
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if session.isReachable { self.flushPending() }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if session.isReachable { self.flushPending() }
        }
    }
}
