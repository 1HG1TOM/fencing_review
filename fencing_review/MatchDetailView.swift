import AVKit
import Photos
import Charts
import SwiftUI

// ------------------- データ構造 -------------------

struct PositionDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Double
    let targetX: Double?
    let targetY: Double?
    let opponentX: Double?
    let opponentY: Double?
    let people: Int
}

// ------------------- MatchDetailView -------------------

struct MatchDetailView: View {
    let session: RecordingSession
    @State private var player: AVPlayer?
    @State private var videoSize: CGSize? = nil
    @State private var fullPositionData: [PositionDataPoint] = []
    @State private var splitSets: [[PositionDataPoint]] = []
    @State private var positionData: [PositionDataPoint] = []
    @State private var flagTimestamps: [Double] = []
    @State private var currentTime: Double = 0
    @State private var videoDuration: Double = 0
    @State private var timer: Timer?
    @State private var isDraggingSlider: Bool = false

    @State private var timeControlStatusObs: NSKeyValueObservation?
    @State private var timeJumpObserver: NSObjectProtocol?
    @State private var didPlayToEndObserver: NSObjectProtocol?

    @State private var selectedSetIndex: Int = 0 {
        didSet {
            if splitSets.indices.contains(selectedSetIndex) {
                positionData = splitSets[selectedSetIndex]
                recomputeScoreLabels()
            }
        }
    }

    @State private var gfSeconds: [Double] = []
    @State private var gaSeconds: [Double] = []
    @State private var gdSeconds: [Double] = []
    @State private var offsetSeconds: Double = 0
    @State private var videoStartAt: Date? = nil
    @State private var scoreLabels: [ScoreLabelMark] = []
    @State private var isPlayerInitializing: Bool = true
    private let initQuietPeriod: TimeInterval = 0.5
    private let tinyJumpThreshold: Double = 0.5
    
    @Environment(\.dismiss) private var dismiss
    
    // 画面の向きを追跡（変化ではなく現在の状態）
    @State private var currentOrientation: String = "unknown"
    @State private var isFirstOrientationCheck: Bool = true

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            VStack(spacing: 0) {
                // --- セット選択ピッカー ---
                setPickerSection
                
                // --- フラグ数表示 ---
                flagCountSection
                
                // --- メイン領域 ---
                if isLandscape {
                    landscapeLayout(geometry: geometry)
                } else {
                    portraitLayout(geometry: geometry)
                }
            }
            .onChange(of: geometry.size) { newSize in
                updateOrientationIfNeeded(newSize)
            }
        }
        .navigationTitle(session.matchName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbarRole(.navigationStack)
        .onAppear(perform: onAppearHandler)
        .onDisappear(perform: onDisappearHandler)
    }
    
    // ------------------- サブビュー -------------------
    
    private var setPickerSection: some View {
        Picker("セット", selection: $selectedSetIndex) {
            ForEach(splitSets.indices, id: \.self) { i in
                Text("\(i + 1)").tag(i)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(8)
        .onChange(of: selectedSetIndex) { newIndex in
            handleSetChange(newIndex)
        }
    }
    
    private var flagCountSection: some View {
        HStack {
            ForEach(splitSets.indices, id: \.self) { i in
                flagCountText(for: i)
            }
        }
        .padding(.horizontal)
    }
    
    private func flagCountText(for index: Int) -> some View {
        let start = splitSets[index].first?.timestamp ?? 0
        let end = splitSets[index].last?.timestamp ?? 0
        let count = flagTimestamps.filter { $0 >= start && $0 <= end }.count
        
        return Text("\(count)個")
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
    }
    
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: 8) {
            videoPlayerView(width: geometry.size.width * 0.6)
            
            if !positionData.isEmpty {
                graphAndSliderView(
                    width: geometry.size.width * 0.28,
                    height: geometry.size.height * 0.8,
                    labelsOnLeft: false
                )
            } else {
                loadingTextView(width: geometry.size.width * 0.3)
            }
        }
        .padding()
    }
    
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                if let player = player, let size = videoSize {
                    let aspectRatio = size.width / size.height
                    AVPlayerContainerView(
                        player: player,
                        onFullscreenChange: handleFullscreenChange
                    )
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .onAppear { player.play() }
                } else {
                    Text("動画を読み込み中...")
                }
                
                if !positionData.isEmpty {
                    let horizontalPadding: CGFloat = 16
                    let targetWidth = geometry.size.width - horizontalPadding * 2
                    let targetHeight = geometry.size.height * 0.6
                    
                    sliderAndGraphView(
                        width: targetWidth,
                        height: targetHeight
                    )
                } else {
                    Text("分析データを読み込み中...")
                }
            }
        }
    }
    
    private func videoPlayerView(width: CGFloat) -> some View {
        Group {
            if let player = player, let size = videoSize {
                let aspectRatio = size.width / size.height
                AVPlayerContainerView(
                    player: player,
                    onFullscreenChange: handleFullscreenChange
                )
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(width: width)
            } else {
                Text("動画を読み込み中...")
                    .frame(width: width)
            }
        }
    }
    
    private func loadingTextView(width: CGFloat) -> some View {
        Text("分析データを読み込み中...")
            .frame(width: width)
    }
    
    private func graphAndSliderView(width: CGFloat, height: CGFloat, labelsOnLeft: Bool) -> some View {
        let start = positionData.first?.timestamp ?? 0
        let end = positionData.last?.timestamp ?? start
        let duration = end - start
        
        return HStack(spacing: 8) {
            DualLineGraph(
                data: positionData,
                flagTimestamps: flagTimestamps,
                gfSeconds: gfSeconds,
                gaSeconds: gaSeconds,
                gdSeconds: gdSeconds,
                onTapTime: { seekToTime($0, via: "graph_tap") },
                chartHeight: .constant(height),
                currentTime: $currentTime,
                videoDuration: duration,
                xAxisStart: start
            )
            
            VerticalSlider(
                value: $currentTime,
                range: start...end,
                flags: flagTimestamps,
                scoresGF: gfSeconds,
                scoresGA: gaSeconds,
                scoresGD: gdSeconds,
                labels: scoreLabels,
                height: height,
                labelsOnLeft: labelsOnLeft,
                isEditing: $isDraggingSlider,
                onEnded: { seekToTime($0, via: "slider_drag") }
            )
            .id("slider-right")
        }
        .frame(width: width, height: height)
        .clipped()
    }
    
    private func sliderAndGraphView(width: CGFloat, height: CGFloat) -> some View {
        let start = positionData.first?.timestamp ?? 0
        let end = positionData.last?.timestamp ?? start
        let duration = end - start
        
        return HStack(alignment: .top, spacing: 8) {
            VerticalSlider(
                value: $currentTime,
                range: start...end,
                flags: flagTimestamps,
                scoresGF: gfSeconds,
                scoresGA: gaSeconds,
                scoresGD: gdSeconds,
                labels: scoreLabels,
                height: height,
                labelsOnLeft: true,
                isEditing: $isDraggingSlider,
                onEnded: { seekToTime($0, via: "slider_drag") }
            )
            .id("slider-left")
            
            DualLineGraph(
                data: positionData,
                flagTimestamps: flagTimestamps,
                gfSeconds: gfSeconds,
                gaSeconds: gaSeconds,
                gdSeconds: gdSeconds,
                onTapTime: { seekToTime($0, via: "graph_tap") },
                chartHeight: .constant(height),
                currentTime: $currentTime,
                videoDuration: duration,
                xAxisStart: start
            )
            .frame(maxWidth: .infinity)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    // ------------------- イベントハンドラー -------------------
    
    private func handleSetChange(_ newIndex: Int) {
        if splitSets.indices.contains(newIndex) {
            positionData = splitSets[newIndex]
            if let firstTimestamp = splitSets[newIndex].first?.timestamp {
                seekToTime(firstTimestamp, via: "set_change")
            }
            recomputeScoreLabels()
        }
    }
    
    private func updateOrientationIfNeeded(_ size: CGSize) {
        let newOrientation = size.width > size.height ? "landscape" : "portrait"
        
        // 初回はログを記録せず、状態だけ更新（画面回転の強制による誤検知を防ぐ）
        if isFirstOrientationCheck {
            isFirstOrientationCheck = false
            currentOrientation = newOrientation
            return
        }
        
        // 向きが実際に変わった時だけログを記録
        if currentOrientation != newOrientation {
            currentOrientation = newOrientation
            Logger.shared.log(event: "device_orientation", [
                "orientation": newOrientation
            ])
        }
    }
    
    private func handleFullscreenChange(_ isFullscreen: Bool) {
        let currentPosition = player?.currentTime().seconds ?? 0
        Logger.shared.log(event: "fullscreen", [
            "state": isFullscreen ? "enter" : "exit",
            "position": currentPosition
        ])
    }
    
    private func onAppearHandler() {
        // 初期の向きを設定（ログは記録しない）
        OrientationManager.setLandscapeRight()
        
        Logger.shared.log(event: "start_review", [
            "match": session.matchName,
            "videoID": session.videoAssetID ?? "nil"
        ])
        
        isPlayerInitializing = true
        loadGraphData()
        loadFlagData()
        loadVideo()
        startTimer()
    }
    
    private func onDisappearHandler() {
        // 画面回転の強制をやめる（ユーザーの操作を妨げない）
        // OrientationManager.setPortrait() // ← コメントアウト
        
        stopTimer()
        timeControlStatusObs?.invalidate()
        timeControlStatusObs = nil
        if let obs = timeJumpObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = didPlayToEndObserver { NotificationCenter.default.removeObserver(obs) }
        timeJumpObserver = nil
        didPlayToEndObserver = nil
        Logger.shared.log(event: "end_review")
    }

    // ------------------- タイマー制御 -------------------

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard !isDraggingSlider, let currentItem = player?.currentItem else { return }
            let time = currentItem.currentTime().seconds
            if !time.isNaN { self.currentTime = time }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func seekToTime(_ seconds: Double, via: String = "unknown") {
        guard let player = player else { return }
        let from = player.currentTime().seconds
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        Logger.shared.log(event: "seek", ["from": from, "to": seconds, "via": via])
    }

    // ------------------- データ読み込み -------------------

    private func loadFlagData() {
        guard let filename = session.flagDataFilename else { return }
        let url = folderURL(for: session.matchName).appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            self.flagTimestamps = json.compactMap { $0["flagTime"] as? Double }
        }
    }

    private func loadGraphData() {
        guard let filename = session.analysisDataFilename else { return }
        let url = folderURL(for: session.matchName).appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url),
           let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var points: [PositionDataPoint] = []
            for dict in jsonArray {
                guard let timestamp = dict["videoTimestamp"] as? Double,
                      let result = dict["result"] as? [String: Any] else { continue }
                let peopleCount = result["people"] as? Int ?? 0
                if peopleCount == 2,
                   let left = result["left"] as? [String: Any],
                   let right = result["right"] as? [String: Any],
                   let leftX = left["x"] as? Double,
                   let leftY = left["y"] as? Double,
                   let rightX = right["x"] as? Double,
                   let rightY = right["y"] as? Double {
                    points.append(PositionDataPoint(
                        timestamp: timestamp,
                        targetX: leftX, targetY: leftY,
                        opponentX: rightX, opponentY: rightY,
                        people: peopleCount
                    ))
                } else {
                    points.append(PositionDataPoint(
                        timestamp: timestamp,
                        targetX: nil, targetY: nil,
                        opponentX: nil, opponentY: nil,
                        people: peopleCount
                    ))
                }
            }
            DispatchQueue.main.async {
                self.fullPositionData = points
            }
        }
    }

    private func loadVideo() {
        guard let assetID = session.videoAssetID else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = assets.firstObject else { return }

        let anchor = asset.creationDate ?? session.creationDate
        DispatchQueue.main.async {
            self.videoStartAt = anchor
            self.loadScoringMarks()
        }

        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let avAsset = avAsset,
               let track = avAsset.tracks(withMediaType: .video).first {
                let size = track.naturalSize.applying(track.preferredTransform)
                let durationSeconds = avAsset.duration.seconds
                DispatchQueue.main.async {
                    self.videoSize = CGSize(width: abs(size.width), height: abs(size.height))
                    self.player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                    self.videoDuration = durationSeconds
                }
            }
        }
    }

    private func loadScoringMarks() {
        guard let anchor = videoStartAt else { return }
        let scoreFileName = "scores-\(session.id.uuidString).json"
        let scoreFileURL = folderURL(for: session.matchName).appendingPathComponent(scoreFileName)

        do {
            if FileManager.default.fileExists(atPath: scoreFileURL.path) {
                let marks = try ScoringMapper.loadSeconds(
                    sessionID: session.id,
                    videoName: session.matchName,
                    videoStartAt: anchor,
                    duration: videoDuration == 0 ? nil : videoDuration,
                    offset: offsetSeconds
                )
                self.gfSeconds = marks.gf
                self.gaSeconds = marks.ga
                self.gdSeconds = marks.gd
                self.splitSets = splitBySetBoundaries(from: fullPositionData, boundaries: marks.sets)
            } else {
                self.splitSets = splitIntoSets(from: fullPositionData, gapThreshold: 10.0, minDuration: 90.0)
            }

            self.selectedSetIndex = 0
            self.positionData = splitSets.first ?? []
            self.recomputeScoreLabels()

        } catch {
            print("得失点読み込み失敗: \(error.localizedDescription)")
            self.gfSeconds = []
            self.gaSeconds = []
            self.gdSeconds = []
            self.splitSets = [fullPositionData]
        }
    }

    // ------------------- セット分割 -------------------

    private func splitBySetBoundaries(from data: [PositionDataPoint], boundaries: [Double]) -> [[PositionDataPoint]] {
        var sets: [[PositionDataPoint]] = []
        var current: [PositionDataPoint] = []
        var boundaryIndex = 0

        for point in data {
            while boundaryIndex < boundaries.count,
                  point.timestamp >= boundaries[boundaryIndex] {
                if !current.isEmpty {
                    sets.append(current)
                    current = []
                }
                boundaryIndex += 1
            }
            current.append(point)
        }

        if !current.isEmpty {
            sets.append(current)
        }
        return sets
    }

    private func splitIntoSets(
        from data: [PositionDataPoint],
        gapThreshold: Double = 30.0,
        minDuration: Double = 90.0
    ) -> [[PositionDataPoint]] {
        var rawSets: [[PositionDataPoint]] = []
        var currentSet: [PositionDataPoint] = []
        var lastValidTime: Double? = nil

        for point in data {
            if point.people == 2 {
                if let last = lastValidTime {
                    let gap = point.timestamp - last
                    if gap > gapThreshold {
                        if !currentSet.isEmpty {
                            rawSets.append(currentSet)
                            currentSet = []
                        }
                    }
                }
                lastValidTime = point.timestamp
            }
            currentSet.append(point)
        }
        if !currentSet.isEmpty { rawSets.append(currentSet) }

        var mergedSets: [[PositionDataPoint]] = []
        for set in rawSets {
            if set.count < 2 {
                if !mergedSets.isEmpty {
                    mergedSets[mergedSets.count - 1].append(contentsOf: set)
                } else {
                    mergedSets.append(set)
                }
                continue
            }
            let start = set.first!.timestamp
            let end = set.last!.timestamp
            let duration = end - start
            if duration < minDuration, !mergedSets.isEmpty {
                mergedSets[mergedSets.count - 1].append(contentsOf: set)
            } else {
                mergedSets.append(set)
            }
        }
        return mergedSets
    }

    // ------------------- スコアラベル -------------------

    private func recomputeScoreLabels() {
        guard let setStart = positionData.first?.timestamp,
              let setEnd   = positionData.last?.timestamp else {
            scoreLabels = []
            return
        }
        let allGF = gfSeconds
        let allGA = gaSeconds
        let allGD = gdSeconds

        var gf = allGF.filter { $0 < setStart }.count +
                 allGD.filter { $0 < setStart }.count
        var ga = allGA.filter { $0 < setStart }.count +
                 allGD.filter { $0 < setStart }.count

        var events: [(time: Double, type: String)] = []
        events.append(contentsOf: gfSeconds.filter { $0 >= setStart && $0 <= setEnd }.map { ($0, "GF") })
        events.append(contentsOf: gaSeconds.filter { $0 >= setStart && $0 <= setEnd }.map { ($0, "GA") })
        events.append(contentsOf: gdSeconds.filter { $0 >= setStart && $0 <= setEnd }.map { ($0, "GD") })
        events.sort { $0.time < $1.time }

        var labels: [ScoreLabelMark] = []
        for e in events {
            switch e.type {
            case "GF": gf += 1
            case "GA": ga += 1
            case "GD":
                gf += 1; ga += 1
            default: break
            }
            labels.append(ScoreLabelMark(time: e.time, text: "\(gf)-\(ga)"))
        }
        scoreLabels = labels
    }
}
