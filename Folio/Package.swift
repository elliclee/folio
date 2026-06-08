// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Folio",
    platforms: [
        // macOS 15 for ScrollPosition/onScrollGeometryChange (scroll sync).
        .macOS(.v15),
    ],
    products: [
        // Portable core (rendering, themes, highlighting, tree, find,
        // scroll sync, workspace/recents) — reused by the future iOS app.
        .library(name: "FolioCore", targets: ["FolioCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "FolioCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "Sources/FolioCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Folio",
            dependencies: [
                "FolioCore",
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "Sources/Folio",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "FolioTests",
            dependencies: ["Folio", "FolioCore"],
            path: "Tests/FolioTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
