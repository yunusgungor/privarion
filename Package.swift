// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Privarion",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // Executable CLI tool
        .executable(
            name: "privacyctl",
            targets: ["PrivacyCtl"]
        ),
        // Core library for modules
        .library(
            name: "PrivarionCore",
            targets: ["PrivarionCore"]
        )
    ],
    dependencies: [
        // Swift ArgumentParser for CLI interface
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        // Swift Log for structured logging
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
        // Swift Collections for advanced data structures
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0")
    ],
    targets: [
        // CLI executable target
        .executableTarget(
            name: "PrivacyCtl",
            dependencies: [
                "PrivarionCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        // Core library target
        .target(
            name: "PrivarionCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        // Tests for core library
        .testTarget(
            name: "PrivarionCoreTests",
            dependencies: ["PrivarionCore"]
        )
    ]
)
