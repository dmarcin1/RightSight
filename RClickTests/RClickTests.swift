//
//  RightSightTests.swift
//  RightSightTests
//
//  Created by luke on 2026/4/6.
//

import Foundation
import Testing
@testable import RightSight

struct RightSightTests {

    @MainActor
    @Test func protectedFoldersAreCorrectlyIdentified() {
        // Root and empty string must be protected
        #expect(Utils.isProtectedFolder("/") == true)
        #expect(Utils.isProtectedFolder("") == true)

        // System directories must be protected
        #expect(Utils.isProtectedFolder("/System") == true)
        #expect(Utils.isProtectedFolder("/System/Library") == true)
        #expect(Utils.isProtectedFolder("/System/Library/CoreServices") == true)
        #expect(Utils.isProtectedFolder("/Library") == true)
        #expect(Utils.isProtectedFolder("/Library/Preferences") == true)
        #expect(Utils.isProtectedFolder("/bin") == true)
        #expect(Utils.isProtectedFolder("/bin/zsh") == true)
        #expect(Utils.isProtectedFolder("/usr") == true)
        #expect(Utils.isProtectedFolder("/usr/bin") == true)
        #expect(Utils.isProtectedFolder("/private") == true)
        #expect(Utils.isProtectedFolder("/private/var") == true)

        // User Home and Desktop must be protected
        let home = Utils.getRealHomeDir()
        #expect(Utils.isProtectedFolder(home) == true)
        #expect(Utils.isProtectedFolder(home + "/Desktop") == true)

        // Normal subfolders should not be blocked
        let safeFolder = home + "/Documents/MyProjects/SafeTestFolder"
        #expect(Utils.isProtectedFolder(safeFolder) == false)
    }

    @MainActor
    @Test func realHomeDirIsValid() {
        let home = Utils.getRealHomeDir()
        #expect(!home.isEmpty)
        #expect(home.hasPrefix("/Users/") || home == "/var/root")
    }

    @MainActor
    @Test func appStateConfigurationExportAndImport() throws {
        let appState = AppState()
        let exportedData = try appState.exportSettingsData()
        #expect(!exportedData.isEmpty)

        // Verify import succeeds without throwing
        try appState.importSettingsData(exportedData)
    }

    @MainActor
    @Test func appStateCommonDirsManagement() {
        let appState = AppState()
        // Ensure default directories are populated
        appState.resetCommonDirs()
        #expect(!appState.cdirs.isEmpty)
        #expect(appState.cdirs.count >= 4)

        // Test moveCommonDirs if we have at least 2 items
        let firstId = appState.cdirs[0].id
        appState.moveCommonDirs(from: IndexSet(integer: 0), to: 2)
        #expect(appState.cdirs[1].id == firstId)
    }
}

