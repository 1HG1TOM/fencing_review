import SwiftUI
import AVFoundation

@MainActor
class CameraManager: ObservableObject {
    
    enum UIState {
        case enteringMatchName
        case tappingPoints
        case readyToRecord
        case recording
        case saving
    }
    
    @Published var uiState: UIState = .enteringMatchName
    @Published var isSessionRunning = false
    @Published var errorMessage: String?
    
    @Published var matchName = ""
    @Published var points: [CGPoint] = []
    @Published var resultText = "試合名を入力してください。"
    @Published var remainingRequests = 0
    @Published var flagTimestamps: [TimeInterval] = []

    private let analysisManager = AnalysisManager()
    private var recordingStartTime: Date?
    private var statusTimer: Timer?
    private var lastSentTime = Date(timeIntervalSince1970: 0)
    
    private let apiURL = URL(string: "https://nkmr-lab-share-galleria.tail4dcf3.ts.net/detect-players")
    
    var cameraViewController: CameraViewController?

    // WatchConnectivityでのフラグ受信を設定
    init() {
        WatchConnectivityManageriPhone.shared.onFlagReceived = { [weak self] absoluteTime in
            guard let self = self,
                  let start = self.recordingStartTime else { return }
            let relativeTime = absoluteTime - start.timeIntervalSince1970
            Task { @MainActor in
                self.flagTimestamps.append(relativeTime)
                print("フラグ追加: \(relativeTime)秒")
            }
        }
    }

    func submitMatchName() {
        guard !self.matchName.isEmpty else {
            self.resultText = "試合名を入力してください。"
            return
        }
        self.uiState = .tappingPoints
        self.resultText = "ピストの4点をタップしてください (0/4)"
    }
    
    func handleTap(location: CGPoint) {
        guard self.uiState == .tappingPoints && self.points.count < 4 else { return }
        
        self.points.append(location)
        self.resultText = "ピストの4点をタップしてください (\(self.points.count)/4)"
        
        if self.points.count == 4 {
            self.uiState = .readyToRecord
            self.resultText = "録画開始の準備ができました。"
        }
    }

    func startRecordingAndAnalysis() {
        guard self.uiState == .readyToRecord, let vc = self.cameraViewController else { return }

        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    do {
                        try vc.startRecording()
                        self.recordingStartTime = Date()
                        Task { await self.analysisManager.reset() }
                        self.flagTimestamps.removeAll()
                        self.uiState = .recording
                        self.resultText = "分析中..."
                        WatchConnectivityManageriPhone.shared.sendRecordingStateToWatch(true)
                    } catch {
                        self.errorMessage = "録画の開始に失敗しました: \(error.localizedDescription)"
                    }
                } else {
                    self.errorMessage = "カメラの使用が許可されていません。"
                }
            }
        }
    }

    
    func stopRecordingAndAnalysis() {
        guard self.uiState == .recording else { return }
        
        self.uiState = .saving
        
        self.statusTimer?.invalidate()
        self.statusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task {
                let count = await self.analysisManager.inFlightRequests.count
                await MainActor.run { self.remainingRequests = count }
            }
        }
        
        Task {
            async let videoURLTask = self.cameraViewController?.stopRecording()
            async let analysisFramesTask = self.analysisManager.finishAndGetData()
            
            let (tempURL, analysisFrames) = await (videoURLTask, analysisFramesTask)
            
            self.statusTimer?.invalidate()

            if let url = tempURL {
                await self.finalizeAndSaveSession(videoTempURL: url, analysisFrames: analysisFrames)
            } else {
                self.errorMessage = "動画ファイルの取得に失敗しました。"
                self.resetToIdle()
            }
        }
    }
    
    private func finalizeAndSaveSession(videoTempURL: URL, analysisFrames: [AnalysisFrame]) async {
        var newSession = RecordingSession(id: UUID(), creationDate: Date(), matchName: self.matchName)
        
        do {
            let videoAssetID = try await MediaSaver.saveVideoToPhotoLibrary(from: videoTempURL)
            newSession.videoAssetID = videoAssetID
            
            let flagFilename = try DataSaver.saveFlagTimestamps(times: self.flagTimestamps, sessionID: newSession.id)
            newSession.flagDataFilename = flagFilename

            let analysisFilename = try DataSaver.saveAnalysisData(frames: analysisFrames, sessionID: newSession.id)
            newSession.analysisDataFilename = analysisFilename


            print("フラグファイル保存済み: \(flagFilename)")
            
            SessionStore.save(session: newSession)
            self.resultText = "「\(self.matchName)」の保存が完了しました。"
        } catch {
            self.errorMessage = "保存中にエラーが発生しました: \(error.localizedDescription)"
        }
        
        self.resetToIdle()
    }
    
    private func resetToIdle() {
        self.uiState = .enteringMatchName
        self.matchName = ""
        self.points = []
        self.flagTimestamps = []
        if self.resultText.contains("保存が完了") == false {
             self.resultText = "試合名を入力してください。"
        }
        WatchConnectivityManageriPhone.shared.sendRecordingStateToWatch(false)
    }
    
    func onFrameCaptured(sampleBuffer: CMSampleBuffer) {
        guard self.uiState == .recording, self.points.count == 4 else { return }

        let now = Date()
        if now.timeIntervalSince(self.lastSentTime) > 0.5 {
            self.lastSentTime = now
            Task {
                await self.sendFrameForAnalysis(sampleBuffer)
            }
        }
    }
    
    private nonisolated func sendFrameForAnalysis(_ sampleBuffer: CMSampleBuffer) async {
        guard let url = await self.apiURL,
              let startTime = await self.recordingStartTime,
              let vc = await self.cameraViewController,
              let previewLayer = vc.previewLayer,
              let image = UIImage(sampleBuffer: sampleBuffer) else { return }

        let videoTimestamp = Date().timeIntervalSince(startTime)
        let requestId = UUID().uuidString
        await self.analysisManager.trackNewRequest(id: requestId)

        var normalizedPointsForAPI: [CGFloat] = []
        for pt in await self.points {
            let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: pt)
            normalizedPointsForAPI.append(devicePoint.x)
            normalizedPointsForAPI.append(devicePoint.y)
        }
        
        let resizedImage = self.resizeImage(image)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"frame.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        if let pointsData = try? JSONEncoder().encode(normalizedPointsForAPI), let pointsString = String(data: pointsData, encoding: .utf8) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"original_points\"\r\n\r\n")
            body.append(pointsString)
            body.append("\r\n")
        }
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"request_id\"\r\n\r\n")
        body.append(requestId)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")

        do {
            let (data, _) = try await URLSession.shared.upload(for: request, from: body)
            if let decoded = try? JSONDecoder().decode(DetectionResult.self, from: data) {
                await self.analysisManager.add(result: decoded, timestamp: videoTimestamp)
                
                await MainActor.run {
                    if decoded.people == 2, let left = decoded.left, let right = decoded.right {
                        self.resultText = "検出人数: \(decoded.people)\n左: (\(left.x), \(left.y))\n右: (\(right.x), \(right.y))"
                    } else {
                        self.resultText = "検出人数: \(decoded.people)人"
                    }
                }
            }
        } catch {
            print("送信エラー: \(error.localizedDescription)")
        }
    }
    
    private nonisolated func resizeImage(_ image: UIImage, maxWidth: CGFloat = 640) -> UIImage {
        if image.size.width <= maxWidth { return image }
        let scale = maxWidth / image.size.width
        let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - 拡張

extension UIImage {
    convenience init?(sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        self.init(cgImage: cgImage)
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

extension DataSaver {
    static func saveFlagTimestamps(times: [TimeInterval], sessionID: UUID) throws -> String {
        let wrapped = times.map { ["flagTime": $0] }
        let data = try JSONSerialization.data(withJSONObject: wrapped, options: .prettyPrinted)
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "flags-\(sessionID.uuidString).json"
        let fileURL = documentsDirectory.appendingPathComponent("flags-\(sessionID.uuidString).json")
        try data.write(to: fileURL)
        return fileName
    }
}

