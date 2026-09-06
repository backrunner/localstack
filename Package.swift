// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LocalStack",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LocalStackShared", targets: ["LocalStackShared"]),
        .library(name: "LocalStackCore", targets: ["LocalStackCore"]),
        .library(name: "LocalStackWidget", targets: ["LocalStackWidget"]),
        .executable(name: "LocalStackApp", targets: ["LocalStackApp"]),
        .executable(name: "LocalStackCoordinator", targets: ["LocalStackCoordinator"])
    ],
    targets: [
        .target(
            name: "LocalStackShared",
            path: "Sources/LocalStackShared"
        ),
        .target(
            name: "LocalStackCore",
            dependencies: ["LocalStackShared"],
            path: "Sources/LocalStackCore"
        ),
        .target(
            name: "LocalStackWidget",
            dependencies: ["LocalStackShared"],
            path: "Sources/LocalStackWidget"
        ),
        .executableTarget(
            name: "LocalStackApp",
            dependencies: ["LocalStackCore", "LocalStackShared"],
            path: "Sources/LocalStackApp"
        ),
        .executableTarget(
            name: "LocalStackCoordinator",
            dependencies: ["LocalStackCore", "LocalStackShared"],
            path: "Sources/LocalStackCoordinator"
        ),
        .testTarget(
            name: "LocalStackCoreTests",
            dependencies: ["LocalStackCore", "LocalStackShared"],
            path: "Tests/LocalStackCoreTests"
        )
    ]
)
