import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            // 背景のカメラビューは常に表示
            CameraView(cameraManager: cameraManager)

            // UIの状態に応じて表示するオーバーレイを切り替える
            switch cameraManager.uiState {
            case .enteringMatchName:
                EnteringMatchNameView(
                    matchName: $cameraManager.matchName,
                    onNext: { cameraManager.submitMatchName() }
                )
                
            case .tappingPoints:
                // ポイントタップ中は、画面全体でタップを受け付ける
                TappingOverlayView(
                    points: cameraManager.points,
                    resultText: cameraManager.resultText,
                    onTap: { location in
                        cameraManager.handleTap(location: location)
                    }
                )

            case .readyToRecord:
                // 4点タップ後は、開始ボタンを表示
                ReadyToRecordView(
                    points: cameraManager.points,
                    resultText: cameraManager.resultText,
                    onStart: { cameraManager.startRecordingAndAnalysis() }
                )
                
            case .recording:
                RecordingOverlayView(
                    resultText: cameraManager.resultText,
                    onStop: { cameraManager.stopRecordingAndAnalysis() }
                )
                
            case .saving:
                SavingOverlayView(remainingRequests: cameraManager.remainingRequests)
            }
        }
        .alert("エラー", isPresented: .constant(cameraManager.errorMessage != nil), actions: {
            Button("OK") { cameraManager.errorMessage = nil }
        }, message: {
            Text(cameraManager.errorMessage ?? "不明なエラーが発生しました。")
        })
    }
}

// MARK: - Subviews for each state

struct EnteringMatchNameView: View {
    @Binding var matchName: String
    var onNext: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            VStack {
                Text("試合名を入力してください").foregroundColor(.white).padding()
                TextField("試合名", text: $matchName).textFieldStyle(.roundedBorder).padding()
                Button(action: onNext) {
                    Text("次へ")
                        .fontWeight(.bold).padding().frame(maxWidth: .infinity)
                        .background(matchName.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white).cornerRadius(10)
                }
                .disabled(matchName.isEmpty)
                .padding([.horizontal, .bottom])
            }
            .background(Color.black.opacity(0.7)).cornerRadius(20).padding()
        }
    }
}

struct TappingOverlayView: View {
    let points: [CGPoint]
    let resultText: String
    var onTap: (CGPoint) -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) { // ★ ZStackの配置基準を左上に変更
            // 画面全体でタップを検知するための透明なView
            Color.clear.contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in onTap(value.location) })
            
            Text(resultText)
                .font(.caption) // 文字を小さくする
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .padding() // 画面の端から少し離す
            
            // タップしたポイントの表示
            ForEach(Array(points.enumerated()), id: \.offset) { index, pt in
                Circle().fill(Color.green).frame(width: 15, height: 15).position(pt)
                    .overlay(Text("\(index+1)").foregroundColor(.white).font(.caption2).fontWeight(.bold))
            }
        }
    }
}

struct ReadyToRecordView: View {
    let points: [CGPoint]
    let resultText: String
    var onStart: () -> Void
    
    var body: some View {
        ZStack {
            ForEach(Array(points.enumerated()), id: \.offset) { index, pt in
                Circle().fill(Color.green).frame(width: 15, height: 15).position(pt)
                    .overlay(Text("\(index+1)").foregroundColor(.white).font(.caption2).fontWeight(.bold))
            }
            
            VStack {
                Text(resultText).foregroundColor(.white).padding().background(Color.black.opacity(0.6)).cornerRadius(8).padding(.top)
                Spacer()
                Button(action: onStart) {
                    Text("録画開始").font(.title2).fontWeight(.bold).padding().background(Color.blue).foregroundColor(.white).cornerRadius(10)
                }.padding()
            }
        }
    }
}

struct RecordingOverlayView: View {
    let resultText: String
    var onStop: () -> Void

    var body: some View {
        VStack {
            Text(resultText).foregroundColor(.white).padding().background(Color.black.opacity(0.6)).cornerRadius(8).padding(.top)
            Spacer()
            Button(action: onStop) {
                Text("録画停止 & 保存").font(.title2).fontWeight(.bold).padding().background(Color.red).foregroundColor(.white).cornerRadius(10)
            }.padding()
        }
    }
}

struct SavingOverlayView: View {
    let remainingRequests: Int
    
    var body: some View {
        Color.black.opacity(0.7).ignoresSafeArea()
        VStack {
            ProgressView().scaleEffect(2).progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("保存中...").font(.title).foregroundColor(.white).padding()
            if remainingRequests > 0 {
                Text("残り: \(remainingRequests) 件の分析結果を待っています").foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
