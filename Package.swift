// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ExplorerPP",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ExplorerPP", targets: ["ExplorerPP"])
    ],
    targets: [
        .executableTarget(
            name: "ExplorerPP",
            path: "Sources/Explorer"
        )
    ]
)
