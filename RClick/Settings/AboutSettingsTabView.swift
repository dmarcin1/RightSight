//
//  AboutSettingsTabView.swift
//  RightSight
//
//  Created by 李旭 on 2024/4/4.
//

import SwiftUI

struct AboutSettingsTabView: View {
    @EnvironmentObject private var updateManager: UpdateManager

    var body: some View {
        SettingsPage(
            title: "About",
            subtitle: Tabs.about.subtitle,
            systemImage: Tabs.about.icon
        ) {
            Form {
                Section {
                    HStack(spacing: 18) {
                        Image("Logo")
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color.accentColor.opacity(0.18), radius: 14, y: 7)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("RightSight")
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .tracking(-0.5)
                            Text(appLocalized: "Finder tools, right where you need them.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(String(format: AppLocalization.localized("Version %@ (%@)"), appVersion, buildVersion))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }

                        Spacer()
                    }
                    .padding(.vertical, 10)
                }

                Section {
                    Text(appLocalized: "RightSight is a right-click menu extension that allows you to add applications for opening folders and includes some common actions.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                } header: {
                    Text(appLocalized: "About RightSight")
                }

                Section {
                    Button {
                        Task {
                            await updateManager.checkForUpdates(force: true)
                        }
                    } label: {
                        Label(AppLocalization.localized("Check for Updates"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(updateManager.isChecking)

                    Link(destination: URL(string: "https://github.com/dmarcin1/RightSight")!) {
                        Label(AppLocalization.localized("View Source Code"), systemImage: "chevron.left.forwardslash.chevron.right")
                    }

                    Link(destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!) {
                        Label(AppLocalization.localized("GNU GPL v3 License"), systemImage: "doc.text")
                    }
                } header: {
                    Text(appLocalized: "Project")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? AppLocalization.localized("Unknown")
    }

    private var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? AppLocalization.localized("Unknown")
    }
}

#Preview {
    AboutSettingsTabView()
        .environmentObject(UpdateManager(owner: "dmarcin1", repo: "RightSight", currentVersion: "2.1.0"))
}
