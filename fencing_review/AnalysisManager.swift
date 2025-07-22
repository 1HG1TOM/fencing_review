import Foundation

actor AnalysisManager {
    private var frames: [AnalysisFrame] = []
    private var inFlightRequests: Set<String> = []

    func getInFlightRequestCount() -> Int {
        return inFlightRequests.count
    }

    func add(result: DetectionResult, timestamp: TimeInterval, requestID: String) {
        let frame = AnalysisFrame(videoTimestamp: timestamp, result: result)
        if inFlightRequests.contains(requestID) {
            frames.append(frame)
            inFlightRequests.remove(requestID)
        } else {
            print("未登録の requestID: \(requestID) に対して結果を受信しました")
        }
    }

    func trackNewRequest(id: String) {
        inFlightRequests.insert(id)
    }

    func completeRequest(id: String) {
        inFlightRequests.remove(id)
    }

    func finishAndGetData(timeout: TimeInterval = 60.0) async -> [AnalysisFrame] {
        let startTime = Date()

        while true {
            if inFlightRequests.isEmpty { break }
            if Date().timeIntervalSince(startTime) > timeout {
                print("タイムアウト: \(inFlightRequests.count)件未完了で保存します")
                break
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        return frames
    }

    func reset() {
        frames.removeAll()
        inFlightRequests.removeAll()
    }
}
