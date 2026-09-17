//
//  GeneralSettingsTabView.swift
//  RightSight
//
//  Created by 李旭 on 2024/4/10.
//

import AppKit
import Cocoa
import FinderSync
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsTabView: View {
    @AppLog(category: "settings-general")
    private var logger

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @AppStorage(Key.showMenuBarExtra, store: .group) private var showMenuBarExtra = true
    @EnvironmentObject var store: AppState
    @ObservedObject private var bookmarkManager = AppState.shared.bookmarkManager

    @State private var finderSyncStatus: PermissionStatus = .unknown
    @State private var accessibilityStatus: PermissionStatus = .unknown
    @State private var showFolderPermissionsSheet = false
    @State private var showResetConfirmation = false
    @State private var operationError: String?

    @State private var showDirImporter = false
    @State private var wrongFold = false
    @State private var showAlert = false

    let messager = Messager.shared

    var body: some View {
        SettingsPage(
            title: "General",
            subtitle: Tabs.general.subtitle,
            systemImage: Tabs.general.icon
        ) {
            Form {
            // MARK: - 第一组：主要控制
            Section {
                Toggle(isOn: Binding(
                    get: { finderSyncStatus == .enabled },
                    set: { _ in
                        openExtensionSettings()
                    }
                )) {
                    Text(appLocalized: "Enable RightSight")
                }

                Toggle(isOn: $showMenuBarExtra) {
                    Text(appLocalized: "Show icon in menu bar")
                }

                Toggle(isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        LaunchAtLogin.isEnabled = newValue
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                )) {
                    Text(appLocalized: "Launch at login")
                }
            } header: {
                Text(appLocalized: "Main Controls")
            } footer: {
                Text(appLocalized: "Enable RightSight under Login Items & Extensions to show its actions in Finder context menus.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            // MARK: - 第二组：权限
            Section {
                // Finder 扩展状态
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(finderSyncStatus.description)
                            .foregroundColor(.secondary)
                        Button(AppLocalization.localized("Settings…")) {
                            openExtensionSettings()
                        }
                    }
                } label: {
                    Label(AppLocalization.localized("Finder Extension"), systemImage: finderSyncStatus.icon)
                        .foregroundColor(finderSyncStatus.color)
                }

                // 辅助功能权限
                LabeledContent {
                    Button(AppLocalization.localized("Settings…")) {
                        openAccessibilitySettings()
                    }
                } label: {
                    Label(AppLocalization.localized("Accessibility"), systemImage: accessibilityStatus.icon)
                        .foregroundColor(accessibilityStatus.color)
                }

                // 文件夹权限（Bookmark）
                LabeledContent {
                    HStack(spacing: 8) {
                        Text("\(bookmarkManager.authorizedDirectories.count)")
                            .foregroundColor(.secondary)
                        Button(AppLocalization.localized("Manage…")) {
                            showFolderPermissionsSheet = true
                        }
                    }
                } label: {
                    Label(AppLocalization.localized("Folder Permissions"), systemImage: "folder.badge.person.crop")
                }
            } header: {
                Text(appLocalized: "Permissions")
            } footer: {
                Text(appLocalized: "Select \"RightSight\" in the extensions list to enable the Finder context menu.")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // MARK: - 第三组：设置管理
            Section {
                // 备份
                LabeledContent {
                    HStack(spacing: 12) {
                        Button(AppLocalization.localized("Export…")) {
                            exportSettings()
                        }
                        Button(AppLocalization.localized("Import…")) {
                            importSettings()
                        }
                    }
                } label: {
                    Text(appLocalized: "Backup")
                }

                // 重置所有设置
                HStack {
                    Spacer()
                    Button(AppLocalization.localized("Reset All Settings…")) {
                        showResetConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
            } header: {
                Text(appLocalized: "Settings Management")
            } footer: {
                Text(appLocalized: "Resetting all settings restores the default configuration and cannot be undone")
                    .fixedSize(horizontal: false, vertical: true)
            }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .onAppear {
            updatePermissionStatus()
        }
        .onForeground {
            updatePermissionStatus()
        }
        .alert(
            Text(appLocalized: "Invalid Folder"),
            isPresented: $wrongFold
        ) {
            Button(AppLocalization.localized("OK")) {
                showDirImporter = true
            }
        } message: {
            Text(appLocalized: "The selected folder is a subfolder of an already selected folder. Please choose a different folder.")
        }
        .alert(
            Text(appLocalized: "Unauthorized Folder"),
            isPresented: $showAlert
        ) {
            Button(AppLocalization.localized("OK")) {
                showDirImporter = true
            }
        } message: {
            Text(appLocalized: "Folder access permission is required to use this feature.")
        }
        .sheet(isPresented: $showFolderPermissionsSheet) {
            FolderPermissionsSheetView(bookmarkManager: bookmarkManager)
        }
        .alert(
            Text(appLocalized: "Reset All Settings?"),
            isPresented: $showResetConfirmation
        ) {
            Button(AppLocalization.localized("Cancel"), role: .cancel) {}
            Button(AppLocalization.localized("Reset"), role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text(appLocalized: "This will delete all custom configurations and restore the defaults. This action cannot be undone.")
        }
        .alert(
            Text(appLocalized: "Settings Error"),
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button(AppLocalization.localized("OK")) {
                operationError = nil
            }
        } message: {
            Text(operationError ?? "")
        }
    }

    // MARK: - 权限状态检测

    private func updatePermissionStatus() {
        // Finder 扩展状态
        finderSyncStatus = FIFinderSyncController.isExtensionEnabled ? .enabled : .disabled

        // 辅助功能权限检测
        accessibilityStatus = PermissionChecker.hasAccessibilityPermission() ? .enabled : .disabled

        // 登录时启动状态
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    private func hasAccessibilityPermission() -> Bool {
        return PermissionChecker.hasAccessibilityPermission()
    }

    // MARK: - 权限设置打开

    private func openExtensionSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.extensions"
        ]
        for urlString in urls {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func openAccessibilitySettings() {
        PermissionChecker.openAccessibilitySettings()
    }

    // MARK: - 设置管理

    private func exportSettings() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.propertyList]
        savePanel.nameFieldStringValue = "RightSight_Settings.plist"
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                try store.exportSettingsData().write(to: url, options: .atomic)
                logger.info("导出设置到：\(url.path)")
            } catch {
                operationError = error.localizedDescription
                logger.error("导出设置失败：\(error.localizedDescription)")
            }
        }
    }

    private func importSettings() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.propertyList]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else { return }
            do {
                try store.importSettingsData(Data(contentsOf: url))
                logger.info("从以下路径导入设置：\(url.path)")
            } catch {
                operationError = error.localizedDescription
                logger.error("导入设置失败：\(error.localizedDescription)")
            }
        }
    }

    private func resetAllSettings() {
        do {
            try store.resetAllSettings()
            LaunchAtLogin.isEnabled = false
            launchAtLogin = false
            showMenuBarExtra = true
            logger.info("重置所有设置")
        } catch {
            operationError = error.localizedDescription
            logger.error("重置设置失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 权限状态枚举

enum PermissionStatus {
    case enabled
    case disabled
    case unknown

    var icon: String {
        switch self {
        case .enabled:
            return "checkmark.circle.fill"
        case .disabled:
            return "circle"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .enabled:
            return .green
        case .disabled:
            return .gray
        case .unknown:
            return .yellow
        }
    }

    var description: String {
        switch self {
        case .enabled:
            return AppLocalization.localized("Authorized")
        case .disabled:
            return AppLocalization.localized("Not Authorized")
        case .unknown:
            return AppLocalization.localized("Unknown")
        }
    }
}
