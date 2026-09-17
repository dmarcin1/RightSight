//
//  AppLocalization.swift
//  RightSight
//
//  Created by Codex on 2026/7/3.
//

import Foundation
import SwiftUI

private final class BundleToken {}

enum AppLocalization {
    nonisolated static let tableName = "Localizable"
    nonisolated static let bundle: Bundle = {
        let tokenBundle = Bundle(for: BundleToken.self)
        // If loaded as framework or standalone, tokenBundle is the target bundle.
        // Fallback to Bundle.main if somehow tokenBundle has no bundleIdentifier
        return tokenBundle.bundleIdentifier != nil ? tokenBundle : Bundle.main
    }()

    nonisolated static func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: tableName)
    }
}

extension Text {
    init(appLocalized key: String) {
        self.init(AppLocalization.localized(key))
    }
}
