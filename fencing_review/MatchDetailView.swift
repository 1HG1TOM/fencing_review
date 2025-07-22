import AVKit
import Photos
import Charts

struct PositionDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Double
    let targetX: Double?
    let targetY: Double?
    let opponentX: Double?
    let opponentY: Double?
    let people: Int
}

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
    @State private var chartWidth: CGFloat = 0
    @State private var timer: Timer?
    @State private var isDraggingSlider: Bool = false
    @State private var selectedSetIndex: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("セット", selection: $selectedSetIndex) {
                    ForEach(splitSets.indices, id: \.self) { i in
                        Text("\(i + 1)").tag(i)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedSetIndex) { newValue in
                    if newValue < splitSets.count {
                        self.positionData = splitSets[newValue]
                    }
                }

                if !positionData.isEmpty {
                    let start = positionData.first?.timestamp ?? 0
                    let end = positionData.last?.timestamp ?? start
                    let duration = end - start

                    DualLineGraph(
                        data: positionData,
                        flagTimestamps: flagTimestamps,
                        onTapTime: { tappedTime in
                            seekToTime(tappedTime)
                        },
                        chartWidth: $chartWidth,
                        currentTime: currentTime,
                        videoDuration: duration,
                        xAxisStart: start
                    )

                    VStack(spacing: 4) {
                        ZStack(alignment: .leading) {
                            GeometryReader { geo in
                                let width = chartWidth > 0 ? chartWidth : geo.size.width
                                ForEach(flagTimestamps, id: \.self) { flag in
                                    let xPos = CGFloat((flag - start) / (end - start)) * width
                                    if flag >= start && flag <= end {
                                        Rectangle()
                                            .fill(Color.yellow)
                                            .frame(width: 2, height: 20)
                                            .position(x: xPos, y: 10)
                                    }
                                }

                                Slider(value: $currentTime, in: start...end, onEditingChanged: { editing in
                                    isDraggingSlider = editing
                                    if !editing {
                                        seekToTime(currentTime)
                                    }
                                })
                                .frame(width: width)
                            }
                            .frame(height: 20)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Text("分析データを読み込み中...")
                }

                if let player = player {
                    if let size = videoSize {
                        let aspectRatio = size.width / size.height
                        AVPlayerContainerView(player: player)
                            .aspectRatio(aspectRatio, contentMode: .fit)
                            .onAppear { player.play()}
                    }
                } else {
                    Text("動画を読み込み中...")
                }
            }
            .padding()
        }
        .navigationTitle(session.matchName)
        .onAppear {
            loadGraphData()
            loadFlagData()
            loadVideo()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

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

    private func seekToTime(_ seconds: Double) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func loadFlagData() {
        guard let filename = session.flagDataFilename else { return }
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        if let data = try? Data(contentsOf: fileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            self.flagTimestamps = json.compactMap { $0["flagTime"] as? Double }
        }
    }

    private func loadGraphData() {
        guard let filename = session.analysisDataFilename else { return }
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        if let data = try? Data(contentsOf: fileURL),
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
                        targetX: leftX,
                        targetY: leftY,
                        opponentX: rightX,
                        opponentY: rightY,
                        people: peopleCount
                    ))

                } else {
                    points.append(PositionDataPoint(
                        timestamp: timestamp,
                        targetX: nil,
                        targetY: nil,
                        opponentX: nil,
                        opponentY: nil,
                        people: peopleCount
                    ))
                }
            }

            self.fullPositionData = points
            self.splitSets = splitIntoSets(from: points, gapThreshold: 10.0, minDuration: 90.0)
            self.selectedSetIndex = 0
            self.positionData = splitSets.first ?? []
        }
    }

    private func loadVideo() {
        guard let assetID = session.videoAssetID else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = assets.firstObject else { return }

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

    private func splitIntoSets(from data: [PositionDataPoint], gapThreshold: Double = 30.0, minDuration: Double = 90.0) -> [[PositionDataPoint]] {
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

        if !currentSet.isEmpty {
            rawSets.append(currentSet)
        }

        // 90秒未満のセットを前にくっつける
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
}



import SwiftUI
import Charts

struct DualLineGraph: View {
    let data: [PositionDataPoint]
    let flagTimestamps: [Double]
    let onTapTime: (Double) -> Void
    @State private var chartSize: CGSize = .zero
    @Binding var chartWidth: CGFloat
    let currentTime: Double
    let videoDuration: Double
    let xAxisStart: Double

    struct LinePoint: Hashable {
        var timestamp: Double
        var value: Double
    }

    var body: some View {
        ZStack {
            Chart {
                // 分割した Target の折れ線を描画
                ForEach(splitSeries(data: data, for: \.targetX), id: \.self) { segment in
                    if segment.count > 1 {
                        let segmentID = UUID().uuidString
                        ForEach(segment, id: \.self) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("X Position", point.value),
                                series: .value("Player", "Target \(segmentID)")
                            )
                            .foregroundStyle(.red)
                        }
                    }
                }


                // 分割した Opponent の折れ線を描画
                ForEach(splitSeries(data: data, for: \.opponentX), id: \.self) { segment in
                    if segment.count > 1 {
                        let segmentID = UUID().uuidString
                        ForEach(segment, id: \.self) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("X Position", point.value),
                                series: .value("Player", "Opponent \(segmentID)")
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                }


                // フラグ線
                ForEach(flagTimestamps, id: \.self) { ts in
                    RuleMark(x: .value("Flag", ts))
                        .foregroundStyle(Color.yellow)
                        .lineStyle(StrokeStyle(lineWidth: 3, dash: [4]))
                }

                // 現在位置線
                RuleMark(x: .value("CurrentTime", currentTime))
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }

            
            .chartXAxisLabel("Time (s)")
            .chartYScale(domain: -800...800)
            .chartYAxis(.hidden)
            .chartXScale(domain: xAxisStart...(xAxisStart + videoDuration))
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        self.chartSize = geo.size
                        self.chartWidth = geo.size.width
                    }
                }
            )

            // タップ検出領域
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let tapX = value.location.x
                            let ratio = max(0, min(tapX / chartSize.width, 1))
                            let tappedTime = xAxisStart + ratio * videoDuration
                            onTapTime(tappedTime)
                        }
                )
        }
        .frame(height: 200)
        .padding()
    }

    private func splitSeries(data: [PositionDataPoint], for keyPath: KeyPath<PositionDataPoint, Double?>) -> [[LinePoint]] {
        var result: [[LinePoint]] = []
        var current: [LinePoint] = []

        for point in data {
            if point.people == 2, let value = point[keyPath: keyPath] {
                current.append(LinePoint(timestamp: point.timestamp, value: value))
            } else {
                if !current.isEmpty {
                    result.append(current)
                    current = []
                }
            }
        }

        if !current.isEmpty {
            result.append(current)
        }

        print("分割セグメント数: \(result.count)")
        for (index, segment) in result.enumerated() {
            print("Segment \(index): \(segment.count) points")
        }

        return result
    }

}
