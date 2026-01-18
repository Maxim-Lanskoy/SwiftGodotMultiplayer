// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftMultiplayer",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "SwiftDriver",
            type: .dynamic,
            targets: ["SwiftDriver"]),
         .executable(
             name: "SwiftMultiplayer",
             targets: ["SwiftMultiplayer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Maxim-Lanskoy/SwiftGodot", branch: "rpc-macro"),
        .package(url: "https://github.com/Maxim-Lanskoy/SwiftGodotKit", branch: "rpc-macro")
    ],
    targets: [
        
        .target(
            name: "SwiftDriver",
            dependencies: [
                .product(name: "SwiftGodot", package: "SwiftGodot")
            ], path: "Sources/SwiftDriver"),
        
        .executableTarget(
            name: "SwiftMultiplayer",
            dependencies: [
                "SwiftDriver",
                .product(name: "SwiftGodotKit", package: "SwiftGodotKit")
            ],
            path: "Sources", exclude: ["SwiftDriver"],
            resources: [
                .copy("Resources/SwiftDriver.pck")
            ])
        
    ]
)
