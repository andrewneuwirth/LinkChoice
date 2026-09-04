// LinkChoice — a tiny always-on background app that becomes your default web
// browser. Instead of opening links directly, it shows a small picker near
// wherever you clicked and forwards the URL to whichever browser you choose.
//
// How it gets invoked: once set as the default browser in System Settings,
// macOS launches this app (if needed) and delivers a GetURL Apple Event for
// every http/https link clicked anywhere in the OS (Mail, Slack, Messages,
// any app). No Dock icon (LSUIElement), no menu bar clutter — it just waits.

import AppKit

// MARK: - Candidate browsers

struct Browser {
    let name: String
    let bundleID: String
}

/// Edit this list to add/remove/reorder browser choices.
let candidateBrowsers: [Browser] = [
    Browser(name: "Chrome", bundleID: "com.google.Chrome"),
    Browser(name: "Safari", bundleID: "com.apple.Safari"),
]

// MARK: - Picker window

final class PickerPanel: NSPanel {
    init(url: URL, at point: NSPoint, onChoose: @escaping (Browser) -> Void, onCancel: @escaping () -> Void) {
        let installed = candidateBrowsers.compactMap { browser -> (Browser, URL)? in
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) else {
                return nil
            }
            return (browser, appURL)
        }

        let buttonWidth: CGFloat = 108
        let buttonHeight: CGFloat = 40
        let padding: CGFloat = 10
        let spacing: CGFloat = 8
        let hostLabelHeight: CGFloat = 18
        let width = CGFloat(installed.count) * buttonWidth + CGFloat(max(0, installed.count - 1)) * spacing + padding * 2
        let height = buttonHeight + hostLabelHeight + padding * 2 + 4

        // Keep the panel on-screen even if the click was near a screen edge.
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var origin = NSPoint(x: point.x - width / 2, y: point.y - height - 12)
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - height - 8)

        super.init(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .popUpMenu
        hasShadow = true
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]

        let content = NSVisualEffectView(frame: NSRect(origin: .zero, size: NSSize(width: width, height: height)))
        content.material = .popover
        content.state = .active
        content.wantsLayer = true
        content.layer?.cornerRadius = 14
        content.layer?.masksToBounds = true
        content.layer?.borderWidth = 1
        content.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor

        let hostLabel = NSTextField(labelWithString: url.host ?? url.absoluteString)
        hostLabel.font = .systemFont(ofSize: 11, weight: .medium)
        hostLabel.textColor = .secondaryLabelColor
        hostLabel.alignment = .center
        hostLabel.lineBreakMode = .byTruncatingMiddle
        hostLabel.frame = NSRect(x: padding, y: height - padding - hostLabelHeight, width: width - padding * 2, height: hostLabelHeight)
        content.addSubview(hostLabel)

        for (index, pair) in installed.enumerated() {
            let (browser, appURL) = pair
            let x = padding + CGFloat(index) * (buttonWidth + spacing)
            let y = padding
            let button = BrowserButton(
                frame: NSRect(x: x, y: y, width: buttonWidth, height: buttonHeight),
                title: browser.name,
                icon: NSWorkspace.shared.icon(forFile: appURL.path)
            )
            button.onClick = { onChoose(browser) }
            content.addSubview(button)
        }

        contentView = content
        self.onCancel = onCancel
    }

    var onCancel: (() -> Void)?

    override func resignKey() {
        super.resignKey()
        onCancel?()
    }

    override func cancelOperation(_: Any?) {
        onCancel?()
    }

    override var canBecomeKey: Bool { true }
}

/// A simple icon+label button with hover/press feedback (no storyboard/xib).
final class BrowserButton: NSView {
    var onClick: (() -> Void)?
    private let icon: NSImage
    private let title: String
    private var isHovered = false {
        didSet { needsDisplay = true }
    }

    init(frame: NSRect, title: String, icon: NSImage) {
        self.title = title
        self.icon = icon
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        let tracking = NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self
        )
        addTrackingArea(tracking)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseUp(with event: NSEvent) { onClick?() }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            NSColor.white.withAlphaComponent(0.08).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        }
        let iconSize: CGFloat = 22
        let iconRect = NSRect(x: bounds.midX - iconSize / 2, y: bounds.maxY - iconSize - 3, width: iconSize, height: iconSize)
        icon.draw(in: iconRect)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]
        let text = title as NSString
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: bounds.midX - textSize.width / 2, y: 2), withAttributes: attrs)
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var openPanels: [PickerPanel] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    /// Fallback path some launch invocations use instead of the Apple Event above.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { present(url: url) }
    }

    @objc func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString)
        else { return }
        present(url: url)
    }

    private func present(url: URL) {
        let point = NSEvent.mouseLocation
        var panel: PickerPanel!
        panel = PickerPanel(
            url: url,
            at: point,
            onChoose: { [weak self] browser in
                self?.open(url: url, in: browser)
                self?.close(panel)
            },
            onCancel: { [weak self] in
                self?.close(panel)
            }
        )
        openPanels.append(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func close(_ panel: PickerPanel) {
        panel.orderOut(nil)
        openPanels.removeAll { $0 === panel }
    }

    private func open(url: URL, in browser: Browser) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) else { return }
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Regular (Dock-visible) activation policy is required for macOS to list this
// app in System Settings > Default web browser — LSUIElement/.accessory apps
// are filtered out of that picker even though they register the URL schemes
// fine. The Dock icon is the price of being selectable there.
app.setActivationPolicy(.regular)
app.run()
