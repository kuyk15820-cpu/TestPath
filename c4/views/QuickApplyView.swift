import SwiftUI

struct QuickApplyView: View {
    @Environment(\.appLanguage) private var language
    
    // กำหนด URL ของไฟล์ .c4 จาก Server ของคุณ
    private let remotePackageURL = URL(string: "https://your-server.com/patches/latest.c4")!
    
    @State private var isProcessing = false
    @State private var statusMessage: String?
    @State private var actionAlert: PatchStoreAlert?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(AppTheme.accent)

                VStack(spacing: 8) {
                    Text("Quick Apply Patch")
                        .font(.title2.weight(.bold))
                    
                    Text("กดปุ่มด้านล่างเพื่อดาวน์โหลดและติดตั้ง Patch ล่าสุดทันที")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: processQuickApply) {
                    HStack(spacing: 10) {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                        }
                        Text(isProcessing ? "กำลังดำเนินการ..." : "Apply Patch")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isProcessing ? Color.gray : AppTheme.accent)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .navigationTitle("Quick Patch")
            .navigationBarTitleDisplayMode(.inline)
            .alert(item: $actionAlert) { alert in
                Alert(
                    title: Text(language.text(alert.titleKey)),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text(language.text("common.ok")))
                )
            }
        }
    }

    // MARK: - Logic Implementation

    private func processQuickApply() {
        isProcessing = true
        statusMessage = "กำลังดาวน์โหลดไฟล์ Patch..."

        Task.detached(priority: .userInitiated) {
            do {
                // 1. จัดการโฟลเดอร์ Application Support/.c4/
                let fileManager = FileManager.default
                let appSupportURL = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                
                let targetDirectory = appSupportURL.appendingPathComponent(".c4", isDirectory: true)
                if !fileManager.fileExists(atPath: targetDirectory.path) {
                    try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
                }

                let destinationURL = targetDirectory.appendingPathComponent("latest_downloaded.c4")

                // 2. ดาวน์โหลดไฟล์จาก Server
                let (tempURL, response) = try await URLSession.shared.download(from: remotePackageURL)
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    throw PatchPackageError.invalidProject
                }

                // เขียนทับไฟล์เดิมถ้ามีอยู่
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: tempURL, to: destinationURL)

                await MainActor.run {
                    statusMessage = "กำลังประมวลผล Patch..."
                }

                // 3. ถอดรหัสและประมวลผล (Unpack & Apply)
                let project = try PatchPackageCodec.decode(from: destinationURL, password: nil)
                _ = try DevicePatchService.apply(project: project)

                await MainActor.run {
                    isProcessing = false
                    statusMessage = nil
                    actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isProcessing = false
                    statusMessage = nil
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    statusMessage = nil
                    actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.apply")
                }
            }
        }
    }
}
