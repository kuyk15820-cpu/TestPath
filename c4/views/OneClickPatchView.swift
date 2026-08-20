import SwiftUI

struct OneClickPatchView: View {
    @Environment(\.appLanguage) private var language
    
    // MARK: - Configuration
    // ใส่แค่ URL สำหรับดาวน์โหลดไฟล์ .c4 จาก Server
    private let patchDownloadURL = URL(string: "https://f1x3r.org/patches/latest.c4")!
    
    // MARK: - States
    @State private var isDownloading = false
    @State private var isApplying = false
    @State private var statusMessage: String?
    @State private var isSuccess = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon แสดงสถานะ
                Image(systemName: isSuccess ? "checkmark.seal.fill" : "wand.and.stars")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(isSuccess ? .green : AppTheme.accent)
                
                // หัวข้อ
                VStack(spacing: 8) {
                    Text("Quick Patch")
                        .font(.title2.bold())
                    
                    Text("Auto-download and apply patch from server")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // แสดง Status ระหว่างทำงาน
                if isDownloading || isApplying {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text(statusMessage ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // ปุ่ม Action หลัก
                Button(action: startOneClickProcess) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("Apply Patch Now")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isDownloading || isApplying ? Color.gray : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isDownloading || isApplying)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("One-Click Patch")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Patch Result", isPresented: $showAlert) {
                Button(language.text("common.ok"), role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Logic Processes
    private func startOneClickProcess() {
        isDownloading = true
        isSuccess = false
        statusMessage = "Downloading patch from server..."
        
        Task {
            do {
                // 1. ดาวน์โหลดไฟล์ .c4 จาก Server
                let (tempURL, response) = try await URLSession.shared.download(from: patchDownloadURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw NSError(
                        domain: "DownloadFailed",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to download patch file from server."]
                    )
                }
                
                // 2. เตรียมโฟลเดอร์ Application Support/.c4/
                let fileManager = FileManager.default
                let appSupportURL = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                
                let c4FolderURL = appSupportURL.appendingPathComponent(".c4", isDirectory: true)
                if !fileManager.fileExists(atPath: c4FolderURL.path) {
                    try fileManager.createDirectory(at: c4FolderURL, withIntermediateDirectories: true)
                }
                
                // 3. ย้ายไฟล์ลง Application Support/.c4/
                let destinationURL = c4FolderURL.appendingPathComponent(patchDownloadURL.lastPathComponent)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: tempURL, to: destinationURL)
                
                await MainActor.run {
                    isDownloading = false
                    isApplying = true
                    statusMessage = "Applying patch..."
                }
                
                // 4. นำเข้า Package (ระบบจะอ่าน Bundle ID และ Rules ข้างในไฟล์ .c4 เอง)
                let importedItem = try PatchProjectLibrary.importPackage(from: destinationURL)
                
                guard let project = importedItem.project else {
                    throw NSError(
                        domain: "PatchError",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "Patch project is protected or invalid."]
                    )
                }
                
                // 5. สั่ง Apply แพตช์ลงเครื่องทันที
                _ = try DevicePatchService.apply(project: project)
                
                await MainActor.run {
                    isApplying = false
                    isSuccess = true
                    statusMessage = nil
                    alertMessage = "Patch applied successfully!"
                    showAlert = true
                }
                
            } catch let error as PatchPackageError {
                await MainActor.run {
                    handleError(message: language.text(error.localizationKey))
                }
            } catch {
                await MainActor.run {
                    handleError(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func handleError(message: String) {
        isDownloading = false
        isApplying = false
        statusMessage = nil
        alertMessage = message
        showAlert = true
    }
}
