//
//  CommonDirsSettingTabView.swift
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

struct CommonDirsSettingTabView: View {
    @AppLog(category: "settings-general")
    private var logger
    
    @EnvironmentObject var store: AppState
    
    @State private var showCommonDirImporter = false
    
    var body: some View {
        SettingsPage(
            title: "Common Dir",
            subtitle: Tabs.cdirs.subtitle,
            systemImage: Tabs.cdirs.icon
        ) {
            List {
                Section {
                    Toggle(isOn: $store.showCommonDirs) {
                        Text(appLocalized: "Enable common folders")
                    }
                    .onChange(of: store.showCommonDirs) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
                    Toggle(isOn: $store.foldCommonDirMenu) {
                        Text(appLocalized: "Collapse menu")
                    }
                    .disabled(!store.showCommonDirs)
                    .onChange(of: store.foldCommonDirMenu) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
                }

                Section {
                    if store.cdirs.isEmpty {
                        SettingsEmptyState(
                            systemImage: "folder.badge.plus",
                            title: "No folders added",
                            message: "Add folders you visit often to reach them from Finder's context menu."
                        )
                    } else {
                        ForEach(store.cdirs) { item in
                            LabeledContent {
                                Button {
                                    removeCommonDir(item)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help(AppLocalization.localized("Remove folder"))
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                    Label(item.displayName, systemImage: item.icon.isEmpty ? "folder" : item.icon)
                                }
                            }
                        }
                        .onMove { source, destination in
                            store.moveCommonDirs(from: source, to: destination)
                        }
                    }
                } header: {
                    HStack {
                        Text(appLocalized: "Added Folders")
                        Spacer()
                        Button {
                            showCommonDirImporter = true
                        } label: {
                            Label(AppLocalization.localized("Add Folder"), systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                    }
                } footer: {
                    HStack {
                        Spacer()
                        Button(AppLocalization.localized("Restore Defaults")) {
                            store.resetCommonDirs()
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
        }
        .fileImporter(
            isPresented: $showCommonDirImporter,
            allowedContentTypes: [.directory],
            allowsMultipleSelection: false
        ) { result in
            switch result {
                case .success(let urls):
                    if let url = urls.first {
                        let commonDir = CommonDir(id: UUID().uuidString, name: url.lastPathComponent, url: url, icon: iconForDirectory(url: url))
                        if !store.cdirs.contains(where: { $0.url == commonDir.url }) {
                            store.cdirs.append(commonDir)
                            store.sync()
                        }
                    }
                case .failure(let error):
                    logger.error("Failed to select common folder: \(error.localizedDescription)")
            }
        }
    }

    @MainActor private func removeCommonDir(_ item: CommonDir) {
        if let index = store.cdirs.firstIndex(of: item) {
            store.cdirs.remove(at: index)
            store.sync()
        }
    }
}
