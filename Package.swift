// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacExplorer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.1")
    ],
    targets: [
        .executableTarget(
            name: "MacExplorer",
            dependencies: ["CoreXLSX"],
            path: "MacExplorer",
            resources: [
                .copy("Resources/highlight.min.js"),
                .copy("Resources/atom-one-dark.min.css"),
                .copy("Resources/atom-one-light.min.css")
            ]
        )
    ]
)
