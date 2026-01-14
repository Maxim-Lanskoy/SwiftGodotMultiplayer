// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Swift",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "SwiftLibrary",
            type: .dynamic,
            targets: ["SwiftLibrary"]),
        .executable(
            name: "MultiplayerSwift",
            targets: ["MultiplayerSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "a1af0de831a22a2f1d5d8b4221d9df2fdd12978f"),
        .package(url: "https://github.com/migueldeicaza/SwiftGodotKit", revision: "7f59a1ad97d243a071b548bed7ff573449c82af5")
    ],
    targets: [
        .target(
            name: "SwiftLibrary",
            dependencies: [
                .product(name: "SwiftGodot", package: "SwiftGodot")
            ], path: "SwiftLibrary"),
        .executableTarget(
            name: "MultiplayerSwift",
            dependencies: [
                "SwiftLibrary",
                .product(name: "SwiftGodotKit", package: "SwiftGodotKit")
            ], path: "MultiplayerSwift",
            resources: [
                .copy("Resources")
            ])
    ]
)
