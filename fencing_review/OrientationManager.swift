import UIKit

enum OrientationManager {
    static func allowAllOrientations(_ allowed: Bool) {
        if let _ = UIApplication.shared.delegate as? AppDelegate {
            AppDelegate.allowAllOrientations = allowed
        }
    }

    static func setLandscapeRight() {
        // ログ記録を削除（MatchDetailViewのdevice_orientationで記録する）
        print("→ OrientationManager: setLandscapeRight()")

        AppDelegate.allowAllOrientations = true
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }

    static func setPortrait() {
        // ログ記録を削除（MatchDetailViewのdevice_orientationで記録する）
        print("→ OrientationManager: setPortrait()")

        AppDelegate.allowAllOrientations = false
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }

    private static func currentOrientation() -> String {
        switch UIDevice.current.orientation {
        case .portrait: return "portrait"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        case .portraitUpsideDown: return "portraitUpsideDown"
        default: return "unknown"
        }
    }
}
