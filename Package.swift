// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "dmg-notary",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "dmg-notary",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ShellOut", package: "ShellOut"),
            ],
            path: "Sources"
        ),
    ]
)
