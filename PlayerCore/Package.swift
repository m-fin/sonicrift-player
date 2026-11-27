// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlayerCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PlayerCore", targets: ["PlayerCore"]),
    ],
    targets: [
        .target(name: "PlayerCore"),
        .testTarget(
            name: "PlayerCoreTests",
            dependencies: ["PlayerCore"]
        ),
    ]
)
