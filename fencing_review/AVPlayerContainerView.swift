import SwiftUI
import AVKit

struct AVPlayerContainerView: UIViewControllerRepresentable {
    let player: AVPlayer
    var onFullscreenChange: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let parent: AVPlayerContainerView
        init(_ parent: AVPlayerContainerView) { self.parent = parent }

        func playerViewControllerWillBeginFullScreenPresentation(_ pvc: AVPlayerViewController) {
            parent.onFullscreenChange?(true)
            Logger.shared.log(event: "fullscreen", ["state": "enter",
                                                    "position": pvc.player?.currentTime().seconds ?? 0])
        }
        func playerViewControllerWillEndFullScreenPresentation(_ pvc: AVPlayerViewController) {
            parent.onFullscreenChange?(false)
            Logger.shared.log(event: "fullscreen", ["state": "exit",
                                                    "position": pvc.player?.currentTime().seconds ?? 0])
        }
    }
}
