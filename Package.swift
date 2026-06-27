// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WindowGestures",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "WindowGesturesCore",
            targets: ["WindowGesturesCore"]
        ),
        .library(
            name: "WindowGesturesMac",
            targets: ["WindowGesturesMac"]
        ),
        .executable(
            name: "WindowGesturesApp",
            targets: ["WindowGesturesApp"]
        )
    ],
    targets: [
        .target(
            name: "WindowGesturesCore"
        ),
        .target(
            name: "WindowGesturesMac",
            dependencies: ["WindowGesturesCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "WindowGesturesApp",
            dependencies: [
                "WindowGesturesCore",
                "WindowGesturesMac"
            ],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "WindowGesturesCoreTests",
            dependencies: ["WindowGesturesCore"]
        )
    ]
)
