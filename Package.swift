// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacExplorer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacExplorer",
            path: "MacExplorer"
        )
    ]
)
