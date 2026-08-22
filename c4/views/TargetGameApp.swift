import SwiftUI
import UIKit

struct TargetGameApp: Identifiable, Hashable {
    let id = UUID()
    let rawName: String?
    let bundleID: String

    // 🟢 เช็กสถานะติดตั้งแบบเจาะลึกผ่าน LSApplicationProxy
    var isInstalled: Bool {
        guard let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type,
              let proxy = proxyClass.perform(Selector(("applicationProxyForIdentifier:")), with: bundleID)?.takeUnretainedValue() as? NSObject else {
            return false
        }
        
        // 1. เช็กว่าแอปถูกระบุว่าติดตั้งอยู่หรือไม่
        let isInstalledNum = proxy.perform(Selector(("isInstalled")))?.takeUnretainedValue() as? NSNumber
        let installedState = isInstalledNum?.boolValue ?? false
        
        if !installedState { return false }

        // 2. เช็กซ้ำว่าแอปไม่ใช่อยู่ในสถานะ Placeholder (แอปกำลังดาวน์โหลด/โดนลบไปแล้ว)
        if let isPlaceholder = proxy.perform(Selector(("isPlaceholder")))?.takeUnretainedValue() as? NSNumber,
           isPlaceholder.boolValue == true {
            return false
        }

        // 3. เช็กว่ามี Path สำหรับเข้าถึงไฟล์ของแอปนั้นจริงๆ ในระบบหรือไม่
        let hasBundleURL = proxy.perform(Selector(("bundleURL")))?.takeUnretainedValue() != nil
        
        return hasBundleURL
    }

    // 🟢 แสดงชื่อแอป: ต่อท้าย (ไม่ได้ติดตั้ง) ทันทีถ้า isInstalled = false
    var name: String {
        let baseName = rawName ?? TargetGameApp.fetchAppName(for: bundleID)
        return isInstalled ? baseName : "\(baseName) (ไม่ได้ติดตั้ง)"
    }

    var icon: UIImage? {
        isInstalled ? UIImage.applicationIcon(forBundleIdentifier: bundleID) : nil
    }

    // MARK: - Initializers

    init(name: String, bundleID: String) {
        self.rawName = name
        self.bundleID = bundleID
    }

    init(bundleID: String) {
        self.rawName = nil
        self.bundleID = bundleID
    }

    // MARK: - Private Helpers

    private static func fetchAppName(for bundleID: String) -> String {
        let presetApps: [String: String] = [
            "com.dts.freefireth": "Free Fire",
            "com.dts.freefiremax": "Free Fire MAX"
        ]
        
        if let presetName = presetApps[bundleID] {
            return presetName
        }

        if let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type,
           let proxy = proxyClass.perform(Selector(("applicationProxyForIdentifier:")), with: bundleID)?.takeUnretainedValue() as? NSObject {
            
            if let localizedName = proxy.perform(Selector(("localizedName")))?.takeUnretainedValue() as? String, !localizedName.isEmpty {
                return localizedName
            }
        }

        let fallback = bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
        return fallback
    }
    
    static func == (lhs: TargetGameApp, rhs: TargetGameApp) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
}
