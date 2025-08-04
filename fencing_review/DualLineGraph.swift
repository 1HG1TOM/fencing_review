// DualLineGraph.swift
import SwiftUI
import Charts

struct DualLineGraph: View {
    let data: [PositionDataPoint]
    let flagTimestamps: [Double]
    let onTapTime: (Double) -> Void
    @Binding var chartHeight: CGFloat
    @Binding var currentTime: Double
    let videoDuration: Double
    let xAxisStart: Double

    struct LinePoint: Hashable {
        var timestamp: Double
        var value: Double
    }

    @State private var chartSize: CGSize = .zero

    var body: some View {
        ZStack {
            Chart {
                // Target のライン
                ForEach(splitSeries(data: data, for: \.targetX), id: \.self) { segment in
                    if segment.count > 1 {
                        let segmentID = UUID().uuidString
                        ForEach(segment, id: \.self) { point in
                            let flippedTimestamp = xAxisStart + videoDuration - point.timestamp
                            LineMark(
                                x: .value("X Position", point.value),
                                y: .value("Time", flippedTimestamp),
                                series: .value("Player", "Target \(segmentID)")
                            )
                            .foregroundStyle(.red)
                        }
                    }
                }

                // Opponent のライン
                ForEach(splitSeries(data: data, for: \.opponentX), id: \.self) { segment in
                    if segment.count > 1 {
                        let segmentID = UUID().uuidString
                        ForEach(segment, id: \.self) { point in
                            let flippedTimestamp = xAxisStart + videoDuration - point.timestamp
                            LineMark(
                                x: .value("X Position", point.value),
                                y: .value("Time", flippedTimestamp),
                                series: .value("Player", "Opponent \(segmentID)")
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                }

                // 現在のセット範囲内のみのフラグ線（横線）
                ForEach(flagTimestamps.filter { $0 >= xAxisStart && $0 <= xAxisStart + videoDuration }, id: \.self) { ts in
                    let flippedFlag = xAxisStart + videoDuration - ts
                    RuleMark(y: .value("Flag", flippedFlag))
                        .foregroundStyle(Color.yellow)
                        .lineStyle(StrokeStyle(lineWidth: 3, dash: [4]))
                }

                // 現在時間線（横線）
                let flippedCurrentTime = xAxisStart + videoDuration - currentTime
                RuleMark(y: .value("CurrentTime", flippedCurrentTime))
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXScale(domain: -800...800)
            .chartYScale(domain: 0...videoDuration)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        self.chartSize = geo.size
                        self.chartHeight = geo.size.height
                    }
                }
            )

            // タップ検出領域
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let tapY = value.location.y
                            let ratio = max(0, min(tapY / chartSize.height, 1))
                            let tappedRelative = ratio * videoDuration
                            let flippedTappedTime = xAxisStart + tappedRelative
                            DispatchQueue.main.async {
                                currentTime = flippedTappedTime
                                onTapTime(flippedTappedTime)
                            }
                        }
                )
        }
        .frame(height: chartHeight)
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

        return result
    }
}
