// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacdroidMirror",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacdroidMirror",
            targets: ["MacdroidMirror"]
        ),
        .library(
            name: "MacdroidMirrorCore",
            targets: ["MacdroidMirrorCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MacdroidMirrorCore",
            dependencies: [],
            path: "Sources/MacdroidMirrorCore"
        ),
        .executableTarget(
            name: "MacdroidMirror",
            dependencies: ["MacdroidMirrorCore"],
            path: "Sources/MacdroidMirror"
        ),
        .testTarget(
            name: "MacdroidMirrorTests",
            dependencies: ["MacdroidMirrorCore"],
            path: "Tests/MacdroidMirrorTests"
        )
    ]
)
