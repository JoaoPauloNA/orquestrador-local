// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrquestradorLocal",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OrquestradorLocal",
            path: "Sources/OrquestradorLocal",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        ),
        .testTarget(
            name: "OrquestradorLocalTests",
            dependencies: ["OrquestradorLocal"],
            path: "Tests/OrquestradorLocalTests"
        )
    ]
)
