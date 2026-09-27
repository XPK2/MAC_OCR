// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacOCR",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MacOCR",
            path: "Sources/MacOCR"
        ),
        .testTarget(
            name: "MacOCRTests",
            dependencies: ["MacOCR"],
            path: "Tests/MacOCRTests"
        )
    ]
)
