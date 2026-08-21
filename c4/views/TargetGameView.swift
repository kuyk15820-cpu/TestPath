import SwiftUI
import UIKit

// MARK: - Extension เพื่อดึง Application Icon จาก Private API
extension UIImage {
    // ดึง Private Method `_applicationIconImage(forBundleIdentifier:format:scale:)` ผ่าน Selector
    static func applicationIcon(forBundleIdentifier bid: String) -> UIImage? {
        let selector = Selector(("_applicationIconImage:format:scale:"))
        guard UIImage.responds(to: selector) else { return nil }
        
        typealias MethodImp = @convention(c) (AnyObject, Selector, NSString, Int, CGFloat) -> Unmanaged<UIImage>?
        let method = UIImage.method(for: selector)
        let imp = unsafeBitCast(method, to: MethodImp.self)
        
        if let unmanagedImage = imp(UIImage.self, selector, bid as NSString, 0, 3.0) {
            return unmanagedImage.takeUnretainedValue()
        }
        return nil
    }
}

// MARK: - Target Game Model
struct TargetGameApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    
    var icon: UIImage? {
        UIImage.applicationIcon(forBundleIdentifier: bundleID)
    }
}

// MARK: - Main Target Game View
struct TargetGameView: View {
    // 🟢 กำหนด 2 แอปเป้าหมายพร้อม Bundle ID ของคุณที่นี่
    private let targetApps: [TargetGameApp] = [
        TargetGameApp(name: "Free Fire", bundleID: "com.dts.freefireth"),
        TargetGameApp(name: "Free Fire MAX", bundleID: "com.dts.freefiremax")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(targetApps) { app in
                        NavigationLink(destination: QuickApplyView()) {
                            HStack(spacing: 16) {
                                // 🟢 แสดงไอคอนแอป หรือใช้ app.window.checkmark ถ้าหาไม่เจอ
                                if let icon = app.icon {
                                    Image(uiImage: icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 48, height: 48)
                                        .cornerRadius(10)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                } else {
                                    Image(systemName: "app.window.checkmark")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 32, height: 32)
                                        .padding(8)
                                        .foregroundStyle(AppTheme.accent)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(10)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.name)
                                        .font(.headline)
                                    Text(app.bundleID)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("เลือกเกมที่ต้องการนำส่ง Patch")
                }
            }
            .listStyle(.plain) // 🟢 กำหนด Style เป็น .plain ตามต้องการ
            .navigationTitle("Target Game")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
