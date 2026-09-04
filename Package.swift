// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "LinkChoice",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "LinkChoice", path: "Sources/LinkChoice"),
    ]
)
