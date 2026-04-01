// swift-tools-version: 6.2
// MacPowerMeter — macOS 状态栏系统监控应用

import PackageDescription

let package = Package(
    name: "MacPowerMeter",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "MacPowerMeter",
            path: "MacPowerMeter",
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Charts")
            ]
        ),
        .testTarget(
            name: "MacPowerMeterTests",
            dependencies: [
                "MacPowerMeter",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "MacPowerMeterTests"
        )
    ]
)
