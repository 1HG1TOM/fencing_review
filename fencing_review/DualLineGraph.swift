import SwiftUI
import Charts

struct DualLineGraph: View {
    let data: [PositionDataPoint]
    let flagTimestamps: [Double]
    let gfSeconds: [Double]
    let gaSeconds: [Double]
    let onTapTime: (Double) -> Void
    @Binding var chartHeight: CGFloat?
    @Binding var currentTime: Double
    let videoDuration: Double
    let xAxisStart: Double

    struct LinePoint: Hashable {
        var timestamp: Double
        var value: Double
    }

    @State private var chartSize: CGSize = .zero

    var body: some View {
        let chartView = ZStack {
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

                // フラグ（黄色、破線）
                ForEach(flagTimestamps.filter { $0 >= xAxisStart && $0 <= xAxisStart + videoDuration }, id: \.self) { ts in
                    let flippedFlag = xAxisStart + videoDuration - ts
                    RuleMark(y: .value("Flag", flippedFlag))
                        .foregroundStyle(Color.yellow)
                        .lineStyle(StrokeStyle(lineWidth: 3, dash: [4]))
                }

                // GF（黒線）
                ForEach(gfSeconds.filter { $0 >= xAxisStart && $0 <= xAxisStart + videoDuration }, id: \.self) { ts in
                    let y = xAxisStart + videoDuration - ts
                    RuleMark(y: .value("GF", y))
                        .foregroundStyle(Color.black)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // GA（グレー0.5）
                ForEach(gaSeconds.filter { $0 >= xAxisStart && $0 <= xAxisStart + videoDuration }, id: \.self) { ts in
                    let y = xAxisStart + videoDuration - ts
                    RuleMark(y: .value("GA", y))
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // 現在時間線
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
                        if chartHeight == nil {
                            self.chartHeight = geo.size.height
                        }
                    }
                }
            )

            // タップ検出エリア
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let tapY = value.location.y
                            let ratio = max(0, min(tapY / chartSize.height, 1))
                            let tappedTime = xAxisStart + ratio * videoDuration
                            DispatchQueue.main.async {
                                currentTime = tappedTime
                                onTapTime(tappedTime)
                            }
                        }
                )
        }

        Group {
            if let height = chartHeight {
                chartView.frame(height: height)
            } else {
                chartView
            }
        }
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
