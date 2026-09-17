//
//  SettingsView.swift
//  RightSight
//
//  Created by 李旭 on 2024/4/4.
//

import SwiftUI

enum Tabs: String, CaseIterable, Identifiable {
    case general = "General"
    case apps = "Apps"
    case actions = "Actions"
    case newFile = "New File"
    case cdirs = "Common Dir"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .apps: "app.badge"
        case .actions: "bolt.square"
        case .newFile: "doc.badge.plus"
        case .cdirs: "folder.badge.gearshape"
        case .about: "info.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Control startup, permissions, and menu bar behavior."
        case .apps: "Choose the apps that appear in the Finder context menu."
        case .actions: "Arrange the file actions you use most often."
        case .newFile: "Create files from your own types and templates."
        case .cdirs: "Keep frequently used folders one click away."
        case .about: "Version, updates, and project information."
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: Tabs = .general
    @EnvironmentObject var appState: AppState

    private var sidebar: some View {
        List(selection: $selectedTab) {
            Section {
                ForEach(Tabs.allCases) { tab in
                    Label {
                        Text(appLocalized: tab.rawValue)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                    } icon: {
                        Image(systemName: tab.icon)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .tag(tab)
                    .padding(.vertical, 3)
                }
            } header: {
                Text(appLocalized: "Settings")
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 230)
        .safeAreaInset(edge: .top) {
            brandHeader
        }
        .toolbar(removing: .sidebarToggle)
    }

    private var brandHeader: some View {
        VStack(spacing: 6) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text("RightSight")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .tracking(-0.25)
                .lineLimit(1)
            Text(String(format: AppLocalization.localized("Version %@"), appVersion))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsTabView()
        case .apps:
            AppsSettingsTabView()
        case .actions:
            ActionSettingsTabView()
        case .newFile:
            NewFileSettingsTabView()
        case .cdirs:
            CommonDirsSettingTabView()
        case .about:
            AboutSettingsTabView()
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .id(selectedTab)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.18), value: selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? AppLocalization.localized("Unknown")
    }
}

struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.055))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 100, y: -150)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 42, height: 42)
                        .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppLocalization.localized(title))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .tracking(-0.45)
                        Text(AppLocalization.localized(subtitle))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 18)

                Divider()
                    .opacity(0.7)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct SettingsEmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
            Text(AppLocalization.localized(title))
                .font(.headline)
            Text(AppLocalization.localized(message))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .padding(24)
    }
}

struct SettingsSheetHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(AppLocalization.localized(title))
                    .font(.headline)
                Text(AppLocalization.localized(subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
