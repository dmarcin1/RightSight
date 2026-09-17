//
//  SettingsWindow.swift
//  RightSight
//
//  Created by 李旭 on 2024/9/25.
//

import SwiftUI

struct SettingsWindow: Scene {
    @ObservedObject var appState: AppState
    
    @EnvironmentObject var updateManager: UpdateManager
    
    let onAppear: () -> Void

    var body: some Scene {
        Window(AppLocalization.localized("Settings"), id: Constants.settingsWindowID) {
            SettingsView()
                .environmentObject(appState)
                .onAppear {
                    onAppear()
                }
                .frame(minWidth: 820, minHeight: 560)
                .sheet(isPresented: $updateManager.showUpdateSheet) {
                    UpdateView(updateManager: updateManager)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 920, height: 640)
    }
    
}
