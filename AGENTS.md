# AGENTS.md: LinkChoice

A tiny macOS app that registers as the default web browser and, for every link clicked anywhere, shows a small picker at the cursor so you choose which browser opens it. No daemon, no polling, no telemetry; a menu-bar icon holds settings.

## Stack

- Swift 5.10 tools, SwiftPM, macOS 13+. One executable target `LinkChoice` (`Sources/LinkChoice/main.swift`, `MenuBarController.swift`, `Prefs.swift`), AppKit.
- `Info.plist` (repo root) declares `CFBundleURLTypes` for `http`/`https`; bundle id `com.andrewneuwirth.linkchoice`. `AppIcon.icns` at the root; `scripts/make_icon.swift` regenerates it.

## Commands

```sh
swift build                 # compile check
./build.sh                  # release build, then INSTALLS: replaces /Applications/LinkChoice.app, signs, lsregister, kills the old copy and launches it
```

- `build.sh` has no build-only mode: running it always installs and relaunches. Only run it when Andrew asks for an install; use `swift build` to check compilation.
- Signing: a "Developer ID Application" identity if present (hardened runtime), else ad-hoc. macOS won't accept an ad-hoc build as the real default browser.
- Setting the default browser is manual: System Settings › Desktop & Dock › Default web browser.

## Where data lives

- `UserDefaults` (`Prefs.swift`): which installed browsers show in the picker, and Launch at Login. No files.

## Rules

- Browsers are discovered with `NSWorkspace` lookups; don't hardcode browser paths.
- The last enabled browser can't be disabled; keep that guard.
- Escape or a click outside dismisses without opening anything.
- No tests.
