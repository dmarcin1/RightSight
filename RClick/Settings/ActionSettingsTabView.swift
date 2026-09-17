//
//  ActionSettingsView.swift
//  RightSight
//
//  Created by 李旭 on 2024/4/9.
//

import SwiftUI

struct ActionSettingsTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        SettingsPage(
            title: "Actions",
            subtitle: Tabs.actions.subtitle,
            systemImage: Tabs.actions.icon
        ) {
            List {
                Section {
                    Toggle(isOn: $appState.foldActionsMenu) {
                        Text(appLocalized: "Collapse actions menu")
                    }
                    .onChange(of: appState.foldActionsMenu) {
                        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                    }
                }

                Section {
                    if appState.actions.isEmpty {
                        SettingsEmptyState(
                            systemImage: "bolt.slash",
                            title: "No actions available",
                            message: "Restore the default actions to rebuild this menu."
                        )
                    } else {
                        ForEach($appState.actions) { $item in
                            LabeledContent {
                                Toggle(AppLocalization.localized("Enabled"), isOn: $item.enabled)
                                    .toggleStyle(.switch)
                                    .onChange(of: item.enabled) {
                                        appState.toggleActionItem()
                                    }
                                    .labelsHidden()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                    Label(item.displayName, systemImage: item.icon)
                                }
                            }
                        }
                        .onMove { source, destination in
                            appState.moveActions(from: source, to: destination)
                        }
                    }
                } header: {
                    Text(appLocalized: "Actions")
                } footer: {
                    HStack {
                        Spacer()
                        Button(AppLocalization.localized("Restore Defaults")) {
                            appState.resetActionItems()
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
        }
    }
}
