import SwiftUI

struct TargetGameView: View {
    private let targetApps: [TargetGameApp] = [
        TargetGameApp(bundleID: "com.dts.freefireth"),
        TargetGameApp(bundleID: "com.dts.freefiremax")        
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(targetApps) { app in
                        NavigationLink(destination: QuickApplyView(selectedApp: app)) {
                            HStack(spacing: 12) {
                                if let icon = app.icon {
                                    Image(uiImage: icon)
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "app.window.checkmark")
                                        .font(.title2)
                                        .foregroundStyle(Color.primary)
                                }

                                Text(app.name)
                                    .font(.headline)
                                    .foregroundStyle(app.isInstalled ? Color.primary : Color.secondary)
                            }
                        }
                        .disabled(!app.isInstalled) // 🟢 ปิดการเปิดเข้าไปทำงานเมื่อยังไม่ได้ติดตั้งแอป
                        .opacity(app.isInstalled ? 1.0 : 0.5) // 🟢 ปรับความจางของแถบรายการหากไม่ได้ติดตั้ง
                    }
                } header: {
                    Text("เลือกเกม")
                }
            }
            .listStyle(.plain)
            .navigationTitle("หน้าแรก")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
