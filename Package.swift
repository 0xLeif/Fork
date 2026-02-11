// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Fork",
    platforms: [
        .iOS(.v13),
        .watchOS(.v6),
        .macOS(.v10_15),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Fork",
            targets: ["Fork"]
        )
    ],
    targets: [
        .target(
            name: "Fork"
        ),
        .testTarget(
            name: "ForkTests",
            dependencies: ["Fork"]
        )
    ]
)
