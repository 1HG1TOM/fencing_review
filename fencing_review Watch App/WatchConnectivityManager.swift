import Foundation
import WatchConnectivity
import WatchKit

struct FlagItem: Codable, Hashable {
    let id: UUID
    let timestamp: TimeInterval
}

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    // 公開プロパティ（UIから参照したい場合）
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var pendingCount: Int = 0

    // 内部
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private let pendingKey = "pending_flags_v1"
    private var pendingFlags: [FlagItem] = [] {
        didSet { pendingCount = pendingFlags.count; savePending() }
    }

    override init() {
        super.init()
        if let s = session {
            s.delegate = self
            s.activate()
        }
        self.pendingFlags = loadPending()
        self.pendingCount = pendingFlags.count
    }

    // MARK: - Public API

    /// フラグ追加（押下時に呼ぶ）
    func addFlagNow() {
        // 触覚フィードバック
        WKInterfaceDevice.current().play(.click)

        let item = FlagItem(id: UUID(), timestamp: Date().timeIntervalSince1970)

        // 到達可能なら即時送信をまず試す
        if let s = session, s.isReachable {
            sendInstant([item]) { success in
                if !success {
                    // 失敗したらバッファへ
                    self.enqueue(items: [item])
                }
            }
        } else {
            // 未接続ならすぐ保存
            enqueue(items: [item])
        }
    }

    /// 再接続時などに呼んで、未送信を送る
    func flushPending() {
        guard !pendingFlags.isEmpty else { return }
        if let s = session, s.isReachable {
            // まずは即時まとめ送信を試す
            sendInstant(pendingFlags) { success in
                if success {
                    self.pendingFlags.removeAll()
                } else {
                    // 即時が無理なら、遅延配送に切替
                    self.sendDeferred(self.pendingFlags)
                    self.pendingFlags.removeAll()
                }
            }
        } else {
            // まだ到達不可：遅延配送キューにも入れておく（届くタイミングで配送される）
            sendDeferred(pendingFlags)
            pendingFlags.removeAll()
        }
    }

    // MARK: - 送信処理

    /// 即時送信（到達可：isReachable=true）
    private func sendInstant(_ items: [FlagItem], completion: @escaping (Bool) -> Void) {
        guard let s = session, s.isReachable else { completion(false); return }
        let payload: [String: Any] = [
            "type": "flags_batch",
            "flags": items.map { ["id": $0.id.uuidString, "ts": $0.timestamp] }
        ]
        s.sendMessage(payload, replyHandler: { _ in
            completion(true)
        }, errorHandler: { _ in
            completion(false)
        })
    }

    /// 遅延配送（到達不可・バックグラウンドでもOK：重複排除はiPhone側で）
    private func sendDeferred(_ items: [FlagItem]) {
        guard let s = session else { return }
        let userInfo: [String: Any] = [
            "type": "flags_batch",
            "flags": items.map { ["id": $0.id.uuidString, "ts": $0.timestamp] }
        ]
        s.transferUserInfo(userInfo)
    }

    // MARK: - バッファ（UserDefaults）

    private func enqueue(items: [FlagItem]) {
        var set = Set(pendingFlags)
        items.forEach { set.insert($0) }
        pendingFlags = Array(set).sorted(by: { $0.timestamp < $1.timestamp })
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
        // 起動直後にも一応フラッシュを試す（到達可なら即時、不可でも遅延投入）
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.flushPending()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if session.isReachable {
                // 再接続時は即フラッシュ
                self.flushPending()
            }
        }
    }
}
