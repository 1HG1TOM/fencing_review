import SwiftUI
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
}


struct MatchDetailView: View {
    let session: RecordingSession
    @State private var player: AVPlayer?
    @State private var graphData: [Double] = []
    @State private var videoSize: CGSize? = nil
    @State private var positionData: [PositionDataPoint] = []
    @State private var flagTimestamps: [Double] = []
    @State private var currentTime: Double = 0
    @State private var videoDuration: Double = 0
    @State private var chartWidth: CGFloat = 0
    @State private var timer: Timer?
    @State private var isDraggingSlider: Bool = false



    var graphMinTimestamp: Double {
        positionData.compactMap { $0.targetX != nil || $0.opponentX != nil ? $0.timestamp : nil }.min() ?? 0
    }

    var graphMaxTimestamp: Double {
        positionData.compactMap { $0.targetX != nil || $0.opponentX != nil ? $0.timestamp : nil }.max() ?? videoDuration
    }


    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !positionData.isEmpty {
                    DualLineGraph(
                        data: positionData,
                        flagTimestamps: flagTimestamps,
                        onTapTime: { tappedTime in
                            seekToTime(tappedTime)
                        },
                        chartWidth: $chartWidth,
                        currentTime: currentTime,
                        videoDuration: videoDuration
                    )
                } else {
                    Text("分析データを読み込み中...")
                }

                if videoDuration > 0 {
                    VStack(spacing: 4) {
                        ZStack(alignment: .leading) {
                            GeometryReader { geo in
                                let width = chartWidth > 0 ? chartWidth : geo.size.width

                                ForEach(flagTimestamps, id: \.self) { flag in
                                    let xPos = CGFloat(flag / videoDuration) * width
                                    Rectangle()
                                        .fill(Color.yellow)
                                        .frame(width: 2, height: 20)
                                        .position(x: xPos, y: 10)
                                }

                                Slider(value: $currentTime, in: 0...videoDuration, onEditingChanged: { editing in
                                    isDraggingSlider = editing
                                    if !editing {
                                        seekToTime(currentTime)  // ドラッグ完了時にジャンプ
                                    }
                                })
                                .frame(width: width)
                            }
                            .frame(height: 20)
                        }
                    }
                    .padding(.horizontal)
                }


                if let player = player {
                    if let size = videoSize {
                        let aspectRatio = size.width / size.height
                        VideoPlayer(player: player)
                            .aspectRatio(aspectRatio, contentMode: .fit)
                            .onAppear {
                                player.play()
                            }
                    } else {
                        VideoPlayer(player: player)
                            .frame(height: 200)
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
            guard !isDraggingSlider else { return }  // ← ここで防止
            if let currentItem = player?.currentItem {
                let time = currentItem.currentTime().seconds
                if !time.isNaN {
                    self.currentTime = time
                }
            }
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
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(filename)

        do {
            let data = try Data(contentsOf: fileURL)
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                self.flagTimestamps = json.compactMap { $0["flagTime"] as? Double }
            }
        } catch {
            print("フラグ読み込み失敗: \(error)")
        }
    }


    private func loadGraphData() {
        guard let filename = session.analysisDataFilename else { return }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(filename)

        do {
            let data = try Data(contentsOf: fileURL)
            let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] ?? []

            print("読み込んだJSON数: \\(jsonArray.count)")

            var points: [PositionDataPoint] = []

            for dict in jsonArray {
                guard let timestamp = dict["videoTimestamp"] as? Double,
                      let result = dict["result"] as? [String: Any] else {
                    print("videoTimestamp または result の取得に失敗")
                    continue
                }

                let peopleCount = result["people"] as? Int ?? 0
                print("timestamp: \\(timestamp), people: \\(peopleCount)")

                if peopleCount == 2 {
                    print("people == 2: データを使用")

                    guard let left = result["left"] as? [String: Any],
                          let right = result["right"] as? [String: Any],
                          let leftX = left["x"] as? Double,
                          let leftY = left["y"] as? Double,
                          let rightX = right["x"] as? Double,
                          let rightY = right["y"] as? Double else {
                        print("座標データの取得に失敗")
                        continue
                    }

                    points.append(PositionDataPoint(
                        timestamp: timestamp,
                        targetX: leftX,
                        targetY: leftY,
                        opponentX: rightX,
                        opponentY: rightY
                    ))

                } else {
                    print("people == \\(peopleCount): 無効データとして nil で追加")
                    points.append(PositionDataPoint(
                        timestamp: timestamp,
                        targetX: nil,
                        targetY: nil,
                        opponentX: nil,
                        opponentY: nil
                    ))
                }
            }

            
            print("最終的なPositionDataPoint件数: \\(points.count)")
            self.positionData = points

        } catch {
            print("グラフデータ読み込み失敗: \\(error)")
        }
    }



    private func loadVideo() {
        guard let assetID = session.videoAssetID else {
            print("videoAssetID is nil")
            return
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)

        guard let asset = assets.firstObject else {
            print("Asset not found for ID: \\(assetID)")
            return
        }

        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let avAsset = avAsset {
                if let track = avAsset.tracks(withMediaType: .video).first {
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
    }
}

struct DualLineGraph: View {
    let data: [PositionDataPoint]
    let flagTimestamps: [Double]
    let onTapTime: (Double) -> Void
    @State private var chartSize: CGSize = .zero
    @Binding var chartWidth: CGFloat
    let currentTime: Double
    let videoDuration: Double

    var body: some View {
        ZStack {
            chartContent
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            self.chartSize = geo.size
                            self.chartWidth = geo.size.width
                        }
                    }
                )

            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let tapX = value.location.x
                            let width = chartSize.width
                            let timestamps = data.map { $0.timestamp }

                            guard let minT = timestamps.min(), let maxT = timestamps.max(), width > 0 else { return }

                            let ratio = max(0, min(tapX / width, 1))
                            let tappedTime = minT + ratio * (maxT - minT)

                            onTapTime(tappedTime)
                        }
                )
        }
        .frame(height: 200)
        .padding()
    }

    @ViewBuilder
    private var chartContent: some View {
        let targetPoints = data.compactMap { point -> (Double, Double)? in
            guard let x = point.targetX else { return nil }
            return (point.timestamp, x)
        }

        let opponentPoints = data.compactMap { point -> (Double, Double)? in
            guard let x = point.opponentX else { return nil }
            return (point.timestamp, x)
        }

        Chart {
            ForEach(targetPoints, id: \.0) { t, x in
                LineMark(
                    x: .value("Time", t),
                    y: .value("X Position", x),
                    series: .value("Player", "Target")
                )
                .foregroundStyle(.red)
            }

            ForEach(opponentPoints, id: \.0) { t, x in
                LineMark(
                    x: .value("Time", t),
                    y: .value("X Position", x),
                    series: .value("Player", "Opponent")
                )
                .foregroundStyle(.blue)
            }

            ForEach(flagTimestamps, id: \.self) { ts in
                            RuleMark(x: .value("Flag", ts))
                                .foregroundStyle(Color.yellow)
                                .lineStyle(StrokeStyle(lineWidth: 3, dash: [4]))
            }
            
            RuleMark(x: .value("CurrentTime", currentTime))
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxisLabel("Time (s)")
        .chartYScale(domain: -600...600)
        .chartYAxis(.hidden)
        .chartXScale(domain: 0...videoDuration)
    }

    struct LinePoint: Hashable {
        var timestamp: Double
        var value: Double
    }

    private func splitSeries(data: [PositionDataPoint], for keyPath: KeyPath<PositionDataPoint, Double?>) -> [[LinePoint]] {
        var result: [[LinePoint]] = []
        var current: [LinePoint] = []

        for point in data {
            if let value = point[keyPath: keyPath] {
                current.append(LinePoint(timestamp: point.timestamp, value: value))
            } else if !current.isEmpty {
                result.append(current)
                current = []
            }
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }
}
