import SwiftUI
import UIKit
import MBProgressHUD

struct HUDHelper {
    private static var currentHUD: MBProgressHUD?

    @MainActor
    static func show(message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }
        
        hide() // เคลียร์ตัวเก่าก่อนถ้ามี
        let hud = MBProgressHUD.showAdded(to: window, animated: true)
        hud.label.text = message
        currentHUD = hud
    }

    @MainActor
    static func update(message: String) {
        if let hud = currentHUD {
            hud.label.text = message
        } else {
            show(message: message)
        }
    }

    @MainActor
    static func hide() {
        if let hud = currentHUD {
            hud.hide(animated: true)
            currentHUD = nil
        }
    }
}
