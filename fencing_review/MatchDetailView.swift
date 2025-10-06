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


    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            // すべてを1つのVStackにまとめる（←重要）
            VStack(spacing: 0) {

                // --- セット選択ピッカー ---
                Picker("セット", selection: $selectedSetIndex) {
                    ForEach(splitSets.indices, id: \.self) { i in
                        Text("\(i + 1)").tag(i)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(8)
                .onChange(of: selectedSetIndex) { newIndex in
                    if splitSets.indices.contains(newIndex) {
                        positionData = splitSets[newIndex]
                        if let firstTimestamp = splitSets[newIndex].first?.timestamp {
                            seekToTime(firstTimestamp, via: "set_change")
                        }
                        recomputeScoreLabels()
                    }
                }

                // --- ピッカー直下にセットごとのフラグ数 ---
                HStack {
                    ForEach(splitSets.indices, id: \.self) { i in
                        let start = splitSets[i].first?.timestamp ?? 0
                        let end   = splitSets[i].last?.timestamp  ?? 0
                        let count = flagTimestamps.filter { $0 >= start && $0 <= end }.count

                        Text("\(count)個")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                // --- メイン領域（横/縦で切替） ---
                if isLandscape {
                    // 横画面レイアウト
                    HStack(alignment: .center, spacing: 8) {
                        if let player = player, let size = videoSize {
                            let aspectRatio = size.width / size.height
                            AVPlayerContainerView(player: player, onFullscreenChange: { _ in })
                                .aspectRatio(aspectRatio, contentMode: .fit)
                                .frame(width: geometry.size.width * 0.6)
                        } else {
                            Text("動画を読み込み中...")
                                .frame(width: geometry.size.width * 0.6)
                        }

                        if !positionData.isEmpty {
                            let start = positionData.first?.timestamp ?? 0
                            let end = positionData.last?.timestamp ?? start
                            let duration = end - start
                            let targetHeight = geometry.size.height * 0.8

                            HStack(spacing: 8) {
                                DualLineGraph(
                                    data: positionData,
                                    flagTimestamps: flagTimestamps,
                                    gfSeconds: gfSeconds,
                                    gaSeconds: gaSeconds,
                                    gdSeconds: gdSeconds,
                                    onTapTime: { seekToTime($0, via: "graph_tap") },
                                    chartHeight: .constant(targetHeight),
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
                                    height: targetHeight,
                                    labelsOnLeft: false,
                                    isEditing: $isDraggingSlider,
                                    onEnded: { seekToTime($0, via: "slider_drag") }
                                )
                                .id("slider-right")
                            }
                            .frame(width: geometry.size.width * 0.28, height: targetHeight)
                            .clipped()
                        } else {
                            Text("分析データを読み込み中...")
                                .frame(width: geometry.size.width * 0.3)
                        }
                    }
                    .padding()
                } else {
                    // 縦画面レイアウト
                    ScrollView {
                        VStack(spacing: 8) {
                            if let player = player, let size = videoSize {
                                let aspectRatio = size.width / size.height
                                AVPlayerContainerView(player: player, onFullscreenChange: { _ in })
                                    .aspectRatio(aspectRatio, contentMode: .fit)
                                    .onAppear { player.play() }
                            } else {
                                Text("動画を読み込み中...")
                            }

                            if !positionData.isEmpty {
                                let start = positionData.first?.timestamp ?? 0
                                let end = positionData.last?.timestamp ?? start
                                let duration = end - start
                                let horizontalPadding: CGFloat = 16
                                let targetWidth = geometry.size.width - horizontalPadding * 2
                                let targetHeight = geometry.size.height * 0.6

                                HStack(alignment: .top, spacing: 8) {
                                    VerticalSlider(
                                        value: $currentTime,
                                        range: start...end,
                                        flags: flagTimestamps,
                                        scoresGF: gfSeconds,
                                        scoresGA: gaSeconds,
                                        scoresGD: gdSeconds,
                                        labels: scoreLabels,
                                        height: targetHeight,
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
                                        chartHeight: .constant(targetHeight),
                                        currentTime: $currentTime,
                                        videoDuration: duration,
                                        xAxisStart: start
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .frame(width: targetWidth, height: targetHeight)
                                .clipped()
                            } else {
                                Text("分析データを読み込み中...")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(session.matchName)
        .navigationTitle(session.matchName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)   // ← 自作ナビゲーションを削除して標準に戻す
        .toolbarRole(.navigationStack)
        .onAppear {
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
        .onDisappear {
            stopTimer()
            timeControlStatusObs?.invalidate()
            timeControlStatusObs = nil
            if let obs = timeJumpObserver { NotificationCenter.default.removeObserver(obs) }
            if let obs = didPlayToEndObserver { NotificationCenter.default.removeObserver(obs) }
            timeJumpObserver = nil
            didPlayToEndObserver = nil
            Logger.shared.log(event: "end_review")
        }
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
            self.loadScoringMarks()   // videoStartAt を確定させてから
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

        print("[Debug] loadScoringMarks called")

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

        print("[Debug] splitSets.count = \(splitSets.count)")
        splitSets.enumerated().forEach { i, set in
            print("  Set \(i): \(set.first?.timestamp ?? -1) 〜 \(set.last?.timestamp ?? -1)  (\(set.count) points)")
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
