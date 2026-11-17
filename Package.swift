// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lenscam",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "LenscamCore", targets: ["LenscamCore"]),
    ],
    targets: [
        .target(
            name: "LenscamCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "LenscamCoreTests",
            dependencies: ["LenscamCore"],
            path: "tests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
