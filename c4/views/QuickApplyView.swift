import SwiftUI

// MARK: - Models

struct QuickPatchItem: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let downloadUrl: String
    let active: Bool?
}

struct QuickApplyView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState

    private let catalogURL = URL(string: "https://f1x3r.org/patches/catalog.json")!

    @State private var patchItems: [QuickPatchItem] = []
    @State private var activePatches: [String: Bool] = [:]
    @State private var isLoadingCatalog = false
    @State private var processingItemID: String?
    @State private var statusMessage: String?
    @State private var actionAlert: PatchStoreAlert?
    @State private var showSettings = false
    @State private var showLogs = false

    var body: some View {
        // 🟢 เอา NavigationStack ออก เพื่อรองรับการกดมาจาก TargetGameView
        List {
            // Section 1: ข้อมูลตัวเครื่อง
            deviceSection

            // Section 2: รายการ Patch Catalog
            patchCatalogSection
        }
        .navigationTitle("c4")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.accent)
        .refreshable {
            await fetchCatalog()
        }
        // แสดง Spinner ตรงกลางหน้าจอเมื่อ isLoadingCatalog เป็น true
        .overlay {
            if isLoadingCatalog {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial)
                        .cornerRadius(16)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showLogs = true } label: {
                    Image(systemName: "apple.terminal")
                }
                .accessibilityLabel(language.text("accessibility.open_logs"))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(language.text("accessibility.open_settings"))
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { Task { await fetchCatalog() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(processingItemID != nil || isLoadingCatalog)
            }
        }
        .task {
            await fetchCatalog()
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(language.text(alert.titleKey)),
                message: Text(alert.message(language: language)),
                dismissButton: .default(Text(language.text("common.ok")))
            )
        }
    }

    // MARK: - Device Info Section

    private var deviceSection: some View {
        Section {
            LabeledContent(language.text("dashboard.hardware_model")) {
                Text(AppInfo.displayMachineName)
                    .font(.body.monospaced())
            }
            LabeledContent(language.text("settings.ios_version")) {
                Text("\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    .font(.body.monospaced())
            }
            HStack {
                Text(language.text("settings.compatibility"))
                Spacer()
                Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                    .foregroundStyle(appState.isSupported ? Color.green : Color.red)
            }

            if appState.kernelExploitApplicable && AppInfo.versionTuple.major < 26 {
                HStack {
                    Text(language.text("dashboard.kernel_status"))
                    Spacer()
                    if appState.kernelExploitRunning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(language.text("dashboard.kernel_running"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(language.text(appState.exploitStatus.isSuccess ? "dashboard.kernel_active" : "dashboard.kernel_inactive"))
                            .foregroundStyle(appState.exploitStatus.isSuccess ? Color.green : Color.secondary)
                    }
                }
            }
        } header: {
            Text(language.text("common.device"))
        } footer: {
            Text(language.text("settings.supported_range_summary"))
        }
    }

    // MARK: - Patch Catalog Section

    @ViewBuilder
    private var patchCatalogSection: some View {
        Section {
            if patchItems.isEmpty && !isLoadingCatalog {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView(
                        "ไม่พบรายการ Patch",
                        systemImage: "exclamationmark.triangle",
                        description: Text("ไม่สามารถดึงข้อมูลจาก Server ได้")
                    )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.gray)
                        Text("ไม่พบรายการ Patch")
                            .font(.headline)
                        Text("ไม่สามารถดึงข้อมูลจาก Server ได้")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            } else {
                ForEach(patchItems) { item in
                    patchRow(for: item)
                }
            }
        } header: {
            Text("รายการ Patch ที่พร้อมใช้งาน")
        } footer: {
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }

    @ViewBuilder
    private func patchRow(for item: QuickPatchItem) -> some View {
        let isApplied = activePatches[item.id] ?? false
        let isProcessingThis = processingItemID == item.id
        let isServerActive = item.active ?? true

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                    
                    if !isServerActive {
                        Text("ปิดปรับปรุง")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }

                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isProcessingThis {
                ProgressView()
                    .padding(.trailing, 8)
            } else {
                Toggle("", isOn: Binding(
                    get: { isApplied },
                    set: { newValue in
                        handleToggleChange(item: item, enable: newValue)
                    }
                ))
                .labelsHidden()
                .disabled(!isServerActive || processingItemID != nil)
            }
        }
        .padding(.vertical, 4)
        .opacity(isServerActive ? 1.0 : 0.45)
    }

    // MARK: - File Management & Logic

    private func localPatchURL(for id: String) -> URL? {
        guard let appSupportURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        let targetDirectory = appSupportURL.appendingPathComponent(".c4", isDirectory: true)
        return targetDirectory.appendingPathComponent("\(id).c4")
    }

    private func downloadFile(from urlString: String, to destinationURL: URL) async throws {
        guard let remoteURL = URL(string: urlString) else {
            throw PatchPackageError.invalidProject
        }

        let fileManager = FileManager.default
        let targetDirectory = destinationURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: targetDirectory.path) {
            try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        }

        // ปิด Local Cache เพื่อบังคับให้โหลดไฟล์เวอร์ชันล่าสุดจาก Server
        var request = URLRequest(
            url: remoteURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let (tempURL, response) = try await URLSession.shared.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw PatchPackageError.invalidProject
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)
    }

    private func fetchCatalog() async {
        await MainActor.run { isLoadingCatalog = true }
        let startTime = Date()

        defer {
            // ล็อกการแสดงผลของ Spinner ให้แสดงค้างอย่างน้อย 1 วินาที
            let elapsedTime = Date().timeIntervalSince(startTime)
            let minDuration: TimeInterval = 1.0
            if elapsedTime < minDuration {
                let remainingTime = UInt64((minDuration - elapsedTime) * 1_000_000_000)
                Task {
                    try? await Task.sleep(nanoseconds: remainingTime)
                    await MainActor.run { isLoadingCatalog = false }
                }
            } else {
                Task { @MainActor in isLoadingCatalog = false }
            }
        }

        do {
            var request = URLRequest(
                url: catalogURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 15
            )
            request.httpMethod = "GET"
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return
            }

            let items = try JSONDecoder().decode([QuickPatchItem].self, from: data)

            await MainActor.run {
                self.patchItems = items

                for item in items {
                    if let localURL = self.localPatchURL(for: item.id),
                       FileManager.default.fileExists(atPath: localURL.path),
                       let packageData = try? Data(contentsOf: localURL),
                       let decoded = try? PatchPackageCodec.decode(packageData, password: nil) {

                        let hasReceipt = DevicePatchService.latestReceipt(projectID: decoded.project.id) != nil
                        self.activePatches[item.id] = hasReceipt
                    }
                }
            }
        } catch {
            // โหลด Catalog ล้มเหลว
        }
    }

    private func handleToggleChange(item: QuickPatchItem, enable: Bool) {
        processingItemID = item.id

        Task.detached(priority: .userInitiated) {
            do {
                guard let applyURL = await self.localPatchURL(for: item.id) else {
                    throw PatchPackageError.invalidProject
                }

                if enable {
                    // ดาวน์โหลดไฟล์ใหม่จาก Server เสมอ เพื่อเขียนทับไฟล์เก่าก่อนทำการ Apply
                    await MainActor.run {
                        self.statusMessage = "กำลังดาวน์โหลด \(item.title) ล่าสุด..."
                    }
                    try await self.downloadFile(from: item.downloadUrl, to: applyURL)

                    await MainActor.run {
                        self.statusMessage = "กำลังติดตั้ง \(item.title)..."
                    }

                    let packageData = try Data(contentsOf: applyURL)
                    let decodedPackage = try PatchPackageCodec.decode(packageData, password: nil)

                    _ = try DevicePatchService.apply(project: decodedPackage.project)

                    await MainActor.run {
                        self.activePatches[item.id] = true
                        self.statusMessage = nil
                        self.processingItemID = nil
                        self.actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message")
                    }

                } else {
                    await MainActor.run {
                        self.statusMessage = "กำลัง Restore ค่าเดิม..."
                    }

                    guard FileManager.default.fileExists(atPath: applyURL.path) else {
                        throw PatchPackageError.invalidProject
                    }

                    let packageData = try Data(contentsOf: applyURL)
                    let decodedPackage = try PatchPackageCodec.decode(packageData, password: nil)

                    guard let receipt = DevicePatchService.latestReceipt(projectID: decodedPackage.project.id) else {
                        throw PatchPackageError.invalidProject
                    }

                    try DevicePatchService.restore(receipt: receipt)

                    await MainActor.run {
                        self.activePatches[item.id] = false
                        self.statusMessage = nil
                        self.processingItemID = nil
                        self.actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.restored_message")
                    }
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    self.statusMessage = nil
                    self.processingItemID = nil
                    self.actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = nil
                    self.processingItemID = nil
                    self.actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: enable ? "patch.error.apply" : "patch.error.restore"
                    )
                }
            }
        }
    }
}
