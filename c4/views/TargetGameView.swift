import SwiftUI
import UIKit

// MARK: - Extension สำหรับดึง Private API เหมือนใน Objective-C
extension UIImage {
    static func applicationIcon(forBundleIdentifier bid: String) -> UIImage? {
        // Selector ชื่อเดียวกับ Objective-C: _applicationIconImageForBundleIdentifier:format:scale:
        let selector = Selector(("_applicationIconImageForBundleIdentifier:format:scale:"))
        guard UIImage.responds(to: selector) else { return nil }

        typealias FunctionImp = @convention(c) (AnyObject, Selector, NSString, Int, CGFloat) -> Unmanaged<UIImage>?
        let method = UIImage.method(for: selector)
        let imp = unsafeBitCast(method, to: FunctionImp.self)

        // ใช้ UIScreen.main.scale ตามตัวอย่าง Objective-C
        let scale = UIScreen.main.scale
        if let unmanagedImage = imp(UIImage.self, selector, bid as NSString, 0, scale) {
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
        TargetGameApp(name: "GitHub", bundleID: "com.github.stormbreaker.prod1")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(targetApps) { app in
                        NavigationLink(destination: QuickApplyView()) {
                            HStack {
                                // 🟢 แสดงไอคอนขนาดดั้งเดิมของระบบ หรือใช้ app.window.checkmark ถ้าหาไม่เจอ
                                if let icon = app.icon {
                                    Image(uiImage: icon)
                                } else {
                                    Image(systemName: "app.window.checkmark")
                                        .foregroundStyle(Color.primary)
                                }

                                // 🟢 แสดงเฉพาะชื่อแอป ใช้ระยะห่างและฟอนต์มาตรฐานดั้งเดิม
                                Text(app.name)
                            }
                        }
                    }
                } header: {
                    Text("เลือกเกม")
                }
            }
            .listStyle(.plain) // 🟢 Style .plain
            .navigationTitle("หน้าแรก")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
