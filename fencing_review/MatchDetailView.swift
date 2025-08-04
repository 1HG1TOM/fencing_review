// MatchDetailView.swift
import AVKit
import Photos
import Charts
import SwiftUI

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
    @State private var chartHeight: CGFloat = 400
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
                        let newData = splitSets[newValue]
                        self.positionData = newData
                        let newStartTime = newData.first?.timestamp ?? 0
                        self.currentTime = newStartTime
                        seekToTime(newStartTime) // ← 再生位置をセット先頭にジャンプ
                    }
                }

                if let player = player, let size = videoSize {
                    let aspectRatio = size.width / size.height
                    AVPlayerContainerView(player: player)
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .onAppear { player.play() }
                } else {
                    Text("動画を読み込み中...")
                }

                if !positionData.isEmpty {
                    let start = positionData.first?.timestamp ?? 0
                    let end = positionData.last?.timestamp ?? start
                    let duration = end - start

                    HStack(alignment: .top) {
                        VerticalSlider(
                            value: $currentTime,
                            range: start...end,
                            flags: flagTimestamps,
                            height: chartHeight,
                            onEnded: { seekToTime($0) }
                        )
                        .frame(width: 40)

                        DualLineGraph(
                            data: positionData,
                            flagTimestamps: flagTimestamps,
                            onTapTime: { seekToTime($0) },
                            chartHeight: $chartHeight,
                            currentTime: $currentTime,
                            videoDuration: duration,
                            xAxisStart: start
                        )
                    }
                } else {
                    Text("分析データを読み込み中...")
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
