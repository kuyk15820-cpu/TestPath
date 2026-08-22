import SwiftUI
import UIKit

struct TargetGameApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleID: String
    let isInstalled: Bool

    // Initializer สำหรับใส่ทั้ง name และ bundleID
    init(name: String, bundleID: String) {
        self.bundleID = bundleID
        
        // 🟢 เช็กจากไอคอนระบบจริง: ถ้าไม่มีแอป ไอคอนจะคืนค่า nil
        let installed = UIImage.applicationIcon(forBundleIdentifier: bundleID) != nil
        self.isInstalled = installed
        self.name = installed ? name : "\(name) (ไม่ได้ติดตั้ง)"
    }

    // Initializer แบบระบุแค่ bundleID
    init(bundleID: String) {
        self.bundleID = bundleID
        
        // 🟢 เช็กจากไอคอนระบบจริง: ถ้าไม่มีแอป ไอคอนจะคืนค่า nil
        let installed = UIImage.applicationIcon(forBundleIdentifier: bundleID) != nil
        self.isInstalled = installed
        
        let baseName = TargetGameApp.fetchAppName(for: bundleID)
        self.name = installed ? baseName : "\(baseName) (ไม่ได้ติดตั้ง)"
    }

    var icon: UIImage? {
        UIImage.applicationIcon(forBundleIdentifier: bundleID)
    }

    // MARK: - Private Helpers

    private static func fetchAppName(for bundleID: String) -> String {
        // 1. รายชื่อแอปที่กำหนดไว้ล่วงหน้า
        let presetApps: [String: String] = [
            "com.dts.freefireth": "Free Fire",
            "com.dts.freefiremax": "Free Fire MAX"
        ]
        
        if let presetName = presetApps[bundleID] {
            return presetName
        }

        // 2. ดึงจากระบบ iOS (ถ้าเครื่องอนุญาต)
        if let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type,
           let proxy = proxyClass.perform(Selector(("applicationProxyForIdentifier:")), with: bundleID)?.takeUnretainedValue() as? NSObject {
            
            if let localizedName = proxy.perform(Selector(("localizedName")))?.takeUnretainedValue() as? String, !localizedName.isEmpty {
                return localizedName
            }
        }

        // 3. Fallback ตัดคำจาก Bundle ID
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
