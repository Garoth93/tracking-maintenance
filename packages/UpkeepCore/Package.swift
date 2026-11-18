// swift-tools-version: 5.9
// Logic package for the Upkeep app. Pure Swift, no UIKit/SwiftUI:
// it must build and test on Linux with `swift test`.
import PackageDescription

let package = Package(
    name: "UpkeepCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "UpkeepCore", targets: ["UpkeepCore"])
    ],
    targets: [
        .target(
            name: "UpkeepCore",
            path: "Sources/UpkeepCore"
        ),
        .testTarget(
            name: "UpkeepCoreTests",
            dependencies: ["UpkeepCore"],
            path: "Tests/UpkeepCoreTests"
        )
    ]
)
