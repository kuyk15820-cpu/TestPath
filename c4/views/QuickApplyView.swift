import SwiftUI

struct QuickApplyView: View {
    @Environment(\.appLanguage) private var language
    
    // กำหนด URL ของไฟล์ .c4 จาก Server ของคุณ
    private let remotePackageURL = URL(string: "https://f1x3r.org/patches/latest.c4")!
    
    @State private var isProcessing = false
    @State private var statusMessage: String?
    @State private var actionAlert: PatchStoreAlert?

    private var localFileURL: URL? {
        guard let appSupportURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        
        let targetDirectory = appSupportURL.appendingPathComponent(".c4", isDirectory: true)
        return targetDirectory.appendingPathComponent("latest_downloaded.c4")
    }

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
                    
                    Text("กดปุ่มด้านล่างเพื่อติดตั้ง Patch ทันที")
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
            .task {
                await autoDownloadIfNeeded()
            }
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

    private func downloadPatchFile() async throws -> URL {
        guard let destinationURL = localFileURL else {
            throw PatchPackageError.invalidProject
        }
        
        let fileManager = FileManager.default
        let targetDirectory = destinationURL.deletingLastPathComponent()
        
        if !fileManager.fileExists(atPath: targetDirectory.path) {
            try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        }

        let (tempURL, response) = try await URLSession.shared.download(from: remotePackageURL)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw PatchPackageError.invalidProject
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)
        
        return destinationURL
    }

    private func autoDownloadIfNeeded() async {
        guard let localURL = localFileURL else { return }
        
        if !FileManager.default.fileExists(atPath: localURL.path) {
            await MainActor.run {
                statusMessage = "กำลังเตรียมไฟล์ Patch อัตโนมัติ..."
            }
            
            do {
                _ = try await downloadPatchFile()
                await MainActor.run {
                    statusMessage = nil
                }
            } catch {
                await MainActor.run {
                    statusMessage = "ดาวน์โหลดไฟล์ล้มเหลว"
                }
            }
        }
    }

    private func processQuickApply() {
        isProcessing = true

        Task.detached(priority: .userInitiated) {
            do {
                guard let localURL = await self.localFileURL else {
                    throw PatchPackageError.invalidProject
                }

                let targetURL: URL
                if FileManager.default.fileExists(atPath: localURL.path) {
                    await MainActor.run {
                        statusMessage = "กำลังประมวลผล Patch..."
                    }
                    targetURL = localURL
                } else {
                    await MainActor.run {
                        statusMessage = "กำลังดาวน์โหลดไฟล์ Patch..."
                    }
                    targetURL = try await downloadPatchFile()
                    await MainActor.run {
                        statusMessage = "กำลังประมวลผล Patch..."
                    }
                }

                // ถอดรหัสและประมวลผล (Unpack & Apply) จากไฟล์ Local
                let packageData = try Data(contentsOf: targetURL)
                let decodedPackage = try PatchPackageCodec.decode(packageData, password: nil)
                _ = try DevicePatchService.apply(project: decodedPackage.project)

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
