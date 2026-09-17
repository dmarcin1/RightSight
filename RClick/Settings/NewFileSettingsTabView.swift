//
//  NewFileSettingsTabView.swift
//  RightSight
//
//  Created by 李旭 on 2024/11/18.
//

import AppKit
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct NewFileSettingsTabView: View {
    @AppLog(category: "NewFileSettingsTabView")
    private var logger
    
    @EnvironmentObject var appState: AppState
    @State private var editingFile: NewFile?
    @State private var fileToDelete: NewFile?

    var body: some View {
        SettingsPage(
            title: "New File",
            subtitle: Tabs.newFile.subtitle,
            systemImage: Tabs.newFile.icon
        ) {
            List {
                Section {
                    Toggle(isOn: $appState.foldNewFileMenu) {
                        Text(appLocalized: "Collapse new file menu")
                    }
                    .onChange(of: appState.foldNewFileMenu) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
                }

                Section {
                    if appState.newFiles.isEmpty {
                        SettingsEmptyState(
                            systemImage: "doc.badge.plus",
                            title: "No file types added",
                            message: "Add a file type or restore the defaults to create files from Finder."
                        )
                    } else {
                        ForEach($appState.newFiles) { $item in
                            LabeledContent {
                                HStack(spacing: 12) {
                                    Button {
                                        editingFile = item
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(.borderless)
                                    .help(AppLocalization.localized("Edit File Type"))

                                    Button {
                                        fileToDelete = item
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help(AppLocalization.localized("Delete File Type"))

                                    Toggle(AppLocalization.localized("Enabled"), isOn: $item.enabled)
                                        .toggleStyle(.switch)
                                        .onChange(of: item.enabled) {
                                            appState.sync()
                                        }
                                        .labelsHidden()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                    // 图标
                                    if let appUrl = item.openApp {
                                        Image(nsImage: IconCache.shared.icon(for: appUrl))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 24, height: 24)
                                    } else if let sysIcon = FileTypeIconProvider.shared.icon(for: item.ext, fallbackSymbol: item.icon) {
                                        Image(nsImage: sysIcon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 20, height: 20)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                        Text(String(format: AppLocalization.localized("Extension: %@"), item.ext))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onMove { source, destination in
                            appState.moveNewFiles(from: source, to: destination)
                        }
                    }
                } header: {
                    HStack {
                        Text(appLocalized: "New File")
                        Spacer()
                        Button {
                            editingFile = NewFile(ext: "", name: "", idx: appState.newFiles.count)
                        } label: {
                            Label(AppLocalization.localized("Add File Type"), systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                    }
                } footer: {
                    HStack {
                        Spacer()
                        Button(AppLocalization.localized("Restore Defaults")) {
                            appState.resetFiletypeItems()
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
        }
        .sheet(item: $editingFile) { file in
            EditFileTypeSheetView(file: file, appState: appState)
        }
        .confirmationDialog(
            AppLocalization.localized("Delete File Type"),
            isPresented: Binding(
                get: { fileToDelete != nil },
                set: { if !$0 { fileToDelete = nil } }
            ),
            presenting: fileToDelete
        ) { file in
            Button(AppLocalization.localized("Delete"), role: .destructive) {
                appState.deleteNewFile(id: file.id)
            }
            Button(AppLocalization.localized("Cancel"), role: .cancel) {
                fileToDelete = nil
            }
        } message: { file in
            Text(String(format: AppLocalization.localized("Are you sure you want to delete \"%@\" (%@)? This action cannot be undone."), file.name, file.ext))
        }
    }

}
