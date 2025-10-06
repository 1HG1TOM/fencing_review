import SwiftUI

struct CameraScreen: View {
    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        ZStack {
            CameraView(cameraManager: cameraManager)
            
            switch cameraManager.uiState {
            case .tappingPoints, .readyToRecord:
                TappingOverlayView(
                    points: $cameraManager.points,
                    resultText: cameraManager.resultText,
                    onTap: { cameraManager.handleTap(location: $0) },
                    onDoubleTap: { cameraManager.startRecordingAndAnalysis() }
                )
                
            case .recording:
                RecordingOverlayView(resultText: cameraManager.resultText) {
                    cameraManager.stopRecordingAndAnalysis()
                }
                
            case .saving:
                SavingOverlayView(remainingRequests: cameraManager.remainingRequests)
                
            default:
                EnteringMatchNameView(matchName: $cameraManager.matchName) {
                    cameraManager.submitMatchName()
                }
            }
        }

        .alert("エラー",
               isPresented: Binding(
                   get: { cameraManager.errorMessage != nil },
                   set: { _ in cameraManager.errorMessage = nil }
               ),
               actions: { Button("OK") { cameraManager.errorMessage = nil } },
               message: { Text(cameraManager.errorMessage ?? "不明なエラーが発生しました。") }
        )
    }
}
