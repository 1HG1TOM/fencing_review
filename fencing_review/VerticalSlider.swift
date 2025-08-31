import SwiftUI

struct ScoreLabelMark: Hashable {
    let time: Double
    let text: String
}

struct VerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let flags: [Double]
    let scoresGF: [Double]
    let scoresGA: [Double]
    let labels: [ScoreLabelMark]
    let height: CGFloat
    var labelsOnLeft: Bool = false
    
    @Binding var isEditing: Bool
    var onEnded: ((Double) -> Void)? = nil
    
    
    // レイアウト定数（必要に応じて微調整）
    private let barWidth: CGFloat = 6
    private let labelGap: CGFloat = 6
    private let labelWidth: CGFloat = 25
    private let knobWidth: CGFloat = 21
    private let knobSize: CGFloat = 14
    private let graphSpacing: CGFloat = 8  // ← グラフ側だけに入れる内部スペース
    
    var body: some View {
        // ノブの左右はみ出しに必要な余白（バー中心から半分）
        let knobPad = max(0, knobWidth/2 - barWidth/2)
        
        // どちら側が“ラベル側 / グラフ側”かで内部配分を切替
        let leftIsLabelSide  = labelsOnLeft
        let rightIsLabelSide = !labelsOnLeft
        
        let leftNeededForLabel  = leftIsLabelSide  ? (labelGap + labelWidth) : 0
        let rightNeededForLabel = rightIsLabelSide ? (labelGap + labelWidth) : 0
        
        let leftNeededForGraph  = leftIsLabelSide  ? graphSpacing : 0
        let rightNeededForGraph = rightIsLabelSide ? graphSpacing : 0
        
        // 左右の最終サイド幅：ノブ余白も確保
        let leftSide  = max(leftNeededForLabel + leftNeededForGraph,  knobPad)
        let rightSide = max(rightNeededForLabel + rightNeededForGraph, knobPad)
        
        let sliderWidth = leftSide + barWidth + rightSide
        let barX = leftSide + barWidth/2
        
        GeometryReader { _ in
            let sliderHeight = height
            let insetY: CGFloat = knobSize/2 + 2
            // ★ 使う高さは「グラフと同じ高さ」
            let plotHeight = sliderHeight
            
            ZStack(alignment: .topLeading) {
                // ★ バーは plotHeight 全体を使う
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: barWidth, height: plotHeight)
                    .position(x: barX, y: plotHeight / 2)
                
                // ★ マークは inset を足さず、plotHeight に直接マッピング
                ForEach(flags, id: \.self) { t in
                    mark(at: t, range: range, plotHeight: plotHeight, x: barX, color: .yellow)
                }
                ForEach(scoresGF, id: \.self) { t in
                    mark(at: t, range: range, plotHeight: plotHeight, x: barX, color: .black)
                }
                ForEach(scoresGA, id: \.self) { t in
                    mark(at: t, range: range, plotHeight: plotHeight, x: barX, color: .gray.opacity(0.5))
                }
                
                // ★ ラベルも plotHeight に直接マッピング
                ForEach(labels, id: \.self) { lab in
                    let r = CGFloat((lab.time - range.lowerBound) / (range.upperBound - range.lowerBound))
                    if r >= 0 && r <= 1 {
                        Text(lab.text)
                            .font(.caption2).monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: labelWidth, alignment: labelsOnLeft ? .trailing : .leading)
                            .position(
                                x: labelsOnLeft
                                ? (barX - (barWidth/2 + labelGap + labelWidth/2))
                                : (barX + (barWidth/2 + labelGap + labelWidth/2)),
                                y: r * plotHeight                          // ← ここを変更
                            )
                    }
                }
                
                // ★ ノブは idealY を上下 inset でクランプして“切れない”ようにする
                let r = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                let idealY = r * plotHeight
                let knobY  = min(max(idealY, insetY), plotHeight - insetY)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue)
                    .frame(width: knobWidth, height: knobSize)
                    .position(x: barX, y: knobY)
                    .contentShape(Rectangle().inset(by: -12))
                    .gesture(
                        DragGesture()
                            .onChanged { g in
                                if !isEditing { isEditing = true } // ★ドラッグ開始
                                let clamped = min(max(g.location.y, 0), plotHeight)
                                let rr = clamped / plotHeight
                                let newValue = Double(rr) * (range.upperBound - range.lowerBound) + range.lowerBound
                                value = newValue                     // ★表示はドラッグ位置を優先
                            }
                            .onEnded { g in
                                let clamped = min(max(g.location.y, 0), plotHeight)
                                let rr = clamped / plotHeight
                                let newValue = Double(rr) * (range.upperBound - range.lowerBound) + range.lowerBound
                                value = newValue
                                onEnded?(newValue)                   // ★ここで実シーク
                                isEditing = false                    // ★ドラッグ終了
                            }
                    )
            }
        }
        
        // ← スライダー自身のフレームに“ラベル側 or グラフ側”の内部スペースを含める
        .frame(width: sliderWidth, height: height, alignment: .topLeading)
    }
    
    @ViewBuilder
    private func mark(
        at t: Double,
        range: ClosedRange<Double>,
        plotHeight: CGFloat,
        x: CGFloat,
        color: Color
    ) -> some View {
        let ratio = CGFloat((t - range.lowerBound) / (range.upperBound - range.lowerBound))
        if ratio >= 0 && ratio <= 1 {
            Rectangle()
                .fill(color)
                .frame(width: 10, height: 2)
                .position(x: x, y: ratio * plotHeight)   // ← ここを変更
        }
    }
}
