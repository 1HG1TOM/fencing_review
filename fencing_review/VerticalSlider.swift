// VerticalSlider.swift
import SwiftUI

struct VerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let flags: [Double]
    let height: CGFloat
    var onEnded: ((Double) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let sliderHeight = height
            let knobSize: CGFloat = 14

            ZStack(alignment: .top) {
                // バーの背景
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 6)
                    .position(x: geo.size.width / 2, y: sliderHeight / 2)

                // フラグのマーカー
                ForEach(flags, id: \.self) { flag in
                    let ratio = CGFloat((flag - range.lowerBound) / (range.upperBound - range.lowerBound))
                    if ratio >= 0 && ratio <= 1 {
                        Rectangle()
                            .fill(Color.yellow)
                            .frame(width: 10, height: 2)
                            .position(x: geo.size.width / 2, y: ratio * sliderHeight)
                    }
                }

                // 現在値ノブ
                let ratio = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue)
                    .frame(width: 1.5 * knobSize, height: knobSize)
                    .position(x: geo.size.width / 2, y: ratio * sliderHeight)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let location = gesture.location.y
                                let limited = max(0, min(location, sliderHeight))
                                let newValue = Double(limited / sliderHeight) * (range.upperBound - range.lowerBound) + range.lowerBound
                                value = newValue
                            }
                            .onEnded { gesture in
                                let location = gesture.location.y
                                let limited = max(0, min(location, sliderHeight))
                                let newValue = Double(limited / sliderHeight) * (range.upperBound - range.lowerBound) + range.lowerBound
                                value = newValue
                                onEnded?(newValue)
                            }
                    )
            }
        }
        .frame(height: height)
    }
}
