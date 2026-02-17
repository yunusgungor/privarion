// swift-tools-version: 5.9
// Package version: 1.0.0-beta.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Privarion",
    platforms: [
        .macOS(.v13)
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
        ),
        // Low-level C hook library
        .library(
            name: "PrivarionHook",
            targets: ["PrivarionHook"]
        ),
        // SwiftUI GUI application  
        .executable(
            name: "PrivarionGUI",
            targets: ["PrivarionGUI"]
        )
    ],
    dependencies: [
        // Swift ArgumentParser for CLI interface
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        // Swift Log for structured logging
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
        // Swift Collections for advanced data structures
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        // KeyboardShortcuts for global macOS shortcuts
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.15.0"),
        // SwiftNIO for high-performance async networking
        .package(url: "https://github.com/apple/swift-nio", from: "2.65.0")
    ],
    targets: [
        // CLI executable target
        .executableTarget(
            name: "PrivacyCtl",
            dependencies: [
                "PrivarionCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            exclude: ["AGENTS.md"]
        ),
        // Core library target
        .target(
            name: "PrivarionCore",
            dependencies: [
                "PrivarionHook",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio")
            ],
            exclude: ["AGENTS.md"]
        ),
        // Low-level C hook library
        .target(
            name: "PrivarionHook",
            dependencies: []
        ),
        // SwiftUI GUI application target
        .executableTarget(
            name: "PrivarionGUI",
            dependencies: [
                "PrivarionCore",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            exclude: ["AGENTS.md"]
        ),
        // Tests for core library
        .testTarget(
            name: "PrivarionCoreTests",
            dependencies: ["PrivarionCore"],
            exclude: ["AGENTS.md"]
        ),
        // Tests for hook library
        .testTarget(
            name: "PrivarionHookTests",
            dependencies: ["PrivarionHook", "PrivarionCore"]
        ),
        // Tests for CLI tool
        .testTarget(
            name: "PrivacyCtlTests",
            dependencies: ["PrivacyCtl", "PrivarionCore"]
        ),
        // Tests for GUI application
        .testTarget(
            name: "PrivarionGUITests",
            dependencies: ["PrivarionGUI", "PrivarionCore"]
        )
    ]
)
