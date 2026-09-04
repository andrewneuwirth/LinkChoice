import AppKit
import ServiceManagement

/// The menu bar icon — the only visible surface LinkChoice has when it's
/// not actively showing a picker. Rebuilds its menu fresh every time it's
/// opened so newly installed browsers and toggle states are always current.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "LinkChoice")
            image?.isTemplate = true
            button.image = image
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(disabledTitle("LinkChoice"))
        menu.addItem(.separator())
        menu.addItem(disabledTitle("Browsers"))

        let enabled = Prefs.enabledBundleIDs
        var anyInstalled = false
        for browser in candidateBrowsers {
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) != nil else { continue }
            anyInstalled = true
            let item = NSMenuItem(title: browser.name, action: #selector(toggleBrowser(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = browser.bundleID
            item.state = enabled.contains(browser.bundleID) ? .on : .off
            menu.addItem(item)
        }
        if !anyInstalled {
            menu.addItem(disabledTitle("(none of the listed browsers are installed)"))
        }

        menu.addItem(.separator())

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = Prefs.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        let defaultItem = NSMenuItem(title: "Set as Default Browser…", action: #selector(setAsDefault), keyEquivalent: "")
        defaultItem.target = self
        menu.addItem(defaultItem)

        menu.addItem(.separator())

        let githubItem = NSMenuItem(title: "View on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        githubItem.target = self
        menu.addItem(githubItem)

        let quitItem = NSMenuItem(title: "Quit LinkChoice", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func disabledTitle(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func toggleBrowser(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        var enabled = Prefs.enabledBundleIDs
        if enabled.contains(bundleID) {
            // Never allow disabling every browser — the picker would have
            // nothing to show.
            if enabled.count > 1 { enabled.remove(bundleID) }
        } else {
            enabled.insert(bundleID)
        }
        Prefs.enabledBundleIDs = enabled
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newValue = !Prefs.launchAtLogin
        do {
            if newValue {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Prefs.launchAtLogin = newValue
        } catch {
            NSLog("[LinkChoice] launch-at-login toggle failed: \(error)")
        }
    }

    @objc private func setAsDefault() {
        let appURL = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "http") { _ in }
        // Firing both schemes back-to-back sometimes hits a transient
        // Launch Services rate limit (observed empirically); stagger the
        // second call rather than fire simultaneously.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "https") { _ in }
        }

        let alert = NSAlert()
        alert.messageText = "Requesting default browser status…"
        alert.informativeText = """
        macOS should pick this up within a couple seconds.

        If links still open in your old browser, go to \
        System Settings → Desktop & Dock → Default web browser and pick \
        LinkChoice there — that list can be stale until you reopen it. \
        Note: macOS only allows this for apps signed with a real Apple \
        Developer ID; an ad-hoc-signed build will not be accepted no \
        matter which method you use.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/andrewneuwirth/LinkChoice") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
