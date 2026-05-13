// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MarketMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MarketMonitor",
            path: "Sources/MarketMonitor"
        )
    ]
)
