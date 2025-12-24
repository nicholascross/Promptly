// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Promptly",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "promptly", targets: ["Promptly"]),
        .executable(name: "toolgen", targets: ["GenerateDefaultShellCommandConfig"]),
        .library(
            name: "PromptlyKit",
            targets: ["PromptlyKit"]
        ),
        .library(
            name: "PromptlyKitUtils",
            targets: ["PromptlyKitUtils"]
        ),
        .library(
            name: "PromptlyKitTooling",
            targets: ["PromptlyKitTooling"]
        ),
        .library(
            name: "PromptlySubAgents",
            targets: ["PromptlySubAgents"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/nicholascross/SwiftTokenizer", from: "0.0.1"),
        .package(url: "https://github.com/nicholascross/TerminalUI", from: "0.8.0"),
        .package(url: "https://github.com/nicholascross/PatchApplyKit", from: "0.0.3")
    ],
    targets: [
        .executableTarget(
            name: "Promptly",
            dependencies: [
                "PromptlyKit",
                "PromptlyKitTooling",
                "PromptlyKitUtils",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftTokenizer", package: "SwiftTokenizer"),
                .product(name: "TerminalUI", package: "TerminalUI")
            ]
        ),
        .target(
            name: "PromptlyKit",
            dependencies: [
                "PromptlyKitUtils",
                .product(name: "SwiftTokenizer", package: "SwiftTokenizer"),
                .product(name: "PatchApplyKit", package: "PatchApplyKit")
            ]
        ),
        .target(
            name: "PromptlyKitTooling",
            dependencies: ["PromptlyKit", "PromptlyKitUtils"]
        ),
        .target(
            name: "PromptlyKitUtils",
            dependencies: []
        ),
        .target(
            name: "PromptlySubAgents",
            dependencies: [
                "PromptlyKit",
                "PromptlyKitTooling",
                "PromptlyKitUtils"
            ]
        ),
        .testTarget(
            name: "PromptlyKitTests",
            dependencies: ["PromptlyKit"]
        ),
        .executableTarget(
            name: "GenerateDefaultShellCommandConfig",
            dependencies: [
                "PromptlyKit",
                "PromptlyKitUtils"
            ],
            path: "Scripts/GenerateDefaultShellCommandConfig"
        )
    ],
    swiftLanguageModes: [.v6]
)
