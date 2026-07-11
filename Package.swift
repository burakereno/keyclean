// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KeyClean",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "KeyClean", targets: ["KeyClean"])
    ],
    targets: [
        .executableTarget(
            name: "KeyClean",
            path: "Sources/KeyClean",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "KeyCleanTests",
            dependencies: ["KeyClean"],
            path: "Tests/KeyCleanTests"
        )
    ]
)
