import SwiftUI

// MARK: - Models

struct QuickPatchItem: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let downloadUrl: String
    let active: Bool?
}

// MARK: - QuickApplyView

struct QuickApplyView: View {
    let selectedApp: TargetGameApp

    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState

    private let catalogURL = URL(string: "https://f1x3r.org/patches/catalog.json")!

    @State private var patchItems: [QuickPatchItem] = []
    @State private var activePatches: [String: Bool] = [:]
    @State private var isLoadingCatalog = false
    @State private var processingItemID: String?
    @State private var isRestoringAll = false
    @State private var actionAlert: PatchStoreAlert?
    @State private var showSettings = false
    @State private var showLogs = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                if !isLoadingCatalog {
                    patchCatalogSection
                }
            }
            .listStyle(.plain)
            
            if !patchItems.isEmpty && !isLoadingCatalog {
                bottomActionButtons
            }
        }
        .navigationTitle(selectedApp.name)
        .navigationBarTitleDisplayMode(.large)
        .tint(AppTheme.accent)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showLogs = true } label: {
                    Image(systemName: "apple.terminal")
                }
                .accessibilityLabel("เปิดบันทึกประวัติ (Logs)")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("เปิดการตั้งค่า")
            }
        }
        .task {
            await fetchCatalog()
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(alert.titleKey == "common.done" ? "สำเร็จ" : (alert.titleKey == "common.failed" ? "ล้มเหลว" : alert.titleKey)),
                message: Text(alert.message(language: language)),
                dismissButton: .default(Text("ตกลง"))
            )
        }
    }

    // MARK: - Patch Catalog Section

    @ViewBuilder
    private var patchCatalogSection: some View {
        Section {
            ForEach(patchItems) { item in
                patchRow(for: item)
            }
        } header: {
            Text("รายการ Patch ที่พร้อมใช้งาน (\(patchItems.count))")
        }
    }

    @ViewBuilder
    private func patchRow(for item: QuickPatchItem) -> some View {
        let isApplied = activePatches[item.id] ?? false
        let isServerActive = item.active ?? true

        Button {
            if isServerActive && processingItemID == nil && !isRestoringAll {
                handleToggleChange(item: item, enable: !isApplied)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        
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

                ZStack {
                    if isApplied {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(AppTheme.accent)
                    } else {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 28, height: 28, alignment: .center)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .disabled(!isServerActive || processingItemID != nil || isRestoringAll)
        .opacity(isServerActive ? 1.0 : 0.45)
    }

    // MARK: - Bottom Action Buttons

    private var bottomActionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    restoreAllPatches()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.headline)
                        
                        Text("Restore ค่าเดิม")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white, lineWidth: 1.5)
                    )
                    .clipShape(Capsule())
                }
                .disabled(processingItemID != nil || isRestoringAll || isLoadingCatalog)

                Button {
                    openGame()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller")
                            .font(.headline)
                        Text("เปิดเกม")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white, lineWidth: 1.5)
                    )
                    .clipShape(Capsule())
                }
                .disabled(processingItemID != nil || isRestoringAll || isLoadingCatalog)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - File Management & Logic

    private func openGame() {
        let success = AppLauncher.launchApp(bundleID: selectedApp.bundleID)
        if !success {
            actionAlert = PatchStoreAlert(titleKey: "ล้มเหลว", messageKey: "ไม่สามารถเปิดแอปพลิเคชัน \(selectedApp.name) ได้")
        }
    }

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

    private func fetchCatalog(force: Bool = false) async {
        if !patchItems.isEmpty && !force { return }

        await MainActor.run { 
            isLoadingCatalog = true 
            HUDHelper.show(message: "") // ส่ง String ว่างเพื่อไม่ให้แสดงข้อความ
        }
        let startTime = Date()

        do {
            var request = URLRequest(
                url: catalogURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 15
            )
            request.httpMethod = "GET"
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
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
            }
        } catch {
            print("Fetch catalog failed: \(error)")
        }

        let elapsedTime = Date().timeIntervalSince(startTime)
        let minDuration: TimeInterval = 1.0
        if elapsedTime < minDuration {
            let remainingTime = UInt64((minDuration - elapsedTime) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: remainingTime)
        }

        await MainActor.run {
            self.isLoadingCatalog = false
            HUDHelper.hide()
        }
    }

    // MARK: - Error Message Translator

    // เติม nonisolated เพื่อให้สามารถเรียกใช้จาก Background Task ได้โดยไม่ต้องผ่าน MainActor
    private nonisolated func translatePatchError(_ error: PatchPackageError) -> String {
        switch error.localizationKey {
        case "patch.error.invalid_project":
            return "โปรดตรวจสอบชื่อโปรเจกต์, Bundle เป้าหมาย และเนื้อหาใน Workspace"
        case "patch.error.app_unavailable":
            return "ไม่พบหรือไม่สามารถเปิดแอป Bundle \(selectedApp.bundleID) ได้"
        case "patch.error.apply":
            return "ไม่สามารถใช้งาน Patch ได้ ระบบได้ทำการย้อนคืนการเขียนไฟล์ก่อนหน้าทั้งหมดแล้ว"
        case "patch.error.duplicate_target":
            return "มีเงื่อนไข (Rules) ซ้ำซ้อนที่ชี้ไปที่ไฟล์แอปเดียวกัน"
        case "patch.error.invalid_bundle":
            return "โปรดระบุ App Bundle Identifier ที่ถูกต้อง ไม่ใช่ Container UUID"
        case "patch.error.password_or_corrupt":
            return "รหัสผ่านไม่ถูกต้อง หรือไฟล์ Package ถูกดัดแปลง/เสียหาย"
        case "patch.error.restore":
            return "ไม่สามารถคืนค่าไฟล์ต้นฉบับได้อย่างปลอดภัย ไม่มีเป้าหมายที่ไม่ได้รับการยืนยันถูกเขียนทับ"
        case "patch.error.size_limit":
            return "ไฟล์ Package หรือไฟล์ที่นำมาแทนที่ มีขนาดเกินขีดจำกัดที่รองรับ"
        default:
            return error.localizationKey
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
                    try await self.downloadFile(from: item.downloadUrl, to: applyURL)

                    let packageData = try Data(contentsOf: applyURL)
                    let decodedPackage = try PatchPackageCodec.decode(packageData, password: nil)

                    _ = try DevicePatchService.apply(project: decodedPackage.project)

                    await MainActor.run {
                        self.activePatches[item.id] = true
                        self.processingItemID = nil
                        self.actionAlert = PatchStoreAlert(titleKey: "สำเร็จ", messageKey: "นำเงื่อนไข Patch ทั้งหมดไปใช้งาน และสำรองไฟล์ต้นฉบับเรียบร้อยแล้ว")
                    }

                } else {
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
                        self.processingItemID = nil
                        self.actionAlert = PatchStoreAlert(titleKey: "สำเร็จ", messageKey: "คืนค่าไฟล์ต้นฉบับเรียบร้อยแล้ว")
                    }
                }
            } catch let error as PatchPackageError {
                let message = self.translatePatchError(error)
                await MainActor.run {
                    self.processingItemID = nil
                    self.actionAlert = PatchStoreAlert(
                        titleKey: "ล้มเหลว",
                        messageKey: message
                    )
                }
            } catch {
                await MainActor.run {
                    self.processingItemID = nil
                    self.actionAlert = PatchStoreAlert(
                        titleKey: "ล้มเหลว",
                        messageKey: enable ? "ไม่สามารถใช้งาน Patch ได้ ระบบได้ทำการยกเลิกการเขียนไฟล์ก่อนหน้าทั้งหมดแล้ว" : "ไม่สามารถคืนค่าไฟล์ต้นฉบับได้อย่างปลอดภัย ไม่มีเป้าหมายที่ไม่ได้รับการยืนยันถูกเขียนทับ"
                    )
                }
            }
        }
    }

    private func restoreAllPatches() {
        isRestoringAll = true

        Task.detached(priority: .userInitiated) {
            var count = 0
            let currentItems = await self.patchItems

            for item in currentItems {
                guard let applyURL = await self.localPatchURL(for: item.id),
                      FileManager.default.fileExists(atPath: applyURL.path),
                      let packageData = try? Data(contentsOf: applyURL),
                      let decodedPackage = try? PatchPackageCodec.decode(packageData, password: nil),
                      let receipt = DevicePatchService.latestReceipt(projectID: decodedPackage.project.id) else {
                    continue
                }

                if (try? DevicePatchService.restore(receipt: receipt)) != nil {
                    count += 1
                    await MainActor.run {
                        self.activePatches[item.id] = false
                    }
                }
            }

            let finalCount = count
            await MainActor.run {
                self.isRestoringAll = false
                self.actionAlert = PatchStoreAlert(
                    titleKey: "สำเร็จ",
                    messageKey: finalCount > 0 ? "คืนค่าไฟล์ต้นฉบับเรียบร้อยแล้ว" : "ตกลง"
                )
            }
        }
    }
}
