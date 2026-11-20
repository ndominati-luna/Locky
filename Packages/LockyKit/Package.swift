// swift-tools-version: 6.2
import PackageDescription

let package: Package = .init(
    name: "LockyKit",
    defaultLocalization: "en",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
        .watchOS("27.0")
    ],
    products: [
        .library(name: "LockyKit", targets: ["LockyKit"])
    ],
    targets: [
        .target(
            name: "LockyKit",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "LockyKitTests",
            dependencies: ["LockyKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
