//
//  AppsSettingsTabView.swift
//  RightSight
//
//  Created by 李旭 on 2024/11/18.
//

import AppKit
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct AppsSettingsTabView: View {
    @EnvironmentObject var appState: AppState
    @State var showSelectApp = false
    @State private var editingApp: OpenWithApp?
    @AppLog(category: "AppsSettings")
    private var logger

    var body: some View {
        SettingsPage(
            title: "Apps",
            subtitle: Tabs.apps.subtitle,
            systemImage: Tabs.apps.icon
        ) {
            List {
                Section {
                    Toggle(isOn: $appState.foldAppsMenu) {
                        Text(appLocalized: "Collapse apps menu")
                    }
                    .onChange(of: appState.foldAppsMenu) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
                }

                Section {
                    if appState.apps.isEmpty {
                        SettingsEmptyState(
                            systemImage: "app.dashed",
                            title: "No apps added",
                            message: "Add an app to open selected Finder items from the context menu."
                        )
                    } else {
                        ForEach(appState.apps) { item in
                            LabeledContent {
                                HStack(spacing: 8) {
                                    Button {
                                        editingApp = item
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(.borderless)
                                    .help(AppLocalization.localized("Edit App"))

                                    Button {
                                        deleteApp(item)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help(AppLocalization.localized("Delete App"))
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                    Image(nsImage: IconCache.shared.icon(for: item.url))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                        if !item.arguments.isEmpty || !item.environment.isEmpty {
                                            Text(appSummary(item))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .onMove { source, destination in
                            appState.moveApps(from: source, to: destination)
                        }
                    }
                } header: {
                    HStack {
                        Text(appLocalized: "Apps")
                        Spacer()
                        Button {
                            showSelectApp = true
                        } label: {
                            Label(AppLocalization.localized("Add App"), systemImage: "plus.app")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
        }
        .fileImporter(
            isPresented: $showSelectApp,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let url = files.first {
                    appState.addApp(item: OpenWithApp(appURL: url))
                }
            case .failure(let error):
                logger.error("Failed to select app: \(error.localizedDescription)")
            }
        }
        .sheet(item: $editingApp) { app in
            EditAppSheetView(app: app, appState: appState)
        }
    }

    private func appSummary(_ item: OpenWithApp) -> String {
        var parts: [String] = []
        if !item.arguments.isEmpty {
            parts.append(String(format: AppLocalization.localized("Arguments: %@"), item.arguments.joined(separator: "; ")))
        }
        if !item.environment.isEmpty {
            parts.append(String(format: AppLocalization.localized("Environment variables: %lld"), Int64(item.environment.count)))
        }
        return parts.joined(separator: " · ")
    }
    
    @MainActor private func deleteApp(_ appItem: OpenWithApp) {
        if let index = appState.apps.firstIndex(where: { $0.id == appItem.id }) {
            appState.deleteApp(index: index)
        }
    }
}
