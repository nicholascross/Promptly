// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Promptly",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "promptly", targets: ["Promptly"]),
        .library(
            name: "PromptlyKit",
            targets: ["PromptlyKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/MacPaw/OpenAI.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "Promptly",
            dependencies: [
                "PromptlyKit",
                "OpenAI",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(name: "PromptlyKit")
    ],
    swiftLanguageModes: [.v6]
)
