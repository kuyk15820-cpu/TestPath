import SwiftUI
import UIKit

struct TargetGameApp: Identifiable, Hashable {
    let id = UUID()
    let rawName: String?
    let bundleID: String

    // 🟢 ตรวจสอบสถานะการติดตั้งแบบ Dynamic ทุกครั้งที่มีการเรียกใช้
    var isInstalled: Bool {
        // เช็กจากไอคอนระบบจริง: ถ้าไม่มีแอปจริงในเครื่อง ไอคอนจะคืนค่า nil
        return UIImage.applicationIcon(forBundleIdentifier: bundleID) != nil
    }

    // 🟢 แสดงชื่อแอปแบบ Dynamic: ถ้าไม่ได้ติดตั้งจะต่อท้ายด้วย (ไม่ได้ติดตั้ง) อัตโนมัติ
    var name: String {
        let baseName = rawName ?? TargetGameApp.fetchAppName(for: bundleID)
        return isInstalled ? baseName : "\(baseName) (ไม่ได้ติดตั้ง)"
    }

    var icon: UIImage? {
        UIImage.applicationIcon(forBundleIdentifier: bundleID)
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
