//
//  MenuBarView.swift
//  RightSight
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import FinderSync
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) var openWindow: OpenWindowAction
    @State private var isFinderExtensionEnabled = false

    let messager = Messager.shared

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text("RightSight")
                        .font(.headline)
                    Text(String(format: AppLocalization.localized("Version %@"), appVersion))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Label(
                AppLocalization.localized(isFinderExtensionEnabled ? "Finder Extension Enabled" : "Finder Extension Disabled"),
                systemImage: isFinderExtensionEnabled ? "checkmark.circle.fill" : "exclamationmark.circle"
            )
            .foregroundStyle(isFinderExtensionEnabled ? .green : .secondary)

            Divider()

            Button(action: actionSettings) {
                Image(systemName: "gearshape")
                Text(appLocalized: "Settings")
            }
            .keyboardShortcut(",", modifiers: [.command])

            Button(action: actionQuit) {
                Image(systemName: "xmark.square")
                Text(appLocalized: "Quit")
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .onAppear {
            isFinderExtensionEnabled = FIFinderSyncController.isExtensionEnabled
        }
    }

    @MainActor
    private func actionSettings() {
        openWindow(id: Constants.settingsWindowID)

        let windows = NSApplication.shared.windows

        // 查找已存在的目标窗口
        if let existingWindow = windows.first(where: { $0.identifier?.rawValue == Constants.settingsWindowID }) {
            existingWindow.makeKeyAndOrderFront(nil) // 将窗口置于最前
            NSApplication.shared.activate(ignoringOtherApps: true) // 激活应用
        }
    }

    @MainActor
    private func actionQuit() {
        messager.sendQuitNotification()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApplication.shared.terminate(nil)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? AppLocalization.localized("Unknown")
    }
}

#Preview {
    MenuBarView()
}
