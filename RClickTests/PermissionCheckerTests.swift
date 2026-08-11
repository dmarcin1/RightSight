import Foundation
import Testing
@testable import RightSight

struct PermissionCheckerTests {
    @MainActor
    @Test func accessibilitySettingsUsesRegisteredSystemPreferencesScheme() {
        let url = PermissionChecker.accessibilitySettingsURL

        #expect(url.scheme == "x-apple.systempreferences")
        #expect(url.absoluteString.contains("com.apple.settings.PrivacySecurity.extension"))
        #expect(url.query == "Privacy_Accessibility")
    }
}
