// swift-tools-version: 6.2

import PackageDescription

// let revision = "20d2d7a35d2ad392ec556219ea004da14ab7c1d4"

let package = Package(
    name: "Swift",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "SwiftLibrary",
            type: .dynamic,
            targets: ["SwiftLibrary"]),
        // .executable(
        //     name: "MultiplayerSwift",
        //     targets: ["MultiplayerSwift"]),
    ],
    dependencies: [
        // .package(url:  "https://github.com/migueldeicaza/SwiftGodot", revision: revision),
        // .package(url: "https://github.com/migueldeicaza/SwiftGodotKit", branch:  "main" )
        .package(url:  "https://github.com/migueldeicaza/SwiftGodot", branch: "main")
    ],
    targets: [
        .target(
            name: "SwiftLibrary",
            dependencies: [
                .product(name: "SwiftGodot", package: "SwiftGodot")
            ], path: "SwiftLibrary"),
        // .executableTarget(
        //     name: "MultiplayerSwift",
        //     dependencies: [
        //         "SwiftLibrary",
        //         .product(name: "SwiftGodotKit", package: "SwiftGodotKit")
        //     ], path: "MultiplayerSwift",
        //     resources: [
        //         .copy("Resources/SwiftLibrary.pck")
        //     ])
    ]
)
