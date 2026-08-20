import SwiftUI

// MARK: - Models

struct QuickPatchItem: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let downloadUrl: String
}

struct QuickApplyView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState

    // ⚠️ URL ของ catalog.json บน Server
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
        NavigationStack {
            List {
                // Section 1: ข้อมูลตัวเครื่อง (ย้ายมาจาก Dashboard เดิม)
                deviceSection

                // Section 2: รายการ Patch Catalog
                patchCatalogSection
            }
            .navigationTitle("Quick Patch")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
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
                    .disabled(processingItemID != nil)
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
            if isLoadingCatalog {
                HStack {
                    Spacer()
                    ProgressView("กำลังโหลดรายการ Patch...")
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if patchItems.isEmpty {
                ContentUnavailableView(
                    "ไม่พบรายการ Patch",
                    systemImage: "exclamationmark.triangle",
                    description: Text("ไม่สามารถดึงข้อมูลจาก Server ได้")
                )
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

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
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
                .disabled(processingItemID != nil)
            }
        }
        .padding(.vertical, 4)
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

        let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw PatchPackageError.invalidProject
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)
    }

    private func fetchCatalog() async {
        isLoadingCatalog = true
        defer { isLoadingCatalog = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: catalogURL)
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
                    if !FileManager.default.fileExists(atPath: applyURL.path) {
                        await MainActor.run {
                            self.statusMessage = "กำลังดาวน์โหลด \(item.title)..."
                        }
                        try await self.downloadFile(from: item.downloadUrl, to: applyURL)
                    }

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
