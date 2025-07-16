import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @ObservedObject var cameraManager: CameraManager

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onFrameCaptured = cameraManager.onFrameCaptured

        DispatchQueue.main.async {
            self.cameraManager.cameraViewController = controller
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}
