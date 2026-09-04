import Foundation

/// Tiny UserDefaults-backed settings, read/written from the menu bar.
enum Prefs {
    private static let enabledKey = "enabledBrowserBundleIDs"

    /// Bundle IDs of browsers the picker should offer. Defaults to every
    /// browser in `candidateBrowsers` the first time the app runs.
    static var enabledBundleIDs: Set<String> {
        get {
            if let saved = UserDefaults.standard.array(forKey: enabledKey) as? [String] {
                return Set(saved)
            }
            return Set(candidateBrowsers.map(\.bundleID))
        }
        set { UserDefaults.standard.set(Array(newValue), forKey: enabledKey) }
    }

    private static let loginItemKey = "launchAtLoginEnabled"
    static var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: loginItemKey) }
        set { UserDefaults.standard.set(newValue, forKey: loginItemKey) }
    }
}
