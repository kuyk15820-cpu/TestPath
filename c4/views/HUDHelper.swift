import SwiftUI
import UIKit
import MBProgressHUD

struct HUDHelper {
    private static var currentHUD: MBProgressHUD?
    private static var showTime: Date?

    @MainActor
    static func show(message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }
        
        // หากมี HUD ตัวเก่าเปิดค้างอยู่ ให้สั่ง hide ทันทีโดยไม่ต้องหน่วงเวลา
        if let existingHUD = currentHUD {
            existingHUD.hide(animated: false)
            currentHUD = nil
        }

        let hud = MBProgressHUD.showAdded(to: window, animated: true)
        hud.mode = .indeterminate
        
        // กำหนด Background Style
        hud.backgroundView.style = MBProgressHUDBackgroundStyle.solidColor
        hud.backgroundView.color = UIColor(white: 0.0, alpha: 0.4)
        
        // กำหนด Bezel และ Content Style
        hud.bezelView.blurEffectStyle = .dark
        hud.contentColor = .white
        hud.label.text = message
        hud.label.textColor = .lightGray
        
        // ตั้งค่า minShowTime ให้เป็น 1 วินาที
        hud.minShowTime = 1.0
        
        showTime = Date()
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
        guard let hud = currentHUD else { return }
        
        let targetHUD = hud
        let startTime = showTime ?? Date()
        
        // เคลียร์ Reference ทันทีเพื่อป้องกันการสั่ง hide ซ้ำ
        currentHUD = nil
        showTime = nil
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let minDuration: TimeInterval = 1.0
        
        // คำนวณเวลาถ้ายังไม่ถึง 1 วินาที ให้หน่วงเวลาก่อนสั่งซ่อน HUD
        if elapsedTime < minDuration {
            let delay = minDuration - elapsedTime
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                targetHUD.hide(animated: true)
            }
        } else {
            targetHUD.hide(animated: true)
        }
    }
}
