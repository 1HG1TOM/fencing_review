import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    static var allowAllOrientations = false
    
    // デバッグ用：最後に返した値をキャッシュして、変更時のみログ出力
    private static var lastOrientationMask: UIInterfaceOrientationMask?

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        let mask: UIInterfaceOrientationMask = AppDelegate.allowAllOrientations
            ? [.portrait, .landscapeLeft, .landscapeRight]
            : [.portrait]
        
        // 値が変わった時だけログを出力（ノイズを減らす）
        if AppDelegate.lastOrientationMask != mask {
            if AppDelegate.allowAllOrientations {
                print("→ AppDelegate: allowing all orientations")
            } else {
                print("→ AppDelegate: portrait only")
            }
            AppDelegate.lastOrientationMask = mask
        }
        
        return mask
    }
}
