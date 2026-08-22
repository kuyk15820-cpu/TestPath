import SwiftUI
import UIKit

struct TargetGameApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleID: String
    let isInstalled: Bool // 🟢 เพิ่มสถานะการติดตั้งแอป

    // Initializer สำหรับใส่ทั้ง name และ bundleID
    init(name: String, bundleID: String) {
        self.bundleID = bundleID
        self.isInstalled = TargetGameApp.checkIsInstalled(for: bundleID)
        
        let baseName = name
        self.name = self.isInstalled ? baseName : "\(baseName) (ไม่ได้ติดตั้ง)"
    }

    // Initializer แบบระบุแค่ bundleID
    init(bundleID: String) {
        self.bundleID = bundleID
        self.isInstalled = TargetGameApp.checkIsInstalled(for: bundleID)
        
        let baseName = TargetGameApp.fetchAppName(for: bundleID)
        self.name = self.isInstalled ? baseName : "\(baseName) (ไม่ได้ติดตั้ง)"
    }

    var icon: UIImage? {
        UIImage.applicationIcon(forBundleIdentifier: bundleID)
    }

    // MARK: - Private Helpers

    // 🟢 ตรวจสอบว่ามีแอปติดตั้งอยู่ในเครื่องหรือไม่
    private static func checkIsInstalled(for bundleID: String) -> Bool {
        if let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type,
           let proxy = proxyClass.perform(Selector(("applicationProxyForIdentifier:")), with: bundleID)?.takeUnretainedValue() as? NSObject {
            
            // ตรวจสอบผ่าน isInstalled ของ LSApplicationProxy
            if let isInstalledNum = proxy.perform(Selector(("isInstalled")))?.takeUnretainedValue() as? NSNumber {
                return isInstalledNum.boolValue
            }
            
            // กรณีเป็นแอปที่ซ่อนอยู่ ให้เช็กจาก appState.isInstalled
            if let appState = proxy.perform(Selector(("appState")))?.takeUnretainedValue() as? NSObject,
               let isInstalledNum = appState.perform(Selector(("isInstalled")))?.takeUnretainedValue() as? NSNumber {
                return isInstalledNum.boolValue
            }
        }
        
        // เช็กสำรองจาก Icon (หากไม่มีแอป จะไม่สามารถดึงไอคอนได้)
        return UIImage.applicationIcon(forBundleIdentifier: bundleID) != nil
    }

    private static func fetchAppName(for bundleID: String) -> String {
        // 1. กำหนดชื่อแอปที่ถูกต้องไว้ล่วงหน้า
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
