//
//  RightSightApp.swift
//  RightSight
//
//  Created by 李旭 on 2024/4/4.
//
import AppKit
import ApplicationServices
import Foundation
import SwiftUI
import SwiftData

import FinderSync
import os.log

extension NSNotification.Name {
    static let menuConfigShouldUpdate = NSNotification.Name("RightSight.menuConfigShouldUpdate")
}

@main
struct RightSightApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(Key.showMenuBarExtra, store: .group) private var showMenuBarExtra = true

    @Environment(\.openWindow) var openWindow

    @AppLog(category: "main")
    private var logger
    let messager = Messager.shared

    @StateObject var appState = AppState.shared

    @StateObject private var updateManager = UpdateManager(
        owner: "dmarcin1",
        repo: "RightSight",
        currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    )

    var body: some Scene {
        SettingsWindow(appState: appState, onAppear: {})
            .defaultAppStorage(.group)
            .environmentObject(updateManager)
            .modelContainer(SharedDataManager.sharedModelContainer)

        // showMenuBarExtra 为 true 时显示菜单条
        MenuBarExtra(
            "RightSight", image: "MenuBar", isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
        }
        .defaultAppStorage(.group)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    @AppLog(category: "AppDelegate")
    private var logger

    var appState: AppState = .shared
    var pluginRunning: Bool = false
    var heartBeatCount = 0

    let messager = Messager.shared
    var showMenuBarExtra = UserDefaults.group.bool(forKey: Key.showMenuBarExtra)
    var showInDock = UserDefaults.group.bool(forKey: Key.showInDock)
    var settingsWindow: NSWindow!
    private var cutFileBuffer = FileCutBuffer()

    // MARK: - 重连机制状态

    /// 菜单配置快照（真相源）
    private var lastMenuSnapshot: Data?
    /// 菜单版本号，用于防重复和防乱序
    private var menuVersion: Int = 0
    /// 最大重试次数
    private let maxRunningMessageRetryCount: Int = 6

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("applicationDidFinishLaunching called")

        // 监听菜单配置更新通知（设置页 toggle 动作时触发）
        NotificationCenter.default.addObserver(
            forName: .menuConfigShouldUpdate,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.sendMenuConfigurationUpdate()
            }
        }

        // 在 app 启动后执行的函数

        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }

        // 执行数据迁移
        // TODO: 需要在 Xcode 中将 DataMigrationManager.swift 添加到 RightSight target 后取消注释
        Task { @MainActor in
            do {
//                if DataMigrationManager.shared.needsMigration() {
//                    logger.info("检测到旧数据，开始迁移...")
//
//                    // 备份现有数据
//                    if let backupURL = DataMigrationManager.shared.backupUserDefaults() {
//                        logger.info("数据已备份到：\(backupURL.path)")
//                    }
//
//                    // 执行迁移
//                    let context = ModelContext(SharedDataManager.sharedModelContainer)
//                    try await DataMigrationManager.shared.migrateFromUserDefaults(context: context)
//
//                    logger.info("数据迁移成功完成")
//                } else {
//                    logger.info("无需数据迁移")
//                }

                // 初始化默认数据
                let context = ModelContext(SharedDataManager.sharedModelContainer)
                await SharedDataManager.initializeDefaultData(context: context)
                appState.refresh()
            }

            // Preload icons for all apps to improve performance
            Task { @MainActor in
                IconCache.shared.preloadIcons(for: appState.apps.map { $0.url })
            }

            // Register message handlers using type-safe API
            logger.info("Registering message handlers")
            messager.onExtensionMessage(.click) { [weak self] data in
                guard let self = self else { return }
                if let event: ClickEventPayload = messager.decodeSignedData(data) {
                    Task { @MainActor in
                        await self.handleClickEvent(event)
                    }
                } else {
                    logger.warning("Invalid click event data")
                }
            }

            messager.onExtensionMessage(.heartbeat) { [weak self] _ in
                guard let self = self else { return }
                logger.debug("Received heartbeat from extension")
                pluginRunning = true
                sendMenuConfigurationUpdate()
            }

            // 处理 Extension 请求菜单配置
            messager.onExtensionMessage(.requestConfig) { [weak self] _ in
                guard let self = self else { return }
                logger.info("Received menu config request from extension")
                self.sendMenuConfigurationUpdate()
            }

            // 启动心跳超时检测
            startHeartbeatMonitoring()
            // 启动 running 消息重试机制
            startRunningMessageRetry()

            sendObserveDirMessage()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        messager.sendQuitNotification()
        logger.info("applicationWillTerminate")
    }

    // MARK: - Message Handlers

    func sendObserveDirMessage() {
        let directories: [String] = []
        messager.sendRunningNotification(directories: directories)
        if !pluginRunning {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                sendObserveDirMessage()
            }
        }
    }

    func sendMenuConfigurationUpdate() {
        // Build menu config from AppState
        let actionMenuItems = appState.actions.filter(\.enabled).map { $0.toActionMenuItem() }
        let appMenuItems = appState.apps.map { $0.toAppMenuItem() }
        let newFileMenuItems = appState.newFiles.filter(\.enabled).map { NewFileMenuItem(id: $0.id, name: $0.name, ext: $0.ext, icon: $0.icon) }
        let commonDirMenuItems = appState.showCommonDirs ? appState.cdirs.map { CommonDirMenuItem(id: $0.id, name: $0.displayName, icon: $0.icon, url: $0.url.path) } : []

        // 更新版本号
        menuVersion += 1

        let config = MenuConfigPayload(
            version: menuVersion,
            actions: actionMenuItems,
            apps: appMenuItems,
            newFiles: newFileMenuItems,
            commonDirs: commonDirMenuItems,
            actionsCollapsed: appState.foldActionsMenu,
            appsCollapsed: appState.foldAppsMenu,
            newFilesCollapsed: appState.foldNewFileMenu,
            commonDirsCollapsed: appState.foldCommonDirMenu
        )

        // 更新快照
        lastMenuSnapshot = try? JSONEncoder().encode(config)
        logger.debug("Menu config version updated to \(self.menuVersion)")

        // Send using type-safe API
        messager.sendMenuConfig(config)
        logger.debug("Sent menu configuration to extension: \(actionMenuItems.count) actions, \(appMenuItems.count) apps")
    }

    func handleClickEvent(_ event: ClickEventPayload) async {
        logger.debug("Handling click event: \(event.itemId) type=\(event.itemType.rawValue) trigger=\(event.trigger.rawValue) target=\(event.target)")

        switch event.itemType {
        case .app:
            self.openApp(rid: event.itemId, target: event.target)
        case .action:
            await self.actionHandler(rid: event.itemId, target: event.target, trigger: event.trigger.rawValue)
        case .newFile:
            await self.createFile(rid: event.itemId, target: event.target)
        case .commonDir:
            self.openCommonDirs(target: event.target)
        }
    }

    // MARK: - 重连机制

    /// 心跳监控 Task（可取消）
    private var heartbeatMonitorTask: Task<Void, Never>?

    /// 启动心跳监控（15 秒超时检测）
    private func startHeartbeatMonitoring() {
        heartbeatMonitorTask?.cancel()
        heartbeatMonitorTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                if pluginRunning {
                    pluginRunning = false
                } else {
                    logger.warning("Heartbeat timeout detected, triggering reconnection")
                    performReconnection()
                }
            }
        }
    }

    /// 启动 running 消息重试机制（每 5 秒发送一次，持续 30 秒）
    private func startRunningMessageRetry() {
        Task { @MainActor in
            for retryCount in 0..<self.maxRunningMessageRetryCount {
                try? await Task.sleep(for: .seconds(5))
                guard !self.pluginRunning else { break }
                self.messager.sendRunningNotification()
                self.logger.debug("Sending running message retry \(retryCount + 1)/\(self.maxRunningMessageRetryCount)")
            }
            logger.debug("Running message retry completed")
        }
    }

    /// 执行重连：发送菜单配置请求
    @MainActor private func performReconnection() {
        logger.debug("Performing reconnection: requesting menu config from main app")
        // 重置 pluginRunning 状态，等待心跳恢复
        pluginRunning = false
    }

    // MARK: - Helper Methods

    func openCommonDirs(target: [String]) {
        logger.debug("开始打开常用目录，目标路径：\(target)")

        for dirPath in target {
            let path = dirPath.removingPercentEncoding ?? dirPath
            let url = URL(fileURLWithPath: path, isDirectory: true)

            logger.debug("正在打开目录：\(path)")
            NSWorkspace.shared.open(url)
        }

        logger.debug("常用目录打开操作完成")
    }

    private func revealInFinderAndRename(_ fileURL: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [logger] in
            guard let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
                return
            }
            finderApp.activate(options: .activateIgnoringOtherApps)

            guard PermissionChecker.hasAccessibilityPermission() else {
                logger.debug("Accessibility permission not granted; skipping auto-rename trigger for \(fileURL.path)")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                guard let frontApp = NSWorkspace.shared.frontmostApplication,
                      frontApp.bundleIdentifier == "com.apple.finder" else {
                    logger.debug("Finder is not frontmost, skipping synthetic Return key event")
                    return
                }

                let keyCodeReturn: CGKeyCode = 36
                let source = CGEventSource(stateID: .hidSystemState)
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeReturn, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeReturn, keyDown: false)
                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
            }
        }
    }

    func openApp(rid: String, target: [String]) {
        guard let rcitem = appState.getAppItem(rid: rid) else {
            logger.warning("when openapp, but not have app \(rid)")
            return
        }

        let appUrl = rcitem.url
        logger.debug("openApp: rid=\(rid) app=\(appUrl.path) target=\(target)")

        let targetURLs = target.compactMap { rawPath -> URL? in
            let path = rawPath.removingPercentEncoding ?? rawPath
            guard !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path)
        }

        guard !targetURLs.isEmpty else { return }

        let config = NSWorkspace.OpenConfiguration()
        if !rcitem.arguments.isEmpty {
            config.arguments = rcitem.arguments
        }
        if !rcitem.environment.isEmpty {
            config.environment = rcitem.environment
        }

        let logger = self.logger
        NSWorkspace.shared.open(targetURLs, withApplicationAt: appUrl, configuration: config) { runningApp, error in
            if let error = error {
                logger.error("Error opening with application: \(error.localizedDescription)")
            } else if let runningApp = runningApp {
                logger.debug("Successfully opened with application: \(runningApp.localizedName ?? "Unknown")")
            }
        }
    }

    // MARK: - Helper Methods

    func getUniqueFilePath(dir: String, ext: String) -> String {
        let fileManager = FileManager.default
        let dirURL = URL(fileURLWithPath: dir.hasSuffix("/") ? String(dir.dropLast()) : dir)
        let baseFileName = AppLocalization.localized("Untitled")
        var filePath = dirURL.appendingPathComponent("\(baseFileName)\(ext)").path
        var counter = 1

        while fileManager.fileExists(atPath: filePath) {
            let newFileName = "\(baseFileName)\(counter)"
            filePath = dirURL.appendingPathComponent("\(newFileName)\(ext)").path
            counter += 1
        }

        return filePath
    }

    private func targetDirectoryForNewFile(_ target: [String]) -> String? {
        guard let rawPath = target.first else { return nil }
        let path = rawPath.removingPercentEncoding ?? rawPath
        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return path
            }
            return URL(fileURLWithPath: path).deletingLastPathComponent().path
        }

        return path
    }


    func actionHandler(rid: String, target: [String], trigger: String) async {
        guard let rcitem = appState.getActionItem(rid: rid) else {
            logger.warning("when createFile, but not have fileType ")
            return
        }

        switch rcitem.id {
        case "copy-path":
            copyPath(target)
        case "delete-direct":
            await deleteFoldorFile(target, trigger)
        case "unhide":
            await unhideFilesAndDirs(target, trigger)
        case "hide":
            await hideFilesAndDirs(target, trigger)
        case "airdrop":
            await showAirDrop(target, trigger)
        case "convert-images":
            await convertImages(target, trigger)
        case "cut-files":
            await cutFiles(target, trigger)
        case "paste-files":
            await pasteFiles(target, trigger)
        case "copy-to":
            await transferFilesToChosenFolder(target, trigger, operation: .copy)
        case "move-to":
            await transferFilesToChosenFolder(target, trigger, operation: .move)
        default:
            logger.warning("no action id matched")
        }
    }

    func cutFiles(_ target: [String], _ trigger: String) async {
        guard trigger == "ctx-items" else {
            showFileTransferAlert(
                title: AppLocalization.localized("Select files first"),
                message: AppLocalization.localized("Select one or more files or folders in Finder, then choose Cut Files."),
                style: .informational
            )
            return
        }

        let selectedURLs = existingUnprotectedURLs(from: target)
        let authorizedURLs = await authorizedSourceURLs(selectedURLs)
        guard !authorizedURLs.isEmpty else {
            showFileTransferAlert(
                title: AppLocalization.localized("No files available"),
                message: AppLocalization.localized("The selected items cannot be cut or access was not granted."),
                style: .warning
            )
            return
        }

        cutFileBuffer.replace(with: authorizedURLs)
        showFileTransferAlert(
            title: AppLocalization.localized("Files cut"),
            message: String(
                format: AppLocalization.localized("%d item(s) are ready to move. Right-click the destination folder and choose Paste."),
                authorizedURLs.count
            ),
            style: .informational
        )
    }

    func pasteFiles(_ target: [String], _ trigger: String) async {
        guard !cutFileBuffer.isEmpty else {
            showFileTransferAlert(
                title: AppLocalization.localized("Nothing to paste"),
                message: AppLocalization.localized("Choose Cut Files on one or more items first."),
                style: .informational
            )
            return
        }
        guard let destinationURL = destinationDirectory(from: target, trigger: trigger) else {
            showFileTransferAlert(
                title: AppLocalization.localized("Choose a destination folder"),
                message: AppLocalization.localized("Right-click a folder or an empty area inside a folder, then choose Paste."),
                style: .warning
            )
            return
        }
        guard await ensureAccess(to: destinationURL) else { return }

        let authorizedURLs = await authorizedSourceURLs(cutFileBuffer.urls)
        guard !authorizedURLs.isEmpty else { return }

        let result = await performTransfer(authorizedURLs, to: destinationURL, operation: .move)
        cutFileBuffer.removeSuccessfullyMoved(result.successes)
        presentTransferResult(
            result,
            operation: .move,
            skippedCount: cutFileBuffer.urls.count - result.failures.count
        )
    }

    func transferFilesToChosenFolder(
        _ target: [String],
        _ trigger: String,
        operation: FileTransferOperation
    ) async {
        guard trigger == "ctx-items" else {
            showFileTransferAlert(
                title: AppLocalization.localized("Select files first"),
                message: AppLocalization.localized("Select one or more files or folders in Finder first."),
                style: .informational
            )
            return
        }

        let selectedURLs = existingUnprotectedURLs(from: target)
        let authorizedURLs = await authorizedSourceURLs(selectedURLs)
        guard !authorizedURLs.isEmpty else {
            showFileTransferAlert(
                title: AppLocalization.localized("No files available"),
                message: AppLocalization.localized("The selected items cannot be used or access was not granted."),
                style: .warning
            )
            return
        }
        guard let destinationURL = chooseDestinationFolder(for: operation, sources: authorizedURLs) else {
            return
        }

        if !appState.bookmarkManager.hasAccess(to: destinationURL) {
            appState.bookmarkManager.saveBookmark(for: destinationURL)
        }

        let result = await performTransfer(authorizedURLs, to: destinationURL, operation: operation)
        presentTransferResult(
            result,
            operation: operation,
            skippedCount: target.count - authorizedURLs.count
        )
    }

    private func existingUnprotectedURLs(from target: [String]) -> [URL] {
        target.compactMap { rawPath in
            let path = rawPath.removingPercentEncoding ?? rawPath
            guard FileManager.default.fileExists(atPath: path), !Utils.isProtectedFolder(path) else {
                return nil
            }
            return URL(fileURLWithPath: path)
        }
    }

    private func authorizedSourceURLs(_ sourceURLs: [URL]) async -> [URL] {
        var accessByDirectory: [String: Bool] = [:]
        var authorizedURLs: [URL] = []

        for sourceURL in sourceURLs {
            let directoryURL = sourceURL.deletingLastPathComponent().standardizedFileURL
            let directoryPath = directoryURL.path
            let hasAccess: Bool
            if let cachedAccess = accessByDirectory[directoryPath] {
                hasAccess = cachedAccess
            } else {
                if !appState.bookmarkManager.hasAccess(to: directoryURL) {
                    _ = await appState.bookmarkManager.promptForPermission(for: directoryURL)
                }
                hasAccess = appState.bookmarkManager.hasAccess(to: directoryURL)
                accessByDirectory[directoryPath] = hasAccess
            }

            if hasAccess {
                authorizedURLs.append(sourceURL)
            }
        }

        return authorizedURLs
    }

    private func ensureAccess(to directoryURL: URL) async -> Bool {
        if !appState.bookmarkManager.hasAccess(to: directoryURL) {
            _ = await appState.bookmarkManager.promptForPermission(for: directoryURL)
        }
        return appState.bookmarkManager.hasAccess(to: directoryURL)
    }

    private func destinationDirectory(from target: [String], trigger: String) -> URL? {
        guard let rawPath = target.first else { return nil }
        let path = rawPath.removingPercentEncoding ?? rawPath
        let selectedURL = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return nil
        }
        if trigger == "ctx-container" || (target.count == 1 && isDirectory.boolValue) {
            return isDirectory.boolValue ? selectedURL : nil
        }
        return selectedURL.deletingLastPathComponent()
    }

    private func chooseDestinationFolder(
        for operation: FileTransferOperation,
        sources: [URL]
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.message = operation == .copy
            ? AppLocalization.localized("Choose where to copy the selected items.")
            : AppLocalization.localized("Choose where to move the selected items.")
        panel.prompt = operation == .copy
            ? AppLocalization.localized("Copy Here")
            : AppLocalization.localized("Move Here")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = sources.first?.deletingLastPathComponent()

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private func performTransfer(
        _ sourceURLs: [URL],
        to destinationURL: URL,
        operation: FileTransferOperation
    ) async -> FileTransferResult {
        await Task.detached(priority: .userInitiated) {
            FileTransferService.transfer(sourceURLs, to: destinationURL, operation: operation)
        }.value
    }

    private func presentTransferResult(
        _ result: FileTransferResult,
        operation: FileTransferOperation,
        skippedCount: Int
    ) {
        let destinationURLs = result.successes.map(\.destinationURL)
        if !destinationURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(destinationURLs)
        }

        let hasIssues = !result.failures.isEmpty || skippedCount > 0
        var message = String(
            format: AppLocalization.localized("Completed %d item(s)."),
            result.successes.count
        )
        if skippedCount > 0 {
            message += " " + String(
                format: AppLocalization.localized("Skipped %d item(s)."),
                skippedCount
            )
        }
        if !result.failures.isEmpty {
            message += "\n\n" + result.failures.prefix(5).map {
                "\($0.sourceURL.lastPathComponent): \($0.message)"
            }.joined(separator: "\n")
        }

        let actionName = operation == .copy
            ? AppLocalization.localized("Copy")
            : AppLocalization.localized("Move")
        showFileTransferAlert(
            title: hasIssues
                ? String(format: AppLocalization.localized("%@ finished with errors"), actionName)
                : String(format: AppLocalization.localized("%@ complete"), actionName),
            message: message,
            style: hasIssues ? .warning : .informational
        )
    }

    private func showFileTransferAlert(
        title: String,
        message: String,
        style: NSAlert.Style
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: AppLocalization.localized("OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func convertImages(_ target: [String], _ trigger: String) async {
        guard trigger == "ctx-items" else {
            let alert = NSAlert()
            alert.messageText = AppLocalization.localized("Select images first")
            alert.informativeText = AppLocalization.localized("Select one or more image files in Finder, then choose Convert Images.")
            alert.alertStyle = .informational
            alert.addButton(withTitle: AppLocalization.localized("OK"))
            alert.runModal()
            return
        }

        let selectedURLs = target.map { rawPath in
            URL(fileURLWithPath: rawPath.removingPercentEncoding ?? rawPath)
        }
        let imageURLs = selectedURLs.filter { ImageConverter.canRead($0) }

        guard !imageURLs.isEmpty else {
            let alert = NSAlert()
            alert.messageText = AppLocalization.localized("No readable images")
            alert.informativeText = AppLocalization.localized("The selected items do not contain images that RightSight can convert.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: AppLocalization.localized("OK"))
            alert.runModal()
            return
        }

        let formatPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 26))
        formatPopup.addItems(withTitles: ImageOutputFormat.allCases.map(\.displayName))

        let formatAlert = NSAlert()
        formatAlert.messageText = AppLocalization.localized("Convert Images")
        formatAlert.informativeText = String(
            format: AppLocalization.localized("Choose an output format for %d image(s). Original files will be kept."),
            imageURLs.count
        )
        formatAlert.accessoryView = formatPopup
        formatAlert.addButton(withTitle: AppLocalization.localized("Convert"))
        formatAlert.addButton(withTitle: AppLocalization.localized("Cancel"))
        NSApp.activate(ignoringOtherApps: true)

        guard formatAlert.runModal() == .alertFirstButtonReturn else { return }
        let format = ImageOutputFormat.allCases[formatPopup.indexOfSelectedItem]

        var authorizedURLs: [URL] = []
        for sourceURL in imageURLs {
            let directoryURL = sourceURL.deletingLastPathComponent()
            if !appState.bookmarkManager.hasAccess(to: directoryURL) {
                _ = await appState.bookmarkManager.promptForPermission(for: directoryURL)
            }
            if appState.bookmarkManager.hasAccess(to: directoryURL) {
                authorizedURLs.append(sourceURL)
            }
        }

        var convertedURLs: [URL] = []
        var failureMessages: [String] = []
        for sourceURL in authorizedURLs {
            do {
                convertedURLs.append(try ImageConverter.convert(sourceURL, to: format))
            } catch {
                failureMessages.append("\(sourceURL.lastPathComponent): \(error.localizedDescription)")
                logger.error("convert image failed: \(sourceURL.path), \(error.localizedDescription)")
            }
        }

        if !convertedURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(convertedURLs)
        }

        let skippedCount = selectedURLs.count - imageURLs.count + imageURLs.count - authorizedURLs.count
        let resultAlert = NSAlert()
        resultAlert.messageText = failureMessages.isEmpty
            ? AppLocalization.localized("Conversion complete")
            : AppLocalization.localized("Conversion finished with errors")
        var summary = String(
            format: AppLocalization.localized("Created %d image(s)."),
            convertedURLs.count
        )
        if skippedCount > 0 {
            summary += " " + String(format: AppLocalization.localized("Skipped %d item(s)."), skippedCount)
        }
        if !failureMessages.isEmpty {
            summary += "\n\n" + failureMessages.prefix(5).joined(separator: "\n")
        }
        resultAlert.informativeText = summary
        resultAlert.alertStyle = failureMessages.isEmpty ? .informational : .warning
        resultAlert.addButton(withTitle: AppLocalization.localized("OK"))
        resultAlert.runModal()
    }

    func showAirDrop(_ target: [String], _ trigger: String) async {
        logger.info("---- showAirDrop trigger:\(trigger)")
        let fm = FileManager.default
        var fileURLs: [URL] = []

        if trigger == "ctx-container" {
            let alert = NSAlert()
            alert.messageText = AppLocalization.localized("Warning")
            alert.informativeText = AppLocalization.localized("The current folder cannot be shared. Please select files or subfolders instead.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: AppLocalization.localized("OK"))
            alert.runModal()
            return
        }

        for item in target {
            let decodedPath = item.removingPercentEncoding ?? item
            logger.info("airdrop path \(decodedPath)")

            if Utils.isProtectedFolder(decodedPath) {
                let alert = NSAlert()
                alert.messageText = AppLocalization.localized("Warning")
                alert.informativeText = String(format: AppLocalization.localized("Protected system folders cannot be shared: %@"), decodedPath)
                alert.alertStyle = .warning
                alert.addButton(withTitle: AppLocalization.localized("OK"))
                alert.runModal()
                logger.warning("试图分享受保护的系统文件夹，操作已被阻止：\(decodedPath)")
                continue
            }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: decodedPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    logger.warning("不能通过 AirDrop 分享文件夹：\(decodedPath)")
                    let alert = NSAlert()
                    alert.messageText = AppLocalization.localized("Notice")
                    alert.informativeText = String(format: AppLocalization.localized("Folders cannot be shared via AirDrop: %@"), decodedPath)
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: AppLocalization.localized("OK"))
                    alert.runModal()
                    continue
                } else {
                    // 确保有文件所在目录的访问权限
                    let fileURL = URL(fileURLWithPath: decodedPath)
                    let dirURL = fileURL.deletingLastPathComponent()
                    if !appState.bookmarkManager.hasAccess(to: dirURL) {
                        guard let _ = await appState.bookmarkManager.promptForPermission(for: dirURL) else {
                            logger.warning("用户取消授权，跳过 AirDrop：\(decodedPath)")
                            continue
                        }
                    }
                    fileURLs.append(fileURL)
                }
            }
        }

        if !fileURLs.isEmpty {
            if let airDropService = NSSharingService(named: .sendViaAirDrop) {
                airDropService.perform(withItems: fileURLs)
                logger.info("已通过 AirDrop 分享文件：\(fileURLs.map { $0.path }.joined(separator: ", "))")
            } else {
                logger.warning("无法获取 AirDrop 服务")
            }
        }
    }

    func unhideFilesAndDirs(_ target: [String], _ trigger: String) async {
        logger.info("开始取消隐藏文件和目录，目标路径：\(target)")
        if let dirPath = target.first {
            let fileManager = FileManager.default
            let path = dirPath.removingPercentEncoding ?? dirPath
            logger.info("处理主目录：\(path)")
            let url = URL(fileURLWithPath: path)

            // 确保有目录的访问权限
            if !appState.bookmarkManager.hasAccess(to: url) {
                guard let _ = await appState.bookmarkManager.promptForPermission(for: url) else {
                    logger.warning("用户取消授权，跳过取消隐藏：\(path)")
                    return
                }
            }

            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isHiddenKey], options: [.skipsPackageDescendants])
                for case var fileURL in contents {
                    do {
                        var resourceValues = URLResourceValues()
                        resourceValues.isHidden = false
                        try fileURL.setResourceValues(resourceValues)
                        logger.info("成功取消隐藏：\(fileURL.path)")
                    } catch {
                        logger.error("取消隐藏失败：\(fileURL.path): \(error)")
                    }
                }
            } catch {
                logger.error("获取目录内容失败：\(error)")
            }

            do {
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = false
                var targetURL = url
                try targetURL.setResourceValues(resourceValues)
                logger.info("成功取消隐藏主目录：\(path)")
            } catch {
                logger.error("取消隐藏主目录失败：\(path): \(error)")
            }
            logger.info("取消隐藏操作完成，共处理目录：\(path)")
        }
    }

    func hideFilesAndDirs(_ target: [String], _ trigger: String) async {
        logger.info("开始隐藏文件和目录，目标路径：\(target), 触发器：\(trigger)")
        let fileManager = FileManager.default

        if trigger == "ctx-container", let dirPath = target.first {
            let path = dirPath.removingPercentEncoding ?? dirPath
            logger.info("处理主目录：\(path)")
            let url = URL(fileURLWithPath: path)

            // 确保有目录的访问权限
            if !appState.bookmarkManager.hasAccess(to: url) {
                guard let _ = await appState.bookmarkManager.promptForPermission(for: url) else {
                    logger.warning("用户取消授权，跳过隐藏：\(path)")
                    return
                }
            }

            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants])
                for case var fileURL in contents {
                    if Utils.isProtectedFolder(fileURL.path) {
                        logger.warning("跳过受保护的文件路径：\(fileURL.path)")
                        continue
                    }
                    do {
                        var resourceValues = URLResourceValues()
                        resourceValues.isHidden = true
                        try fileURL.setResourceValues(resourceValues)
                        logger.info("成功隐藏：\(fileURL.path)")
                    } catch {
                        logger.error("隐藏失败：\(fileURL.path): \(error)")
                    }
                }
            } catch {
                logger.error("获取目录内容失败：\(error)")
            }
        } else if trigger == "ctx-items" {
            for dirPath in target {
                let path = dirPath.removingPercentEncoding ?? dirPath
                logger.info("处理路径：\(path)")
                let url = URL(fileURLWithPath: path)

                if Utils.isProtectedFolder(path) {
                    logger.warning("跳过受保护的文件路径：\(path)")
                    continue
                }

                // 确保有文件所在目录的访问权限
                let dirURL = url.deletingLastPathComponent()
                if !appState.bookmarkManager.hasAccess(to: dirURL) {
                    guard let _ = await appState.bookmarkManager.promptForPermission(for: dirURL) else {
                        logger.warning("用户取消授权，跳过隐藏：\(path)")
                        continue
                    }
                }

                do {
                    var resourceValues = URLResourceValues()
                    resourceValues.isHidden = true
                    var targetURL = url
                    try targetURL.setResourceValues(resourceValues)
                    logger.info("成功隐藏：\(path)")
                } catch {
                    logger.error("隐藏失败：\(path): \(error)")
                }
            }
        }
        logger.info("隐藏操作完成")
    }

    func copyPath(_ target: [String]) {
        if let dirPath = target.first {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(dirPath.removingPercentEncoding ?? dirPath, forType: .string)
        }
    }

    func deleteFoldorFile(_ target: [String], _ trigger: String) async {
        logger.info("---- deleteFoldorFile trigger:\(trigger)")
        let fm = FileManager.default

        if trigger == "ctx-container" {
            let alert = NSAlert()
            alert.messageText = AppLocalization.localized("Warning")
            alert.informativeText = AppLocalization.localized("The current folder cannot be deleted. Please select files or subfolders instead.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: AppLocalization.localized("OK"))
            alert.runModal()
            return
        }

        for item in target {
            let decodedPath = item.removingPercentEncoding ?? item

            if Utils.isProtectedFolder(decodedPath) {
                let alert = NSAlert()
                alert.messageText = AppLocalization.localized("Warning")
                alert.informativeText = String(format: AppLocalization.localized("Protected system folders cannot be deleted: %@"), decodedPath)
                alert.alertStyle = .warning
                alert.addButton(withTitle: AppLocalization.localized("OK"))
                alert.runModal()
                logger.warning("试图删除受保护的系统文件夹，操作已被阻止：\(decodedPath)")
                continue
            }

            // 确保有父目录的访问权限
            let url = URL(fileURLWithPath: decodedPath)
            let dirURL = url.deletingLastPathComponent()
            if !appState.bookmarkManager.hasAccess(to: dirURL) {
                guard let _ = await appState.bookmarkManager.promptForPermission(for: dirURL) else {
                    logger.warning("用户取消授权，跳过删除：\(decodedPath)")
                    continue
                }
            }

            do {
                try fm.removeItem(atPath: decodedPath)
            } catch {
                logger.error("delete \(target) file run error \(error)")
            }
        }
    }

    func createFile(rid: String, target: [String]) async {
        guard let dirPath = targetDirectoryForNewFile(target) else {
            logger.warning("when createFile, but not have target directory")
            return
        }

        let dirURL = URL(fileURLWithPath: dirPath)

        // 确保有目标目录的访问权限
        if !appState.bookmarkManager.hasAccess(to: dirURL) {
            guard let _ = await appState.bookmarkManager.promptForPermission(for: dirURL) else {
                logger.warning("用户取消授权，跳过创建文件")
                return
            }
        }

        if rid == NewFileMenuItem.customFileId {
            let filePath = getUniqueFilePath(dir: dirPath, ext: "")
            let fileURL = URL(fileURLWithPath: filePath)
            do {
                try Data().write(to: fileURL)
                logger.info("created editable file: \(fileURL.path)")
                revealInFinderAndRename(fileURL)
            } catch {
                logger.error("create editable file error: \(error.localizedDescription)")
            }
            return
        }

        guard let rcitem = appState.getFileType(rid: rid) else {
            logger.warning("when createFile, but not have fileType \(rid) ")
            return
        }

        let ext = rcitem.ext
        logger.info("create file dir:\(dirPath) -- ext \(ext)")
        let filePath = getUniqueFilePath(dir: dirPath, ext: ext)
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let fileManager = FileManager.default

            if let templateUrl = rcitem.template {
                try fileManager.copyItem(at: templateUrl, to: fileURL)
                logger.info("已成功复制模板到目标路径：\(fileURL.path)")
            } else {
                if let defaultTemplateURL = Bundle.main.url(forResource: "template", withExtension: ext.replacingOccurrences(of: ".", with: "")) {
                    logger.info("使用模板创建文件，模板路径：\(defaultTemplateURL.path)")
                    try fileManager.copyItem(at: defaultTemplateURL, to: fileURL)
                    logger.info("已成功复制模板到目标路径：\(fileURL.path)")
                } else {
                    logger.warning("模板文件不存在：\(ext)")
                    try Data().write(to: fileURL)
                }
            }
            revealInFinderAndRename(fileURL)
        } catch let error as NSError {
            switch error.domain {
            case NSCocoaErrorDomain:
                switch error.code {
                case NSFileNoSuchFileError:
                    logger.error("文件不存在：\(filePath)")
                case NSFileWriteOutOfSpaceError:
                    logger.error("磁盘空间不足")
                case NSFileWriteNoPermissionError:
                    logger.error("没有写入权限：\(filePath)")
                default:
                    logger.error("创建文件错误：\(error.localizedDescription) (错误码：\(error.code))")
                }
            default:
                logger.error("未处理的错误：\(error.localizedDescription) (错误码：\(error.code))")
            }
        }
    }
}
