import Foundation

actor AnalysisManager {
    private var analysisFrames: [AnalysisFrame] = []
    private(set) var inFlightRequests: Set<String> = []

    func trackNewRequest(id: String) {
        inFlightRequests.insert(id)
    }

    func add(result: DetectionResult, timestamp: TimeInterval) {
        if inFlightRequests.contains(result.request_id) {
            inFlightRequests.remove(result.request_id)
            let frame = AnalysisFrame(videoTimestamp: timestamp, result: result)
            analysisFrames.append(frame)
        }
    }

    func finishAndGetData() async -> [AnalysisFrame] {
        while !inFlightRequests.isEmpty {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒待機
        }
        return analysisFrames.sorted { $0.videoTimestamp < $1.videoTimestamp }
    }
    
    func reset() {
        analysisFrames.removeAll()
        inFlightRequests.removeAll()
    }
}
