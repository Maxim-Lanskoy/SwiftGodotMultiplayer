// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Platformer3D",
	platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "Platformer3D",
            type: .dynamic,
            targets: ["Platformer3D"]),
    ],
	dependencies: [
        .package(url: "https://github.com/apple/swift-numerics", from: "1.1.1"),
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "5dbf0dc")
    ],
    targets: [
        .target(
            name: "Platformer3D",
			dependencies: [
                .product(name: "Numerics", package: "swift-numerics"),
                "SwiftGodot"
            ]
        ),
        .testTarget(
            name: "Platformer3DTests",
            dependencies: ["Platformer3D"]),
    ]
)
