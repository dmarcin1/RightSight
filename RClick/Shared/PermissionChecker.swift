//
//  PermissionChecker.swift
//  RightSight
//
//  辅助功能权限检查模块
//

import Foundation
import AppKit
@preconcurrency import ApplicationServices
import OSLog
import SwiftUI

// MARK: - Logger

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "RightSight",
    category: "PermissionChecker"
)

// MARK: - 权限检查器

/// 提供辅助功能权限的检测
public class PermissionChecker {

    static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
    )!

    /// 打开辅助功能权限设置
    @MainActor
    public static func openAccessibilitySettings() {
        NSWorkspace.shared.open(accessibilitySettingsURL)
    }

    /// 检查辅助功能权限
    /// - Returns: 如果有辅助功能权限则返回 true
    public static func hasAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
