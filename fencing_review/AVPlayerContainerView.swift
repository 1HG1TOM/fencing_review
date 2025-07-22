//
//  AVPlayerContainerView.swift
//  fencing_review
//
//  Created by 萩原亜依 on 2025/07/22.
//

import SwiftUI
import AVKit

struct AVPlayerContainerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.entersFullScreenWhenPlaybackBegins = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // 特に何もしない
    }
}
