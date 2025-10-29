// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PDFManager",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "PDFManager",
            targets: ["PDFManager"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/markbattistella/SimpleLogger", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "PDFManager",
            dependencies: ["SimpleLogger"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        )
    ]
)
