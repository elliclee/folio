// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Folio",
    platforms: [
        // macOS 15 for ScrollPosition/onScrollGeometryChange (scroll sync).
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "Folio",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "Sources/Folio",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "FolioTests",
            dependencies: ["Folio"],
            path: "Tests/FolioTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
