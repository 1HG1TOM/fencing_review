import SwiftUI

struct EnteringMatchNameView: View {
    @Binding var matchName: String
    var onNext: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack {
                Text("試合名を入力してください").foregroundColor(.white).padding()
                TextField("試合名", text: $matchName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                Button(action: onNext) {
                    Text("次へ")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(matchName.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(matchName.isEmpty)
                .padding([.horizontal, .bottom])
            }
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
            .padding()
        }
    }
}

struct TappingOverlayView: View {
    @Binding var points: [CGPoint]
    var resultText: String
    var onTap: (CGPoint) -> Void
    var onDoubleTap: () -> Void // ダブルタップで録画開始
    
    @State private var draggingIndex: Int? = nil
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景
                Color.clear
                    .contentShape(Rectangle())
                    // 同時に複数ジェスチャーを有効化
                    .simultaneousGesture(singleTapGesture())
                    .simultaneousGesture(doubleTapGesture())
                    .simultaneousGesture(dragGesture())
                
                // 点の描画
                ForEach(points.indices, id: \.self) { i in
                    Circle()
                        .fill(Color.green.opacity(0.9))
                        .frame(width: 20, height: 20)
                        .position(points[i])
                        .overlay(Text("\(i+1)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        )
                }
                
                // テキスト表示
                VStack {
                    Text(resultText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 16)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - ジェスチャー群
    
    private func singleTapGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                if points.count < 4 {
                    onTap(value.location)
                }
            }
    }
    
    private func doubleTapGesture() -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                if points.count >= 4 {
                    onDoubleTap()
                }
            }
    }
    
    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard points.count >= 4 else { return }
                let dragPoint = value.location
                if let index = draggingIndex {
                    points[index] = dragPoint
                } else if let nearest = nearestPoint(to: dragPoint) {
                    draggingIndex = nearest
                }
            }
            .onEnded { _ in
                draggingIndex = nil
            }
    }
    
    // MARK: - 近い点を検出
    private func nearestPoint(to location: CGPoint) -> Int? {
        var minDistance = CGFloat.greatestFiniteMagnitude
        var minIndex: Int? = nil
        for (i, p) in points.enumerated() {
            let d = hypot(p.x - location.x, p.y - location.y)
            if d < minDistance && d < 30 { // 半径30pt以内
                minDistance = d
                minIndex = i
            }
        }
        return minIndex
    }
}


struct ReadyToRecordView: View {
    let points: [CGPoint]
    var onStart: () -> Void

    var body: some View {
        ZStack {
            // 点だけ表示（触らせるのは下のTappingOverlayViewなので透過）
            ForEach(Array(points.enumerated()), id: \.offset) { index, pt in
                Circle()
                    .fill(Color.green)
                    .frame(width: 15, height: 15)
                    .position(pt)
                    .overlay(
                        Text("\(index+1)")
                            .foregroundColor(.white)
                            .font(.caption2)
                            .fontWeight(.bold)
                    )
            }

            VStack {
                Spacer()
                Button(action: onStart) {
                    Text("録画開始")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.bottom, 30)
            }
        }
        // 透明部分はタップ透過
        .contentShape(Rectangle())
        .allowsHitTesting(false)
    }
}


struct RecordingOverlayView: View {
    let resultText: String
    var onStop: () -> Void

    var body: some View {
        VStack {
            Text(resultText)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .padding(.top)
            Spacer()
            Button(action: onStop) {
                Text("録画停止 & 保存")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct SavingOverlayView: View {
    let remainingRequests: Int

    var body: some View {
        Color.black.opacity(0.7).ignoresSafeArea()
        VStack {
            ProgressView()
                .scaleEffect(2)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("保存中...")
                .font(.title)
                .foregroundColor(.white)
                .padding()
            if remainingRequests > 0 {
                Text("残り: \(remainingRequests) 件の分析結果を待っています")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
