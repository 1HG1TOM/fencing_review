import SwiftUI
import AVKit

struct AVPlayerContainerView: UIViewControllerRepresentable {
    let player: AVPlayer
    var onFullscreenChange: ((Bool) -> Void)? = nil
    var onPlaybackStateChange: ((String) -> Void)? = nil

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.delegate = context.coordinator
        
        print("→ AVPlayerContainerView: 初期化完了")
        
        // プレイヤーの状態監視を開始
        context.coordinator.setupPlayerObservers(player: player)
        
        // 通知ベースのフルスクリーン監視を追加
        context.coordinator.setupFullscreenNotifications(controller: controller)
        
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let parent: AVPlayerContainerView
        private var timeControlStatusObserver: NSKeyValueObservation?
        private var rateObserver: NSKeyValueObservation?
        private var lastRate: Float = 0
        private var lastKnownTime: Double = 0
        private var periodicTimeObserver: Any?
        private var isInFullscreen: Bool = false
        private var fullscreenObservers: [NSObjectProtocol] = []
        
        init(_ parent: AVPlayerContainerView) {
            self.parent = parent
        }
        
        deinit {
            cleanup()
        }
        
        func cleanup() {
            timeControlStatusObserver?.invalidate()
            rateObserver?.invalidate()
            if let observer = periodicTimeObserver {
                parent.player.removeTimeObserver(observer)
                periodicTimeObserver = nil
            }
            // 通知の解除
            fullscreenObservers.forEach { NotificationCenter.default.removeObserver($0) }
            fullscreenObservers.removeAll()
        }
        
        func setupFullscreenNotifications(controller: AVPlayerViewController) {
            // フルスクリーン状態の変化を通知で監視
            let enterObserver = NotificationCenter.default.addObserver(
                forName: UIWindow.didBecomeVisibleNotification,
                object: nil,
                queue: .main
            ) { [weak self, weak controller] _ in
                guard let self = self, let controller = controller else { return }
                
                // フルスクリーンかどうかをビューの階層で判定
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let isFullscreen = controller.view.window?.windowScene?.windows.contains(where: {
                        $0.frame == UIScreen.main.bounds && $0.isKeyWindow
                    }) ?? false
                    
                    if isFullscreen && !self.isInFullscreen {
                        print("→ NOTIFICATION: ★★★ フルスクリーン開始検知 ★★★")
                        self.isInFullscreen = true
                        let position = controller.player?.currentTime().seconds ?? 0
                        Logger.shared.log(event: "fullscreen", [
                            "state": "enter",
                            "position": position
                        ])
                        self.parent.onFullscreenChange?(true)
                    }
                }
            }
            fullscreenObservers.append(enterObserver)
            
            // ビューの階層変更を監視（別の方法）
            let viewObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self, weak controller] _ in
                guard let self = self, let controller = controller else { return }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // フルスクリーンから戻った時の検知
                    if self.isInFullscreen {
                        let isStillFullscreen = controller.view.window?.windowScene?.windows.contains(where: {
                            $0.frame == UIScreen.main.bounds && $0.isKeyWindow
                        }) ?? false
                        
                        if !isStillFullscreen {
                            print("→ NOTIFICATION: ★★★ フルスクリーン終了検知 ★★★")
                            self.isInFullscreen = false
                            let position = controller.player?.currentTime().seconds ?? 0
                            Logger.shared.log(event: "fullscreen", [
                                "state": "exit",
                                "position": position
                            ])
                            self.parent.onFullscreenChange?(false)
                        }
                    }
                }
            }
            fullscreenObservers.append(viewObserver)
        }
        
        func setupPlayerObservers(player: AVPlayer) {
            // 再生/一時停止の監視
            timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                guard let self = self else { return }
                let currentTime = player.currentTime().seconds
                
                switch player.timeControlStatus {
                case .playing:
                    // 再生開始時に現在時刻を更新（SEEK誤検知を防ぐ）
                    self.lastKnownTime = currentTime
                    
                    self.parent.onPlaybackStateChange?("play")
                    Logger.shared.log(event: "playback", [
                        "action": "play",
                        "position": currentTime
                    ])
                case .paused:
                    // 一時停止時も現在時刻を更新
                    self.lastKnownTime = currentTime
                    
                    self.parent.onPlaybackStateChange?("pause")
                    Logger.shared.log(event: "playback", [
                        "action": "pause",
                        "position": currentTime
                    ])
                case .waitingToPlayAtSpecifiedRate:
                    break
                @unknown default:
                    break
                }
            }
            
            // シーク（10秒送りなど）の検知
            periodicTimeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                guard let self = self else { return }
                let currentTime = time.seconds
                
                // 再生中のみシークを検知（一時停止中は無視）
                guard player.timeControlStatus == .playing else {
                    self.lastKnownTime = currentTime
                    return
                }
                
                // 大きな時間ジャンプ（2秒以上）をシークとして検知
                // ※ 1秒 → 2秒に変更して誤検知を減らす
                let timeDiff = abs(currentTime - self.lastKnownTime)
                if timeDiff > 2.0 && self.lastKnownTime > 0 {
                    print("→ SEEK検知: \(self.lastKnownTime) → \(currentTime) (diff: \(timeDiff)秒)")
                    Logger.shared.log(event: "seek", [
                        "from": self.lastKnownTime,
                        "to": currentTime,
                        "via": "player_controls"
                    ])
                }
                
                self.lastKnownTime = currentTime
            }
        }

        // デリゲートメソッドも残しておく（動作する環境用）
        func playerViewControllerWillBeginFullScreenPresentation(_ pvc: AVPlayerViewController) {
            print("→ DELEGATE: ★★★ WillBegin フルスクリーン開始 ★★★")
            isInFullscreen = true
            parent.onFullscreenChange?(true)
        }
        
        func playerViewControllerDidBeginFullScreenPresentation(_ pvc: AVPlayerViewController) {
            print("→ DELEGATE: ★★★ DidBegin フルスクリーン開始完了 ★★★")
            let position = pvc.player?.currentTime().seconds ?? 0
            Logger.shared.log(event: "fullscreen", [
                "state": "enter",
                "position": position
            ])
        }
        
        func playerViewControllerWillEndFullScreenPresentation(_ pvc: AVPlayerViewController) {
            print("→ DELEGATE: ★★★ WillEnd フルスクリーン終了 ★★★")
            isInFullscreen = false
            parent.onFullscreenChange?(false)
        }
        
        func playerViewControllerDidEndFullScreenPresentation(_ pvc: AVPlayerViewController) {
            print("→ DELEGATE: ★★★ DidEnd フルスクリーン終了完了 ★★★")
            let position = pvc.player?.currentTime().seconds ?? 0
            Logger.shared.log(event: "fullscreen", [
                "state": "exit",
                "position": position
            ])
        }
    }
}
