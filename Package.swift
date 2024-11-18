// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XCStringsParser",
    platforms: [.macOS(SupportedPlatform.MacOSVersion.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftcsv/SwiftCSV.git", from: "0.8.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "XCStringsParser",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "SwiftCSV", package: "SwiftCSV"),
            ]
            ),
    ]
)
