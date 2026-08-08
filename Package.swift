// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Explorer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Explorer", targets: ["Explorer"])
    ],
    targets: [
        .executableTarget(
            name: "Explorer",
            path: "Sources/Explorer"
        )
    ]
)
